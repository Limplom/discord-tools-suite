# Discord Token Search
# Searches for Discord tokens in local storage

param(
    [Parameter(Mandatory=$false)]
    [switch]$QuietMode  # Suppresses "Press any key" when called from another script
)

# Check PowerShell version and offer to upgrade at the start
$global:SupportAesGcm = $false

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $global:SupportAesGcm = $true
    Write-Host "[*] PowerShell 7+ detected - Full encryption support enabled" -ForegroundColor Green
    Write-Host ""
} elseif ($PSVersionTable.PSVersion.Major -lt 7) {
    # Check if AesGcm is available (it's not in PS 5.1)
    try {
        [System.Security.Cryptography.AesGcm] | Out-Null
        $global:SupportAesGcm = $true
    } catch {
        $global:SupportAesGcm = $false

        # Check if PowerShell 7 is already installed
        $ps7Installed = $false
        try {
            $ps7Path = Get-Command pwsh -ErrorAction SilentlyContinue
            if ($ps7Path) {
                $ps7Installed = $true
            }
        } catch { }

        if ($ps7Installed) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host "PowerShell 7+ ist installiert!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Discord verwendet jetzt AES-GCM verschluesselte Tokens." -ForegroundColor White
            Write-Host "PowerShell 7+ wird benoetigt fuer vollstaendige Token-Entschluesselung." -ForegroundColor White
            Write-Host ""
            Write-Host "Moechten Sie das Script in PowerShell 7 neu starten? (J/N): " -ForegroundColor Yellow -NoNewline
            $restart = Read-Host

            if ($restart -eq 'J' -or $restart -eq 'j' -or $restart -eq 'Y' -or $restart -eq 'y') {
                Write-Host ""
                Write-Host "[*] Starte in PowerShell 7..." -ForegroundColor Cyan
                Start-Process pwsh -ArgumentList "-NoExit", "-File", "`"$PSCommandPath`""
                exit
            } else {
                Write-Host ""
                Write-Host "[!] Fahre mit PowerShell 5.1 fort (eingeschraenkte Funktionalitaet)" -ForegroundColor Yellow
                Write-Host ""
            }
        } else {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host "PowerShell 7+ wird empfohlen!" -ForegroundColor Yellow
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Discord verwendet jetzt AES-GCM verschluesselte Tokens." -ForegroundColor White
            Write-Host "PowerShell 5.1 kann diese NICHT entschluesseln." -ForegroundColor Red
            Write-Host ""
            Write-Host "Moechten Sie PowerShell 7 jetzt installieren? (J/N): " -ForegroundColor Yellow -NoNewline
            $install = Read-Host

            if ($install -eq 'J' -or $install -eq 'j' -or $install -eq 'Y' -or $install -eq 'y') {
                Write-Host ""
                Write-Host "[*] Installiere PowerShell 7..." -ForegroundColor Cyan

                try {
                    $null = Get-Command winget -ErrorAction Stop
                    Write-Host "[*] Verwende winget fuer Installation..." -ForegroundColor Gray
                    & winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements

                    if ($LASTEXITCODE -eq 0) {
                        Write-Host ""
                        Write-Host "[OK] PowerShell 7 erfolgreich installiert!" -ForegroundColor Green
                        Write-Host "[*] Starte Script neu in PowerShell 7..." -ForegroundColor Cyan
                        Start-Process pwsh -ArgumentList "-NoExit", "-File", "`"$PSCommandPath`""
                        exit
                    } else {
                        Write-Host ""
                        Write-Host "[FEHLER] Installation fehlgeschlagen." -ForegroundColor Red
                        Write-Host "[*] Fahre mit eingeschraenkter Funktionalitaet fort..." -ForegroundColor Yellow
                        Write-Host ""
                    }
                } catch {
                    Write-Host ""
                    Write-Host "[FEHLER] winget nicht gefunden." -ForegroundColor Red
                    Write-Host "Bitte installiere PowerShell 7 manuell: https://aka.ms/powershell" -ForegroundColor Yellow
                    Write-Host "[*] Fahre mit eingeschraenkter Funktionalitaet fort..." -ForegroundColor Yellow
                    Write-Host ""
                }
            } else {
                Write-Host ""
                Write-Host "[*] Fahre mit eingeschraenkter Funktionalitaet fort..." -ForegroundColor Yellow
                Write-Host ""
            }
        }
    }
}

