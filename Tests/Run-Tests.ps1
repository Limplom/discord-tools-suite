# Test Runner for Discord Tools Suite
# This script checks for Pester installation and runs all tests

param(
    [Parameter(Mandatory=$false)]
    [switch]$Coverage,  # Generate code coverage report

    [Parameter(Mandatory=$false)]
    [switch]$Detailed,  # Show detailed output

    [Parameter(Mandatory=$false)]
    [string]$TestFile   # Run specific test file (e.g., "DiscordTokenSearch.Tests.ps1")
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Discord Tools Suite - Test Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Pester is installed
$pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1

if (-not $pesterModule) {
    Write-Host "[ERROR] Pester is not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "To install Pester, run:" -ForegroundColor Yellow
    Write-Host "  Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Check Pester version
$pesterVersion = $pesterModule.Version
Write-Host "[OK] Pester $pesterVersion detected" -ForegroundColor Green

if ($pesterVersion.Major -lt 5) {
    Write-Host "[WARNING] Pester 5.x or later is recommended" -ForegroundColor Yellow
    Write-Host "Current version: $pesterVersion" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To upgrade:" -ForegroundColor Yellow
    Write-Host "  Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck" -ForegroundColor White
    Write-Host ""
}

# Import Pester
Import-Module Pester -MinimumVersion 5.0 -ErrorAction SilentlyContinue

if (-not (Get-Module Pester)) {
    Write-Host "[ERROR] Failed to import Pester module" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Determine test path
$testPath = if ($TestFile) {
    $fullPath = Join-Path $PSScriptRoot $TestFile
    if (-not (Test-Path $fullPath)) {
        Write-Host "[ERROR] Test file not found: $TestFile" -ForegroundColor Red
        exit 1
    }
    $fullPath
} else {
    $PSScriptRoot
}

# Build Pester configuration
$configuration = [PesterConfiguration]::Default

# Set test path
$configuration.Run.Path = $testPath

# Set output verbosity
if ($Detailed) {
    $configuration.Output.Verbosity = 'Detailed'
} else {
    $configuration.Output.Verbosity = 'Normal'
}

# Set code coverage
if ($Coverage) {
    Write-Host "[*] Code coverage analysis enabled" -ForegroundColor Cyan
    Write-Host ""

    $sourceFiles = @(
        (Join-Path (Split-Path $PSScriptRoot) "DiscordTokenSearch.ps1")
    )

    # Filter to only existing files
    $existingFiles = $sourceFiles | Where-Object { Test-Path $_ }

    if ($existingFiles.Count -gt 0) {
        $configuration.CodeCoverage.Enabled = $true
        $configuration.CodeCoverage.Path = $existingFiles
        $configuration.CodeCoverage.OutputFormat = 'JaCoCo'
        $configuration.CodeCoverage.OutputPath = Join-Path $PSScriptRoot 'coverage.xml'
    }
}

# Run tests
Write-Host "Running tests..." -ForegroundColor Cyan
Write-Host ""

try {
    $result = Invoke-Pester -Configuration $configuration

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Test Results Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total:  $($result.TotalCount)" -ForegroundColor Gray
    Write-Host "Passed: $($result.PassedCount)" -ForegroundColor Green
    Write-Host "Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { "Red" } else { "Gray" })
    Write-Host "Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
    Write-Host ""

    if ($result.FailedCount -gt 0) {
        Write-Host "[FAILED] Some tests failed!" -ForegroundColor Red
        Write-Host ""
        exit 1
    } else {
        Write-Host "[SUCCESS] All tests passed!" -ForegroundColor Green
        Write-Host ""

        if ($Coverage -and $configuration.CodeCoverage.Enabled) {
            $coveragePercent = [math]::Round(($result.CodeCoverage.CoveragePercent), 2)
            Write-Host "Code Coverage: $coveragePercent%" -ForegroundColor $(
                if ($coveragePercent -ge 80) { "Green" }
                elseif ($coveragePercent -ge 60) { "Yellow" }
                else { "Red" }
            )
            Write-Host "Coverage report: $(Join-Path $PSScriptRoot 'coverage.xml')" -ForegroundColor Gray
            Write-Host ""
        }
        exit 0
    }
}
catch {
    Write-Host ""
    Write-Host "[ERROR] Test execution failed!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    exit 1
}
