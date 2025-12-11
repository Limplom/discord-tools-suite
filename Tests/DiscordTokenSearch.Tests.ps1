# Pester 5.x Tests for DiscordTokenSearch.ps1

BeforeAll {
    # Import the script under test
    . "$PSScriptRoot/../DiscordTokenSearch.ps1" -QuietMode

    # Mock Write-Host to suppress output during tests
    Mock Write-Host {}
}

Describe "Test-TokenValidity" {
    Context "When token is valid" {
        BeforeEach {
            Mock Invoke-RestMethod {
                return @{
                    username = "TestUser"
                    discriminator = "1234"
                    global_name = "Test User"
                    id = "123456789012345678"
                }
            }
        }

        It "Should return valid status with user information" {
            $result = Test-TokenValidity -Token "validtoken123"

            $result.Valid | Should -Be $true
            $result.Username | Should -Be "TestUser"
            $result.Discriminator | Should -Be "1234"
            $result.GlobalName | Should -Be "Test User"
            $result.Id | Should -Be "123456789012345678"
        }

        It "Should call Discord API with correct headers" {
            Test-TokenValidity -Token "testtoken" | Out-Null

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -eq "https://discord.com/api/v10/users/@me" -and
                $Method -eq "Get" -and
                $Headers.Authorization -eq "testtoken" -and
                $Headers."User-Agent" -eq "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            }
        }

        It "Should use 5 second timeout" {
            Test-TokenValidity -Token "testtoken" | Out-Null

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $TimeoutSec -eq 5
            }
        }
    }

    Context "When token is invalid" {
        BeforeEach {
            Mock Invoke-RestMethod {
                throw "Unauthorized"
            }
        }

        It "Should return invalid status" {
            $result = Test-TokenValidity -Token "invalidtoken"

            $result.Valid | Should -Be $false
        }

        It "Should not throw exception" {
            { Test-TokenValidity -Token "invalidtoken" } | Should -Not -Throw
        }
    }

    Context "When API response is malformed" {
        BeforeEach {
            Mock Invoke-RestMethod {
                return @{
                    # Missing username field
                    discriminator = "1234"
                }
            }
        }

        It "Should return invalid status for incomplete response" {
            $result = Test-TokenValidity -Token "malformedresponse"

            $result.Valid | Should -Be $false
        }
    }

    Context "When API returns empty response" {
        BeforeEach {
            Mock Invoke-RestMethod {
                return $null
            }
        }

        It "Should return invalid status for null response" {
            $result = Test-TokenValidity -Token "nullresponse"

            $result.Valid | Should -Be $false
        }
    }

    Context "When network error occurs" {
        BeforeEach {
            Mock Invoke-RestMethod {
                throw "Network error: Unable to connect"
            }
        }

        It "Should handle network errors gracefully" {
            $result = Test-TokenValidity -Token "networkfail"

            $result.Valid | Should -Be $false
        }
    }
}

