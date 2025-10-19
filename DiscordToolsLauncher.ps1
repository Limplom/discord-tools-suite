<#
.SYNOPSIS
    Discord Tools Suite - Main Launcher
.DESCRIPTION
    Interactive launcher for all Discord analysis and security tools
.NOTES
    Version: 1.0
    Author: Discord Tools Suite
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Token
)

# Script configuration
$script:ToolsPath = $PSScriptRoot
$script:CurrentToken = $Token
$script:CurrentUser = $null

# Set console window size to fit main menu
function Set-ConsoleSize {
    try {
        # Check if running in Windows Terminal
        if ($env:WT_SESSION) {
            # Windows Terminal - use escape sequences
            $width = 79
            $height = 35

            # ANSI escape sequence to resize window (CSI 8 ; height ; width t)
            $esc = [char]27
            Write-Host "$esc[8;$height;${width}t" -NoNewline
        }
        else {
            # Classic console host - use RawUI
            $console = $Host.UI.RawUI
            $bufferSize = $console.BufferSize
            $windowSize = $console.WindowSize

            # Set width to 79 characters (fits menu perfectly)
            $newWidth = 79
            $newHeight = 35  # Enough for menu + breathing room

            # Update buffer first (must be >= window size)
            if ($bufferSize.Width -lt $newWidth) {
                $bufferSize.Width = $newWidth
            }
            $bufferSize.Height = 3000  # Large buffer for scrolling
            $console.BufferSize = $bufferSize

            # Then update window size
            $windowSize.Width = $newWidth
            $windowSize.Height = $newHeight
            $console.WindowSize = $windowSize
        }
    }
    catch {
        # Silently fail if we can't resize
    }
}

# Set window size on launch
Set-ConsoleSize
$script:Tools = @{
    '1' = @{
        Name = 'Discord Token Search'
        File = 'DiscordTokenSearch.ps1'
        Description = 'Find encrypted & unencrypted tokens (PS7+ recommended)'
        RequiresToken = $false
    }
    '2' = @{
        Name = 'Discord API Explorer'
        File = 'DiscordAPIExplorer.ps1'
        Description = 'Explore available Discord API endpoints'
        RequiresToken = $true
    }
    '3' = @{
        Name = 'Discord Affinity Analyzer'
        File = 'DiscordAffinityAnalyzer.ps1'
        Description = 'Analyze server activity and mentions'
        RequiresToken = $true
    }
    '4' = @{
        Name = 'Discord Connections Analyzer'
        File = 'DiscordConnectionsAnalyzer.ps1'
        Description = 'Audit connected accounts & privacy'
        RequiresToken = $true
    }
}

function Get-DiscordUser {
    param(
        [string]$Token
    )

    try {
        $headers = @{
            "Authorization" = $Token
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        }

        $response = Invoke-RestMethod -Uri "https://discord.com/api/v10/users/@me" -Headers $headers -Method Get -ErrorAction Stop

        return @{
            Username = $response.username
            GlobalName = $response.global_name
            Discriminator = $response.discriminator
            Id = $response.id
        }
    } catch {
        return $null
    }
}

function Show-Banner {
    Clear-Host
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan

    # Center "DISCORD TOOLS SUITE - LAUNCHER v1.0"
    $title1 = "DISCORD TOOLS SUITE - LAUNCHER v1.0"
    $padding1 = [Math]::Max(0, (79 - $title1.Length) / 2)
    Write-Host (' ' * [int]$padding1) -NoNewline
    Write-Host $title1 -ForegroundColor Cyan

    # Center "------------------------------------"
    $title2 = "------------------------------------"
    $padding2 = [Math]::Max(0, (79 - $title2.Length) / 2)
    Write-Host (' ' * [int]$padding2) -NoNewline
    Write-Host $title2 -ForegroundColor Cyan

    Write-Host "" -ForegroundColor Cyan

    # Center "Comprehensive Discord API Analysis & Security Testing Tools"
    $subtitle = "Comprehensive Discord API Analysis & Security Testing Tools"
    $padding3 = [Math]::Max(0, (79 - $subtitle.Length) / 2)
    Write-Host (' ' * [int]$padding3) -NoNewline
    Write-Host $subtitle -ForegroundColor Cyan

    Write-Host "" -ForegroundColor Cyan

    # Center "AVAILABLE TOOLS"
    $headerText = "AVAILABLE TOOLS"
    $padding = [Math]::Max(0, (79 - $headerText.Length) / 2)
    Write-Host (' ' * [int]$padding) -NoNewline
    Write-Host $headerText -ForegroundColor Cyan
}