$LOCAL = $env:LOCALAPPDATA
$ROAMING = $env:APPDATA
$PATHS = @{
    'Discord' = "$ROAMING\discord"
    'Discord Canary' = "$ROAMING\discordcanary"
    'Discord PTB' = "$ROAMING\discordptb"
    'Lightcord' = "$ROAMING\Lightcord"
    'Opera' = "$ROAMING\Opera Software\Opera Stable"
    'Opera GX' = "$ROAMING\Opera Software\Opera GX Stable"
    'Chrome' = "$LOCAL\Google\Chrome\User Data\Default"
    'Chrome SxS' = "$LOCAL\Google\Chrome SxS\User Data"
    'Microsoft Edge' = "$LOCAL\Microsoft\Edge\User Data\Default"
    'Brave' = "$LOCAL\BraveSoftware\Brave-Browser\User Data\Default"
    'Yandex' = "$LOCAL\Yandex\YandexBrowser\User Data\Default"
    'Vivaldi' = "$LOCAL\Vivaldi\User Data\Default"
}

Add-Type -AssemblyName System.Security

function Get-MasterKey {
    param (
        [string]$BasePath
    )

    $localStatePath = Join-Path $BasePath "Local State"

    if (-not (Test-Path $localStatePath)) {
        return $null
    }

    try {
        $localState = Get-Content $localStatePath -Raw | ConvertFrom-Json
        $encryptedKey = $localState.os_crypt.encrypted_key

        if (-not $encryptedKey) {
            return $null
        }

        # Decode base64
        $encryptedKeyBytes = [System.Convert]::FromBase64String($encryptedKey)

        # Remove "DPAPI" prefix (first 5 bytes)
        $encryptedKeyBytes = $encryptedKeyBytes[5..($encryptedKeyBytes.Length - 1)]

        # Decrypt with DPAPI
        $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $encryptedKeyBytes,
            $null,
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )

        return $masterKey
    }
    catch {
        Write-Host "  Warning: Could not load master key: $_" -ForegroundColor Yellow
        return $null
    }
}

function ConvertFrom-EncryptedToken {
    param (
        [string]$EncryptedToken,
        [byte[]]$MasterKey
    )

    if (-not $MasterKey -or -not $global:SupportAesGcm) {
        return $null
    }

    try {
        # Decode base64
        $encryptedBytes = [System.Convert]::FromBase64String($EncryptedToken)

        # Check for v10 or v11 prefix
        $prefix = [System.Text.Encoding]::UTF8.GetString($encryptedBytes[0..2])

        if ($prefix -ne "v10" -and $prefix -ne "v11") {
            return $null
        }

        # Extract nonce (12 bytes after prefix)
        $nonce = $encryptedBytes[3..14]

        # Extract ciphertext and tag
        $ciphertext = $encryptedBytes[15..($encryptedBytes.Length - 1)]
        $tag = $ciphertext[($ciphertext.Length - 16)..($ciphertext.Length - 1)]
        $actualCiphertext = $ciphertext[0..($ciphertext.Length - 17)]

        # Use AesGcm (PowerShell 7+)
        $aes = [System.Security.Cryptography.AesGcm]::new($MasterKey)
        $decrypted = New-Object byte[] $actualCiphertext.Length
        $aes.Decrypt($nonce, $actualCiphertext, $tag, $decrypted)
        return [System.Text.Encoding]::UTF8.GetString($decrypted)
    }
    catch {
        return $null
    }
}