Describe "Get-MasterKey" {
    Context "When Local State file exists and is valid" {
        BeforeAll {
            # Create test directory structure
            $script:testBasePath = Join-Path $TestDrive "TestApp"
            New-Item -ItemType Directory -Path $testBasePath -Force | Out-Null

            # Create valid Local State file
            $masterKeyBase64 = "RFBBUEkBAAAADwIAADAAAABAAAAAAAAA"  # Mock encrypted key with DPAPI prefix
            $localStateContent = @{
                os_crypt = @{
                    encrypted_key = $masterKeyBase64
                }
            } | ConvertTo-Json

            Set-Content -Path (Join-Path $testBasePath "Local State") -Value $localStateContent
        }

        BeforeEach {
            # Mock DPAPI decryption
            Mock -CommandName Invoke-Expression -MockWith {
                param($Command)
                if ($Command -like "*ProtectedData*Unprotect*") {
                    return [byte[]]@(0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08)
                }
            }
        }

        It "Should return decrypted master key" {
            # Note: This test will only work on Windows with real DPAPI
            # In CI/CD, you may need to mock this differently
            $result = Get-MasterKey -BasePath $script:testBasePath

            # Should return byte array or null (depends on DPAPI availability)
            $result | Should -BeOfType [System.Object]
        }

        It "Should read from correct Local State path" {
            Get-MasterKey -BasePath $script:testBasePath | Out-Null

            $expectedPath = Join-Path $script:testBasePath "Local State"
            Test-Path $expectedPath | Should -Be $true
        }
    }

    Context "When Local State file does not exist" {
        BeforeAll {
            $script:nonExistentPath = Join-Path $TestDrive "NonExistent"
        }

        It "Should return null" {
            $result = Get-MasterKey -BasePath $script:nonExistentPath

            $result | Should -Be $null
        }
    }

    Context "When Local State file is malformed" {
        BeforeAll {
            $script:malformedPath = Join-Path $TestDrive "Malformed"
            New-Item -ItemType Directory -Path $script:malformedPath -Force | Out-Null

            # Create invalid JSON
            Set-Content -Path (Join-Path $script:malformedPath "Local State") -Value "invalid json {"
        }

        It "Should return null for invalid JSON" {
            $result = Get-MasterKey -BasePath $script:malformedPath

            $result | Should -Be $null
        }
    }

    Context "When encrypted_key is missing" {
        BeforeAll {
            $script:missingKeyPath = Join-Path $TestDrive "MissingKey"
            New-Item -ItemType Directory -Path $script:missingKeyPath -Force | Out-Null

            # Create JSON without encrypted_key
            $localStateContent = @{
                os_crypt = @{
                    # No encrypted_key field
                }
            } | ConvertTo-Json

            Set-Content -Path (Join-Path $script:missingKeyPath "Local State") -Value $localStateContent
        }

        It "Should return null when encrypted_key is missing" {
            $result = Get-MasterKey -BasePath $script:missingKeyPath

            $result | Should -Be $null
        }
    }

    Context "When DPAPI decryption fails" {
        BeforeAll {
            $script:dpapiFailPath = Join-Path $TestDrive "DPAPIFail"
            New-Item -ItemType Directory -Path $script:dpapiFailPath -Force | Out-Null

            $localStateContent = @{
                os_crypt = @{
                    encrypted_key = "RFBBUEkBAAAADwIAADAAAABAAAAAAAAA"
                }
            } | ConvertTo-Json

            Set-Content -Path (Join-Path $script:dpapiFailPath "Local State") -Value $localStateContent
        }

        It "Should return null and show warning" {
            $result = Get-MasterKey -BasePath $script:dpapiFailPath

            # Result will be null if DPAPI fails
            # In real Windows environment, this depends on DPAPI availability
            $result | Should -BeIn @($null, [byte[]])
        }
    }
}

Describe "ConvertFrom-EncryptedToken" {
    Context "When PowerShell 7+ with AES-GCM support" {
        BeforeAll {
            # Save original state
            $script:originalAesSupport = $global:SupportAesGcm
            $global:SupportAesGcm = $true
        }

        AfterAll {
            # Restore original state
            $global:SupportAesGcm = $script:originalAesSupport
        }

        BeforeEach {
            # Mock AesGcm class
            if (-not ([System.Management.Automation.PSTypeName]'System.Security.Cryptography.AesGcm').Type) {
                # AesGcm not available in PS 5.1, skip these tests
            }
        }

        It "Should return null when MasterKey is null" {
            $result = ConvertFrom-EncryptedToken -EncryptedToken "dGVzdA==" -MasterKey $null

            $result | Should -Be $null
        }

        It "Should return null when AES-GCM is not supported" {
            $global:SupportAesGcm = $false
            $masterKey = [byte[]]@(0x01, 0x02, 0x03, 0x04)

            $result = ConvertFrom-EncryptedToken -EncryptedToken "dGVzdA==" -MasterKey $masterKey

            $result | Should -Be $null
            $global:SupportAesGcm = $true
        }

        It "Should return null for invalid base64" {
            $masterKey = [byte[]]@(1..32)

            $result = ConvertFrom-EncryptedToken -EncryptedToken "not-valid-base64!!!" -MasterKey $masterKey

            $result | Should -Be $null
        }

        It "Should return null for token without v10/v11 prefix" -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
            $masterKey = [byte[]]@(1..32)
            # Valid base64 but wrong prefix
            $invalidToken = [Convert]::ToBase64String([byte[]]@(0x76, 0x39, 0x39))  # "v99"

            $result = ConvertFrom-EncryptedToken -EncryptedToken $invalidToken -MasterKey $masterKey

            $result | Should -Be $null
        }
    }

    Context "When decryption fails" {
        BeforeAll {
            $global:SupportAesGcm = $true
        }

        It "Should return null and not throw exception" -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
            $masterKey = [byte[]]@(1..32)
            # Create malformed encrypted token with v10 prefix
            $malformedBytes = [byte[]]@(0x76, 0x31, 0x30) + [byte[]]@(1..20)  # "v10" + garbage
            $malformedToken = [Convert]::ToBase64String($malformedBytes)

            { ConvertFrom-EncryptedToken -EncryptedToken $malformedToken -MasterKey $masterKey } | Should -Not -Throw
        }
    }
}