function Show-Menu {
    # Token status line - centered
    if ($script:CurrentToken) {
        # Try to get user info if not already cached
        if (-not $script:CurrentUser) {
            $script:CurrentUser = Get-DiscordUser -Token $script:CurrentToken
        }

        # Create masked token (first 6 chars ... last 4 chars)
        $maskedToken = $script:CurrentToken.Substring(0, [Math]::Min(6, $script:CurrentToken.Length)) + "..." +
                       $script:CurrentToken.Substring([Math]::Max(0, $script:CurrentToken.Length - 4))

        # Build status string to calculate centering
        $displayName = if ($script:CurrentUser) {
            if ($script:CurrentUser.GlobalName) { $script:CurrentUser.GlobalName } else { $script:CurrentUser.Username }
        } else { "" }

        $statusText = if ($displayName) {
            "[*] Token Status: LOADED [$displayName] ($maskedToken)"
        } else {
            "[*] Token Status: LOADED ($maskedToken)"
        }

        $padding = [Math]::Max(0, (79 - $statusText.Length) / 2)
        Write-Host (' ' * [int]$padding) -NoNewline
        Write-Host "[*] Token Status: " -ForegroundColor White -NoNewline
        Write-Host "LOADED " -ForegroundColor Green -NoNewline

        if ($displayName) {
            Write-Host "[$displayName] " -ForegroundColor Cyan -NoNewline
        }

        Write-Host "($maskedToken)" -ForegroundColor DarkGray
    } else {
        # Center "[*] Token Status: NOT SET"
        $statusText = "[*] Token Status: NOT SET"
        $padding = [Math]::Max(0, (79 - $statusText.Length) / 2)
        Write-Host (' ' * [int]$padding) -NoNewline
        Write-Host "[*] Token Status: " -ForegroundColor White -NoNewline
        Write-Host "NOT SET" -ForegroundColor Yellow
    }

    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""

    foreach ($key in ($script:Tools.Keys | Sort-Object)) {
        $tool = $script:Tools[$key]
        $tokenReq = if ($tool.RequiresToken) { "[TOKEN REQUIRED]" } else { "[NO TOKEN]" }
        $tokenColor = if ($tool.RequiresToken) { "Yellow" } else { "Green" }

        Write-Host "  [$key] " -ForegroundColor White -NoNewline
        Write-Host $tokenReq -ForegroundColor $tokenColor -NoNewline
        Write-Host " $($tool.Name)" -ForegroundColor Cyan
        Write-Host "      $($tool.Description)" -ForegroundColor Gray
        Write-Host ""
    }

    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host " " -NoNewline
    Write-Host "[T]" -ForegroundColor White -NoNewline
    Write-Host " Set/Update Token        " -ForegroundColor Magenta -NoNewline
    Write-Host "[H]" -ForegroundColor White -NoNewline
    Write-Host " Help & Documentation        " -ForegroundColor Magenta -NoNewline
    Write-Host "[Q]" -ForegroundColor White -NoNewline
    Write-Host " Quit" -ForegroundColor Red
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Set-DiscordToken {
    Write-Host ""
    Write-Host "[*] Enter Discord Token (or press ENTER to cancel):" -ForegroundColor Yellow
    Write-Host ""

    $newToken = Read-Host "Token"

    if ([string]::IsNullOrWhiteSpace($newToken)) {
        Write-Host ""
        Write-Host "[!] Token not changed" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }

    # Validate token format
    if ($newToken -match '^[A-Za-z0-9_-]{24}\.[A-Za-z0-9_-]{6}\.[A-Za-z0-9_-]{27,}$') {
        Write-Host ""
        Write-Host "[*] Validating token..." -ForegroundColor Yellow

        # Try to fetch user info to validate token
        $userInfo = Get-DiscordUser -Token $newToken

        if ($userInfo) {
            $script:CurrentToken = $newToken
            $script:CurrentUser = $userInfo

            Write-Host "[+] Token validated successfully!" -ForegroundColor Green
            $displayName = if ($userInfo.GlobalName) { $userInfo.GlobalName } else { $userInfo.Username }
            Write-Host "    Logged in as: " -ForegroundColor Gray -NoNewline
            Write-Host "$displayName" -ForegroundColor Cyan
            Start-Sleep -Seconds 2
        } else {
            Write-Host "[!] Token validation failed!" -ForegroundColor Red
            Write-Host "    The token format is correct but may be invalid or expired." -ForegroundColor Gray
            Write-Host "    Token was NOT saved." -ForegroundColor Yellow
            Start-Sleep -Seconds 3
        }
    } else {
        Write-Host ""
        Write-Host "[!] Invalid token format!" -ForegroundColor Red
        Write-Host "    Expected format: [24 chars].[6 chars].[27+ chars]" -ForegroundColor Gray
        Start-Sleep -Seconds 2
    }
}

function Show-Help {
    Clear-Host
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "                              HELP & DOCUMENTATION                             " -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "QUICK START:" -ForegroundColor Yellow
    Write-Host "  1. Set your Discord token using option [T]" -ForegroundColor White
    Write-Host "  2. Select a tool from the menu (1-5)" -ForegroundColor White
    Write-Host "  3. View results and analysis" -ForegroundColor White
    Write-Host ""

    Write-Host "TOOL DESCRIPTIONS:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] Token Search" -ForegroundColor Cyan
    Write-Host "      Scans your system for Discord tokens:" -ForegroundColor Gray
    Write-Host "      - Finds both encrypted and unencrypted tokens" -ForegroundColor Gray
    Write-Host "      - Discord clients (Stable, Canary, PTB)" -ForegroundColor Gray
    Write-Host "      - Browsers (Chrome, Edge, Opera, etc.)" -ForegroundColor Gray
    Write-Host "      - PowerShell 7+ recommended for AES-GCM decryption" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "  [2] API Explorer" -ForegroundColor Cyan
    Write-Host "      Tests 20+ Discord API endpoints to discover:" -ForegroundColor Gray
    Write-Host "      - Available data and permissions" -ForegroundColor Gray
    Write-Host "      - User info, guilds, billing, etc." -ForegroundColor Gray
    Write-Host "      - Export results to JSON file" -ForegroundColor Gray
    Write-Host ""

    Write-Host "  [3] Affinity Analyzer" -ForegroundColor Cyan
    Write-Host "      Analyzes Discord server activity:" -ForegroundColor Gray
    Write-Host "      - Server affinity scores (engagement metrics)" -ForegroundColor Gray
    Write-Host "      - Mention tracking and statistics" -ForegroundColor Gray
    Write-Host "      - Channel activity breakdown" -ForegroundColor Gray
    Write-Host ""

    Write-Host "  [4] Connections Analyzer" -ForegroundColor Cyan
    Write-Host "      Audits connected third-party accounts:" -ForegroundColor Gray
    Write-Host "      - Privacy score (0-100 with grade)" -ForegroundColor Gray
    Write-Host "      - Detects exposed access tokens" -ForegroundColor Gray
    Write-Host "      - Shows activity display settings" -ForegroundColor Gray
    Write-Host ""

    Write-Host "SECURITY TIPS:" -ForegroundColor Yellow
    Write-Host "  - Never share your Discord token with anyone" -ForegroundColor White
    Write-Host "  - Enable 2FA for extra security" -ForegroundColor White
    Write-Host "  - Regularly audit connected accounts" -ForegroundColor White
    Write-Host "  - Revoke tokens if exposed/leaked" -ForegroundColor White
    Write-Host ""

    Write-Host "TOKEN FORMAT:" -ForegroundColor Yellow
    Write-Host "  Valid Discord tokens follow this pattern:" -ForegroundColor White
    Write-Host "  [24 chars].[6 chars].[27+ chars]" -ForegroundColor Gray
    Write-Host "  Example: MXXXXXXXXXXXXXXXXXX.XXXXXX.XXXXXXXXXXXXXXXXXXXXXXXXXXX" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Press any key to return to main menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Start-Tool {
    param(
        [string]$ToolKey
    )

    if (-not $script:Tools.ContainsKey($ToolKey)) {
        Write-Host ""
        Write-Host "[!] Invalid selection" -ForegroundColor Red
        Start-Sleep -Seconds 1
        return
    }

    $tool = $script:Tools[$ToolKey]
    $toolPath = Join-Path $script:ToolsPath $tool.File

    # Check if tool file exists
    if (-not (Test-Path $toolPath)) {
        Write-Host ""
        Write-Host "[!] Tool file not found: $($tool.File)" -ForegroundColor Red
        Write-Host "    Expected path: $toolPath" -ForegroundColor Gray
        Start-Sleep -Seconds 2
        return
    }

    # Check token requirement
    if ($tool.RequiresToken -and [string]::IsNullOrWhiteSpace($script:CurrentToken)) {
        Write-Host ""
        Write-Host "[!] This tool requires a Discord token!" -ForegroundColor Red
        Write-Host "    Please set a token first using option [T]" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }

    Clear-Host
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "  Starting: $($tool.Name)" -ForegroundColor Yellow
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""

    try {
        # Execute tool based on type
        switch ($ToolKey) {
            '1' {
                # Token Search - no parameters needed
                & $toolPath -QuietMode
            }
            '2' {
                # API Explorer - requires token, ask for save option
                Write-Host "[?] Save results to file? (Y/N): " -ForegroundColor Yellow -NoNewline
                $saveChoice = Read-Host
                Write-Host ""

                if ($saveChoice -eq 'Y' -or $saveChoice -eq 'y') {
                    & $toolPath -Token $script:CurrentToken -SaveToFile -QuietMode
                } else {
                    & $toolPath -Token $script:CurrentToken -QuietMode
                }
            }
            '3' {
                # Affinity Analyzer - requires token
                & $toolPath -Token $script:CurrentToken -QuietMode
            }
            '4' {
                # Connections Analyzer - requires token, ask for export option
                Write-Host "[?] Export results to file? (Y/N): " -ForegroundColor Yellow -NoNewline
                $exportChoice = Read-Host
                Write-Host ""

                if ($exportChoice -eq 'Y' -or $exportChoice -eq 'y') {
                    & $toolPath -Token $script:CurrentToken -ExportToFile -QuietMode
                } else {
                    & $toolPath -Token $script:CurrentToken -QuietMode
                }
            }
        }

    } catch {
        Write-Host ""
        Write-Host "[!] Error executing tool: $_" -ForegroundColor Red
    }

    # Always wait for user input before returning to menu
    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "Press any key to return to main menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Start-Launcher {
    while ($true) {
        Show-Banner
        Show-Menu

        Write-Host "Select an option: " -ForegroundColor White -NoNewline
        $choice = Read-Host

        switch ($choice.ToUpper()) {
            'T' { Set-DiscordToken }
            'H' { Show-Help }
            'Q' {
                Clear-Host
                Write-Host ""
                Write-Host "[*] Thanks for using Discord Tools Suite!" -ForegroundColor Cyan
                Write-Host ""
                exit
            }
            { $_ -in @('1', '2', '3', '4') } {
                Start-Tool -ToolKey $_
            }
            default {
                Write-Host ""
                Write-Host "[!] Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

# Entry point
Write-Host ""
Write-Host "[*] Initializing Discord Tools Suite..." -ForegroundColor Cyan
Start-Sleep -Milliseconds 500

# Check PowerShell version and recommend PS7
if ($PSVersionTable.PSVersion.Major -lt 7) {
    # Check if PowerShell 7 is installed
    $ps7Installed = $false
    try {
        $ps7Path = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($ps7Path) {
            $ps7Installed = $true
        }
    } catch { }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    if ($ps7Installed) {
        Write-Host "PowerShell 7+ ist installiert!" -ForegroundColor Green
    } else {
        Write-Host "PowerShell 7+ wird empfohlen!" -ForegroundColor Yellow
    }
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Einige Tools benoetigen PowerShell 7+ fuer volle Funktionalitaet:" -ForegroundColor White
    Write-Host "  - Token Search: AES-GCM verschluesselte Discord-Tokens entschluesseln" -ForegroundColor Gray
    Write-Host ""

    if ($ps7Installed) {
        Write-Host "Moechten Sie den Launcher in PowerShell 7 starten? (J/N): " -ForegroundColor Yellow -NoNewline
        $restart = Read-Host

        if ($restart -eq 'J' -or $restart -eq 'j' -or $restart -eq 'Y' -or $restart -eq 'y') {
            Write-Host ""
            Write-Host "[*] Starte in PowerShell 7..." -ForegroundColor Cyan
            Start-Process pwsh -ArgumentList "-NoExit", "-File", "`"$PSCommandPath`"", "-Token", "`"$Token`""
            exit
        } else {
            Write-Host ""
            Write-Host "[*] Fahre mit PowerShell $($PSVersionTable.PSVersion.Major) fort..." -ForegroundColor Gray
        }
    } else {
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
                    Write-Host "[*] Starte Launcher neu in PowerShell 7..." -ForegroundColor Cyan
                    Start-Process pwsh -ArgumentList "-NoExit", "-File", "`"$PSCommandPath`"", "-Token", "`"$Token`""
                    exit
                } else {
                    Write-Host ""
                    Write-Host "[FEHLER] Installation fehlgeschlagen." -ForegroundColor Red
                    Write-Host "[*] Fahre mit PowerShell $($PSVersionTable.PSVersion.Major) fort..." -ForegroundColor Yellow
                }
            } catch {
                Write-Host ""
                Write-Host "[FEHLER] winget nicht gefunden." -ForegroundColor Red
                Write-Host "Bitte installiere PowerShell 7 manuell: https://aka.ms/powershell" -ForegroundColor Yellow
                Write-Host "[*] Fahre mit PowerShell $($PSVersionTable.PSVersion.Major) fort..." -ForegroundColor Yellow
            }
        } else {
            Write-Host ""
            Write-Host "[*] Fahre mit PowerShell $($PSVersionTable.PSVersion.Major) fort..." -ForegroundColor Gray
        }
    }
    Write-Host ""
    Start-Sleep -Milliseconds 500
}

# Check if tools exist
$missingTools = @()
foreach ($toolKey in $script:Tools.Keys) {
    $toolPath = Join-Path $script:ToolsPath $script:Tools[$toolKey].File
    if (-not (Test-Path $toolPath)) {
        $missingTools += $script:Tools[$toolKey].Name
    }
}

if ($missingTools.Count -gt 0) {
    Write-Host ""
    Write-Host "[!] WARNING: Some tools are missing:" -ForegroundColor Yellow
    foreach ($missing in $missingTools) {
        Write-Host "    - $missing" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Press any key to continue anyway..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Start the launcher
Start-Launcher