function Get-Tokens {
    param (
        [string]$Path,
        [byte[]]$MasterKey
    )

    $LevelDBPath = Join-Path $Path "Local Storage\leveldb"
    $tokens = @()
    $encryptedTokens = @()

    if (-not (Test-Path $LevelDBPath)) {
        return $tokens
    }

    Get-ChildItem -Path $LevelDBPath -File | Where-Object {
        $_.Extension -eq ".ldb" -or $_.Extension -eq ".log"
    } | ForEach-Object {
        try {
            $content = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            if ($content) {
                # Search for unencrypted tokens: 24 chars . 6 chars . 27+ chars
                $tokenMatches = [regex]::Matches($content, '[A-Za-z0-9_-]{24}\.[A-Za-z0-9_-]{6}\.[A-Za-z0-9_-]{27,}')
                foreach ($match in $tokenMatches) {
                    $token = $match.Value.TrimEnd('\')
                    if ($token -and $token -notin $tokens) {
                        $tokens += $token
                    }
                }

                # Search for encrypted tokens: dQw4w9WgXcQ:base64_encoded_data
                $encMatches = [regex]::Matches($content, 'dQw4w9WgXcQ:([A-Za-z0-9+/=]+)')
                foreach ($encMatch in $encMatches) {
                    $encToken = $encMatch.Groups[1].Value
                    if ($encToken -and $encToken -notin $encryptedTokens) {
                        $encryptedTokens += $encToken
                    }
                }
            }
        }
        catch {
            # Skip files that can't be read
        }
    }

    # If no unencrypted tokens found but encrypted tokens exist, try to decrypt
    if ($tokens.Count -eq 0 -and $encryptedTokens.Count -gt 0 -and $MasterKey) {
        Write-Host "  Found $($encryptedTokens.Count) encrypted token(s), decrypting..." -ForegroundColor Cyan
        $decryptedCount = 0
        foreach ($encToken in $encryptedTokens) {
            $decrypted = ConvertFrom-EncryptedToken -EncryptedToken $encToken -MasterKey $MasterKey
            if ($decrypted -and $decrypted -notin $tokens) {
                $tokens += $decrypted
                $decryptedCount++
            }
        }
        if ($decryptedCount -gt 0) {
            Write-Host "  Successfully decrypted $decryptedCount token(s)" -ForegroundColor Green
        } elseif (-not $global:SupportAesGcm) {
            Write-Host "  Cannot decrypt (PowerShell 7+ required)" -ForegroundColor Yellow
        } else {
            Write-Host "  Failed to decrypt tokens" -ForegroundColor Yellow
        }
    }

    return $tokens
}

$allTokens = @{}

foreach ($platform in $PATHS.Keys) {
    $path = $PATHS[$platform]

    if (Test-Path $path) {
        Write-Host "Checking: $platform" -ForegroundColor Gray

        # Try to get master key for this platform
        $masterKey = Get-MasterKey -BasePath $path

        if ($masterKey) {
            Write-Host "  Master key loaded" -ForegroundColor Green
        }

        $tokens = Get-Tokens -Path $path -MasterKey $masterKey

        if ($tokens.Count -gt 0) {
            $allTokens[$platform] = $tokens
            Write-Host "  Found $($tokens.Count) token(s)" -ForegroundColor Green
        }
    }
}

if ($allTokens.Count -eq 0) {
    Write-Host "`nNo tokens found." -ForegroundColor Yellow
} else {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Gefundene Tokens:" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    foreach ($platform in $allTokens.Keys) {
        Write-Host "`n[$platform]" -ForegroundColor Green
        foreach ($token in $allTokens[$platform]) {
            Write-Host "  $token" -ForegroundColor White
        }
    }
}

Write-Host ""

# Only show "Press any key" if not in quiet mode (not called from another script)
if (-not $QuietMode) {
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}