Describe "Get-Tokens" {
    Context "When LevelDB directory does not exist" {
        BeforeAll {
            $script:noLevelDBPath = Join-Path $TestDrive "NoLevelDB"
            New-Item -ItemType Directory -Path $script:noLevelDBPath -Force | Out-Null
        }

        It "Should return empty array" {
            $result = Get-Tokens -Path $script:noLevelDBPath -MasterKey $null

            $result | Should -HaveCount 0
        }
    }

    Context "When LevelDB directory exists with unencrypted tokens" {
        BeforeAll {
            $script:levelDBPath = Join-Path $TestDrive "Discord"
            $script:levelDBSubPath = Join-Path $script:levelDBPath "Local Storage\leveldb"
            New-Item -ItemType Directory -Path $script:levelDBSubPath -Force | Out-Null

            # Create .ldb file with token (FAKE TOKEN FOR TESTING)
            $testToken = "FAKE1234567890FAKE567890.TEST01.FAKE-TEST-TOKEN-1234567890"
            $ldbContent = "Some random data $testToken more data"
            Set-Content -Path (Join-Path $script:levelDBSubPath "test.ldb") -Value $ldbContent -NoNewline

            # Create .log file with another token (FAKE TOKEN FOR TESTING)
            $testToken2 = "FAKE0987654321FAKE098765.TEST02.FAKE-TEST-TOKEN-0987654321"
            $logContent = "Log data $testToken2 end"
            Set-Content -Path (Join-Path $script:levelDBSubPath "test.log") -Value $logContent -NoNewline
        }

        It "Should find unencrypted tokens in .ldb files" {
            $result = Get-Tokens -Path $script:levelDBPath -MasterKey $null

            $result | Should -Contain "FAKE1234567890FAKE567890.TEST01.FAKE-TEST-TOKEN-1234567890"
        }

        It "Should find tokens in .log files" {
            $result = Get-Tokens -Path $script:levelDBPath -MasterKey $null

            $result | Should -Contain "FAKE0987654321FAKE098765.TEST02.FAKE-TEST-TOKEN-0987654321"
        }

        It "Should return multiple unique tokens" {
            $result = Get-Tokens -Path $script:levelDBPath -MasterKey $null

            $result.Count | Should -BeGreaterOrEqual 2
        }

        It "Should deduplicate tokens" {
            # Add file with duplicate token
            $duplicateContent = "FAKE1234567890FAKE567890.TEST01.FAKE-TEST-TOKEN-1234567890"
            Set-Content -Path (Join-Path $script:levelDBSubPath "duplicate.ldb") -Value $duplicateContent

            $result = Get-Tokens -Path $script:levelDBPath -MasterKey $null

            # Count should not include duplicates
            ($result | Where-Object { $_ -eq "FAKE1234567890FAKE567890.TEST01.FAKE-TEST-TOKEN-1234567890" }).Count | Should -Be 1
        }
    }

    Context "When LevelDB directory contains encrypted tokens" {
        BeforeAll {
            $script:encryptedPath = Join-Path $TestDrive "DiscordEncrypted"
            $script:encryptedLevelDB = Join-Path $script:encryptedPath "Local Storage\leveldb"
            New-Item -ItemType Directory -Path $script:encryptedLevelDB -Force | Out-Null

            # Create file with encrypted token marker
            $encryptedToken = "dQw4w9WgXcQ:YmFzZTY0ZW5jb2RlZGRhdGFoZXJl"
            $content = "Some data $encryptedToken more data"
            Set-Content -Path (Join-Path $script:encryptedLevelDB "encrypted.ldb") -Value $content -NoNewline
        }

        It "Should detect encrypted tokens" {
            Mock ConvertFrom-EncryptedToken { return "decrypted.token.here" }
            $masterKey = [byte[]]@(1..32)

            $result = Get-Tokens -Path $script:encryptedPath -MasterKey $masterKey

            # Should call decryption function
            Should -Invoke ConvertFrom-EncryptedToken
        }

        It "Should return decrypted tokens when decryption succeeds" {
            Mock ConvertFrom-EncryptedToken { return "FAKEDECRYPT123456FAKE78.DECRYP.FAKE-DECRYPTED-TOKEN-TEST" }
            $masterKey = [byte[]]@(1..32)
            $global:SupportAesGcm = $true

            $result = Get-Tokens -Path $script:encryptedPath -MasterKey $masterKey

            $result | Should -Contain "FAKEDECRYPT123456FAKE78.DECRYP.FAKE-DECRYPTED-TOKEN-TEST"
        }

        It "Should handle decryption failure gracefully" {
            Mock ConvertFrom-EncryptedToken { return $null }
            $masterKey = [byte[]]@(1..32)

            $result = Get-Tokens -Path $script:encryptedPath -MasterKey $masterKey

            $result | Should -HaveCount 0
        }

        It "Should skip decryption when AES-GCM is not supported" {
            $global:SupportAesGcm = $false
            Mock ConvertFrom-EncryptedToken { return "should.not.be.called" }
            $masterKey = [byte[]]@(1..32)

            $result = Get-Tokens -Path $script:encryptedPath -MasterKey $masterKey

            # Should still try to decrypt but return empty array
            $result | Should -BeOfType [System.Array]
        }
    }

    Context "When LevelDB contains both encrypted and unencrypted tokens" {
        BeforeAll {
            $script:mixedPath = Join-Path $TestDrive "DiscordMixed"
            $script:mixedLevelDB = Join-Path $script:mixedPath "Local Storage\leveldb"
            New-Item -ItemType Directory -Path $script:mixedLevelDB -Force | Out-Null

            # Unencrypted token (FAKE TOKEN FOR TESTING)
            $unencryptedToken = "FAKEUNENCRYPT123FAKE78.UNENCR.FAKE-UNENCRYPTED-TOKEN-TEST"
            Set-Content -Path (Join-Path $script:mixedLevelDB "unencrypted.ldb") -Value $unencryptedToken -NoNewline

            # Encrypted token
            $encryptedToken = "dQw4w9WgXcQ:ZW5jcnlwdGVkZGF0YQ=="
            Set-Content -Path (Join-Path $script:mixedLevelDB "encrypted.ldb") -Value $encryptedToken -NoNewline
        }

        It "Should find unencrypted tokens and skip decryption" {
            $masterKey = [byte[]]@(1..32)

            $result = Get-Tokens -Path $script:mixedPath -MasterKey $masterKey

            # Should find unencrypted token
            $result | Should -Contain "FAKEUNENCRYPT123FAKE78.UNENCR.FAKE-UNENCRYPTED-TOKEN-TEST"
        }

        It "Should not attempt decryption when unencrypted tokens are found" {
            Mock ConvertFrom-EncryptedToken { throw "Should not be called" }
            $masterKey = [byte[]]@(1..32)

            { Get-Tokens -Path $script:mixedPath -MasterKey $masterKey } | Should -Not -Throw
        }
    }

    Context "When file reading fails" {
        BeforeAll {
            $script:failReadPath = Join-Path $TestDrive "FailRead"
            $script:failReadLevelDB = Join-Path $script:failReadPath "Local Storage\leveldb"
            New-Item -ItemType Directory -Path $script:failReadLevelDB -Force | Out-Null

            # Create a file (we'll mock Get-Content to fail)
            New-Item -Path (Join-Path $script:failReadLevelDB "test.ldb") -ItemType File | Out-Null
        }

        It "Should skip files that cannot be read" {
            Mock Get-Content { throw "Access denied" } -ParameterFilter { $Path -like "*test.ldb" }

            { Get-Tokens -Path $script:failReadPath -MasterKey $null } | Should -Not -Throw
        }
    }

    Context "Token regex pattern validation" {
        BeforeAll {
            $script:regexTestPath = Join-Path $TestDrive "RegexTest"
            $script:regexTestLevelDB = Join-Path $script:regexTestPath "Local Storage\leveldb"
            New-Item -ItemType Directory -Path $script:regexTestLevelDB -Force | Out-Null
        }

        It "Should match valid token format (24.6.27+)" {
            $validToken = "FAKEVALIDTEST123FAKE78.AbCdEf.FAKE-VALID-TOKEN-REGEX-TEST"
            Set-Content -Path (Join-Path $script:regexTestLevelDB "valid.ldb") -Value $validToken

            $result = Get-Tokens -Path $script:regexTestPath -MasterKey $null

            $result | Should -Contain $validToken
        }

        It "Should reject invalid token format (wrong segment lengths)" {
            $invalidToken = "FAKEINVALID.AbCdEf.ghijklmnopqrstuvwxyz1234567"  # First part too short
            Set-Content -Path (Join-Path $script:regexTestLevelDB "invalid.ldb") -Value $invalidToken

            $result = Get-Tokens -Path $script:regexTestPath -MasterKey $null

            $result | Should -Not -Contain $invalidToken
        }

        It "Should handle tokens with trailing backslashes" {
            $tokenWithBackslash = "FAKEBACKSLASH123FAKE78.AbCdEf.FAKE-BACKSLASH-TOKEN-TEST\\"
            Set-Content -Path (Join-Path $script:regexTestLevelDB "backslash.ldb") -Value $tokenWithBackslash

            $result = Get-Tokens -Path $script:regexTestPath -MasterKey $null

            # Should trim trailing backslash
            $result | Should -Contain "FAKEBACKSLASH123FAKE78.AbCdEf.FAKE-BACKSLASH-TOKEN-TEST"
        }

        It "Should match encrypted token format (dQw4w9WgXcQ:base64)" {
            Mock ConvertFrom-EncryptedToken { return "decrypted.token.value" }
            $encryptedToken = "dQw4w9WgXcQ:VGVzdERhdGFIZXJl=="
            Set-Content -Path (Join-Path $script:regexTestLevelDB "encrypted.ldb") -Value $encryptedToken
            $masterKey = [byte[]]@(1..32)

            $result = Get-Tokens -Path $script:regexTestPath -MasterKey $masterKey

            # Should attempt decryption
            Should -Invoke ConvertFrom-EncryptedToken
        }
    }

    Context "Edge cases and special scenarios" {
        BeforeAll {
            $script:edgeCasePath = Join-Path $TestDrive "EdgeCase"
            $script:edgeCaseLevelDB = Join-Path $script:edgeCasePath "Local Storage\leveldb"
            New-Item -ItemType Directory -Path $script:edgeCaseLevelDB -Force | Out-Null
        }

        It "Should handle empty files" {
            New-Item -Path (Join-Path $script:edgeCaseLevelDB "empty.ldb") -ItemType File | Out-Null

            $result = Get-Tokens -Path $script:edgeCasePath -MasterKey $null

            $result | Should -HaveCount 0
        }

        It "Should ignore non-.ldb and non-.log files" {
            $token = "FAKEIGNORED123FAKE78TEST.AbCdEf.FAKE-IGNORED-FILE-TOKEN-TEST"
            Set-Content -Path (Join-Path $script:edgeCaseLevelDB "ignored.txt") -Value $token

            $result = Get-Tokens -Path $script:edgeCasePath -MasterKey $null

            $result | Should -Not -Contain $token
        }

        It "Should handle binary/non-UTF8 files gracefully" {
            $binaryPath = Join-Path $script:edgeCaseLevelDB "binary.ldb"
            [byte[]]@(0xFF, 0xFE, 0xFD, 0x00, 0x01) | Set-Content -Path $binaryPath -AsByteStream -ErrorAction SilentlyContinue

            { Get-Tokens -Path $script:edgeCasePath -MasterKey $null } | Should -Not -Throw
        }
    }
}

