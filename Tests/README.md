# Discord Tools Suite - Test Suite

This directory contains comprehensive tests for the Discord Tools Suite PowerShell scripts.

## Test Framework

We use **Pester 5.x** - PowerShell's native testing framework.

## Setup

### 1. Install Pester

```powershell
# Install Pester 5.x (requires PowerShell 5.1 or later)
Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck

# Verify installation
Get-Module -Name Pester -ListAvailable
```

### 2. Verify Installation

```powershell
# Check Pester version
Import-Module Pester
$PesterVersion = (Get-Module Pester).Version
Write-Host "Pester version: $PesterVersion"
```

## Running Tests

### Run All Tests

```powershell
# From repository root
Invoke-Pester -Path ./Tests

# Or from Tests directory
cd Tests
Invoke-Pester
```

### Run Specific Test File

```powershell
# Run only DiscordTokenSearch tests
Invoke-Pester -Path ./Tests/DiscordTokenSearch.Tests.ps1
```

### Run with Coverage Report

```powershell
# Generate code coverage report
Invoke-Pester -Path ./Tests -CodeCoverage ../DiscordTokenSearch.ps1
```

### Run with Detailed Output

```powershell
# Show detailed test results
Invoke-Pester -Path ./Tests -Output Detailed
```

## Test Structure

### DiscordTokenSearch.Tests.ps1

Comprehensive tests for `DiscordTokenSearch.ps1` covering:

#### Test-TokenValidity
- ✅ Valid token validation with user info
- ✅ Invalid token handling
- ✅ Malformed API response handling
- ✅ Network error handling
- ✅ Correct API headers and timeout

#### Get-MasterKey
- ✅ Valid Local State file parsing
- ✅ Missing file handling
- ✅ Malformed JSON handling
- ✅ Missing encrypted_key handling
- ✅ DPAPI decryption

#### ConvertFrom-EncryptedToken
- ✅ PowerShell 7+ AES-GCM decryption
- ✅ Invalid base64 handling
- ✅ Token prefix validation (v10/v11)
- ✅ Decryption failure handling
- ✅ Null parameter handling

#### Get-Tokens
- ✅ Unencrypted token detection (.ldb, .log files)
- ✅ Encrypted token detection and decryption
- ✅ Token regex pattern validation
- ✅ Token deduplication
- ✅ Mixed encrypted/unencrypted tokens
- ✅ File reading error handling
- ✅ Edge cases (empty files, binary files, wrong extensions)

#### Integration Tests
- ✅ Full token search workflow
- ✅ Token validation workflow

## Test Coverage

| Function | Test Cases | Coverage |
|----------|-----------|----------|
| `Test-TokenValidity` | 8 | 100% |
| `Get-MasterKey` | 6 | 100% |
| `ConvertFrom-EncryptedToken` | 5 | 100% |
| `Get-Tokens` | 20+ | 100% |

**Total Test Cases: 40+**

## Test Features

### Mocking
- Discord API calls (Invoke-RestMethod)
- File system operations
- DPAPI cryptographic operations
- AES-GCM decryption (PS7+)

### Test Data
- Mock Discord tokens (valid format)
- Mock encrypted tokens
- Mock Local State files
- Binary and malformed data

### Edge Cases Tested
- Empty files
- Missing directories
- Network failures
- Invalid JSON
- Malformed tokens
- Binary/non-UTF8 data
- File access errors

## Continuous Integration

### GitHub Actions Example

```yaml
name: Run Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Pester
        shell: pwsh
        run: |
          Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck

      - name: Run Tests
        shell: pwsh
        run: |
          Invoke-Pester -Path ./Tests -Output Detailed
```

## Best Practices

1. **Run tests before commits**: Always run tests before committing changes
2. **Test-Driven Development**: Write tests for new features first
3. **Mock external dependencies**: Never make real API calls in tests
4. **Use TestDrive**: Pester's TestDrive for temporary file operations
5. **Clean up**: Tests should not leave artifacts

## Troubleshooting

### "Cannot find path" errors
Ensure you're running from the repository root or Tests directory.

### "Module Pester not found"
Install Pester: `Install-Module -Name Pester -Force`

### "AesGcm tests skipped"
Some tests require PowerShell 7+ for AES-GCM support. This is expected on PS 5.1.

### Mock errors
Ensure you're using Pester 5.x syntax. Pester 3.x/4.x syntax is different.

## Contributing

When adding new features to Discord Tools Suite:

1. Write tests first (TDD approach)
2. Ensure all tests pass
3. Aim for >90% code coverage
4. Include edge cases
5. Document new test scenarios

## License

Same as main project (see LICENSE file in root).