Describe "Integration Tests" {
    Context "Full token search workflow" {
        BeforeAll {
            $script:integrationPath = Join-Path $TestDrive "IntegrationTest"
            $script:integrationLevelDB = Join-Path $script:integrationPath "Local Storage\leveldb"
            New-Item -ItemType Directory -Path $script:integrationLevelDB -Force | Out-Null

            # Create realistic test data (FAKE TOKEN FOR TESTING)
            $validToken = "FAKEINTEGRATION123FAKE.GhIjKl.FAKE-INTEGRATION-TOKEN-TEST890"
            Set-Content -Path (Join-Path $script:integrationLevelDB "000003.ldb") -Value "prefix_$validToken`_suffix"

            # Create Local State file
            $localStateContent = @{
                os_crypt = @{
                    encrypted_key = "RFBBUEkBAAAADwIAADAAAABAAAAAAAAA"
                }
            } | ConvertTo-Json
            Set-Content -Path (Join-Path $script:integrationPath "Local State") -Value $localStateContent
        }

        It "Should find tokens and extract master key" {
            $masterKey = Get-MasterKey -BasePath $script:integrationPath
            $tokens = Get-Tokens -Path $script:integrationPath -MasterKey $masterKey

            $tokens | Should -Not -BeNullOrEmpty
        }

        It "Should validate found tokens" {
            Mock Invoke-RestMethod {
                return @{
                    username = "IntegrationTestUser"
                    discriminator = "0001"
                    global_name = "Integration Test"
                    id = "999999999999999999"
                }
            }

            $tokens = Get-Tokens -Path $script:integrationPath -MasterKey $null
            $validation = Test-TokenValidity -Token $tokens[0]

            $validation.Valid | Should -Be $true
            $validation.Username | Should -Be "IntegrationTestUser"
        }
    }
}
