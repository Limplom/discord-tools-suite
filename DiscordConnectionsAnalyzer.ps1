# Discord Connected Accounts Analyzer
# Analyzes connected accounts, privacy settings, and security status

param(
    [Parameter(Mandatory=$false)]
    [string]$Token,

    [Parameter(Mandatory=$false)]
    [switch]$ShowTokens,

    [Parameter(Mandatory=$false)]
    [switch]$ExportToFile,

    [Parameter(Mandatory=$false)]
    [switch]$QuietMode  # Suppresses "Press any key" when called from another script
)

# Configuration
$script:config = @{
    UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
    MaxRetries = 3
    RetryDelayMs = 1000
}

function Invoke-DiscordAPI {
    param(
        [string]$Endpoint,
        [string]$Token
    )

    $retryCount = 0
    $maxRetries = $script:config.MaxRetries

    while ($retryCount -le $maxRetries) {
        try {
            $headers = @{
                "Content-Type" = "application/json"
                "User-Agent" = $script:config.UserAgent
                "Authorization" = $Token
            }

            $response = Invoke-RestMethod -Uri "https://discord.com/api/v10$Endpoint" `
                                         -Method Get `
                                         -Headers $headers `
                                         -ErrorAction Stop

            return $response
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__

            if ($statusCode -eq 429) {
                $retryAfter = 2000
                if ($_.Exception.Response.Headers["Retry-After"]) {
                    $retryAfter = [int]$_.Exception.Response.Headers["Retry-After"] * 1000
                }
                Write-Warning "Rate limited on $Endpoint. Retrying after $retryAfter ms..."
                Start-Sleep -Milliseconds $retryAfter
                $retryCount++
                continue
            }

            if ($retryCount -lt $maxRetries -and $statusCode -ge 500) {
                $retryCount++
                $delay = $script:config.RetryDelayMs * $retryCount
                Write-Warning "Server error on $Endpoint (Attempt $retryCount/$maxRetries). Retrying after $delay ms..."
                Start-Sleep -Milliseconds $delay
                continue
            }

            Write-Warning "API Error for $Endpoint : $_"
            return $null
        }
    }

    Write-Warning "Max retries exceeded for $Endpoint"
    return $null
}

function Get-ConnectedAccounts {
    param([string]$Token)

    Write-Host "`n[*] Fetching connected accounts..." -ForegroundColor Cyan

    $connections = Invoke-DiscordAPI -Endpoint "/users/@me/connections" -Token $Token

    if (-not $connections) {
        Write-Host "[!] Failed to fetch connections" -ForegroundColor Red
        return @()
    }

    Write-Host "[+] Found $($connections.Count) connected accounts" -ForegroundColor Green

    return $connections
}

function Get-PrivacyScore {
    param([array]$Connections)

    if ($Connections.Count -eq 0) {
        return 100
    }

    $score = 100
    $issues = @()

    foreach ($conn in $Connections) {
        # Public visibility penalty
        if ($conn.visibility -eq 1) {
            $score -= 5
            $issues += "Public account: $($conn.type)"
        }

        # Show activity penalty
        if ($conn.show_activity) {
            $score -= 3
        }

        # Friend sync penalty
        if ($conn.friend_sync) {
            $score -= 5
            $issues += "Friend sync enabled: $($conn.type)"
        }

        # Access token exposed - CRITICAL
        if ($conn.access_token) {
            $score -= 15
            $issues += "Access token exposed: $($conn.type)"
        }

        # Revoked but still present
        if ($conn.revoked -and $conn.access_token) {
            $score -= 10
            $issues += "Revoked with token: $($conn.type)"
        }
    }

    $score = [Math]::Max(0, $score)

    return @{
        Score = $score
        Issues = $issues
        Grade = if ($score -ge 90) { "A" }
                elseif ($score -ge 75) { "B" }
                elseif ($score -ge 60) { "C" }
                elseif ($score -ge 40) { "D" }
                else { "F" }
    }
}

function Show-AccountOverview {
    param([array]$Connections, [bool]$ShowTokens)

    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "                    CONNECTED ACCOUNTS OVERVIEW                             " -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan

    $active = ($Connections | Where-Object { -not $_.revoked }).Count
    $revoked = ($Connections | Where-Object { $_.revoked }).Count
    $public = ($Connections | Where-Object { $_.visibility -eq 1 }).Count
    $withTokens = ($Connections | Where-Object { $_.access_token }).Count

    Write-Host "`nTotal Accounts: " -ForegroundColor White -NoNewline
    Write-Host $Connections.Count -ForegroundColor Green

    Write-Host "Active: " -ForegroundColor White -NoNewline
    Write-Host $active -ForegroundColor Green -NoNewline
    Write-Host " | Revoked: " -ForegroundColor White -NoNewline
    Write-Host $revoked -ForegroundColor $(if ($revoked -gt 0) { "Yellow" } else { "Green" }) -NoNewline
    Write-Host " | Public: " -ForegroundColor White -NoNewline
    Write-Host $public -ForegroundColor $(if ($public -gt 0) { "Yellow" } else { "Green" })

    if ($withTokens -gt 0) {
        Write-Host "`n" -NoNewline
        Write-Host "WARNING: " -ForegroundColor Red -NoNewline
        Write-Host "$withTokens accounts have exposed access tokens!" -ForegroundColor Yellow
    }

    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "                          ACCOUNT DETAILS                                   " -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan

    foreach ($conn in $Connections | Sort-Object type) {
        $status = if ($conn.revoked) { "REVOKED" } else { "Active" }
        $statusColor = if ($conn.revoked) { "Red" } else { "Green" }

        Write-Host ""
        Write-Host "$($conn.type.ToUpper())" -ForegroundColor Yellow -NoNewline
        Write-Host " - $($conn.name)" -ForegroundColor White

        Write-Host "    Status: " -ForegroundColor Gray -NoNewline
        Write-Host $status -ForegroundColor $statusColor -NoNewline
        Write-Host " | Verified: " -ForegroundColor Gray -NoNewline
        Write-Host $(if ($conn.verified) { "Yes" } else { "No" }) -ForegroundColor $(if ($conn.verified) { "Green" } else { "Red" })

        Write-Host "    Visibility: " -ForegroundColor Gray -NoNewline
        $visText = if ($conn.visibility -eq 1) { "Public" } else { "Private" }
        Write-Host $visText -ForegroundColor $(if ($conn.visibility -eq 1) { "Yellow" } else { "Green" }) -NoNewline
        Write-Host " | Activity: " -ForegroundColor Gray -NoNewline
        Write-Host $(if ($conn.show_activity) { "ON" } else { "OFF" }) -ForegroundColor $(if ($conn.show_activity) { "Yellow" } else { "Green" }) -NoNewline
        Write-Host " | Friend Sync: " -ForegroundColor Gray -NoNewline
        Write-Host $(if ($conn.friend_sync) { "ON" } else { "OFF" }) -ForegroundColor $(if ($conn.friend_sync) { "Red" } else { "Green" })

        # Metadata (Steam, etc.)
        if ($conn.metadata) {
            Write-Host "    Metadata: " -ForegroundColor Gray -NoNewline
            $metaItems = @()
            foreach ($key in $conn.metadata.PSObject.Properties.Name) {
                $metaItems += "$key=$($conn.metadata.$key)"
            }
            Write-Host ($metaItems -join ", ") -ForegroundColor Cyan
        }

        # Integrations
        if ($conn.integrations -and $conn.integrations.Count -gt 0) {
            Write-Host "    Integrations: " -ForegroundColor Gray -NoNewline
            Write-Host "$($conn.integrations.Count) active" -ForegroundColor Cyan
        }

        # Access Token Warning
        if ($conn.access_token) {
            Write-Host "    " -NoNewline
            Write-Host "WARNING: " -ForegroundColor Red -NoNewline
            Write-Host "Access Token Exposed!" -ForegroundColor Yellow
            Write-Host "    Token: " -ForegroundColor Gray -NoNewline
            Write-Host $conn.access_token -ForegroundColor Red
        }
    }
}

function Show-PrivacyScore {
    param([hashtable]$ScoreData)

    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "                          PRIVACY & SECURITY SCORE                          " -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan

    $scoreColor = if ($ScoreData.Score -ge 75) { "Green" }
                  elseif ($ScoreData.Score -ge 50) { "Yellow" }
                  else { "Red" }

    Write-Host "`nScore: " -ForegroundColor White -NoNewline
    Write-Host "$($ScoreData.Score)/100 " -ForegroundColor $scoreColor -NoNewline
    Write-Host "(Grade: $($ScoreData.Grade))" -ForegroundColor $scoreColor

    if ($ScoreData.Issues.Count -gt 0) {
        Write-Host "`nIssues Found:" -ForegroundColor Yellow
        foreach ($issue in $ScoreData.Issues) {
            Write-Host "  - $issue" -ForegroundColor Red
        }
    } else {
        Write-Host "`nNo privacy issues detected!" -ForegroundColor Green
    }

    # Recommendations
    Write-Host "`nRecommendations:" -ForegroundColor Cyan

    if ($ScoreData.Score -lt 100) {
        if ($ScoreData.Issues | Where-Object { $_ -like "*Access token*" }) {
            Write-Host "  ! CRITICAL: Revoke and re-link accounts with exposed tokens" -ForegroundColor Red
        }
        if ($ScoreData.Issues | Where-Object { $_ -like "*Public*" }) {
            Write-Host "  - Consider making sensitive accounts private" -ForegroundColor Yellow
        }
        if ($ScoreData.Issues | Where-Object { $_ -like "*Friend sync*" }) {
            Write-Host "  - Disable friend sync if not needed" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Your privacy settings look good!" -ForegroundColor Green
    }
}

function Show-ActivityStatus {
    param([array]$Connections)

    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "                          ACTIVITY DISPLAY STATUS                           " -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan

    $showing = $Connections | Where-Object { $_.show_activity -and -not $_.revoked }
    $hidden = $Connections | Where-Object { -not $_.show_activity -or $_.revoked }

    if ($showing.Count -gt 0) {
        Write-Host ""
        Write-Host "Accounts Showing Activity:" -ForegroundColor Green
        foreach ($conn in $showing) {
            Write-Host "  [+] $($conn.type) - $($conn.name)" -ForegroundColor White
        }
    }

    if ($hidden.Count -gt 0) {
        Write-Host ""
        Write-Host "Accounts NOT Showing Activity:" -ForegroundColor Gray
        foreach ($conn in $hidden) {
            Write-Host "  [ ] $($conn.type) - $($conn.name)" -ForegroundColor DarkGray
        }
    }
}

function Export-ConnectionsReport {
    param([array]$Connections, [hashtable]$ScoreData)

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $filename = "discord_connections_report_$timestamp.json"

    $export = @{
        GeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        TotalAccounts = $Connections.Count
        PrivacyScore = $ScoreData
        Connections = $Connections | ForEach-Object {
            @{
                Type = $_.type
                Name = $_.name
                ID = $_.id
                Verified = $_.verified
                Revoked = $_.revoked
                Visibility = $_.visibility
                ShowActivity = $_.show_activity
                FriendSync = $_.friend_sync
                TwoWayLink = $_.two_way_link
                HasToken = [bool]$_.access_token
                Metadata = $_.metadata
                Integrations = $_.integrations
            }
        }
    }

    $fullPath = Join-Path (Get-Location) $filename
    $export | ConvertTo-Json -Depth 10 | Out-File $filename

    Write-Host ""
    Write-Host "[+] Report exported to:" -ForegroundColor Green
    Write-Host "  $fullPath" -ForegroundColor Cyan
}

# ============================================
# MAIN EXECUTION
# ============================================

Clear-Host

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "                                                                               " -ForegroundColor Cyan
Write-Host "           Discord Connected Accounts Analyzer v1.0                            " -ForegroundColor Cyan
Write-Host "           ----------------------------------------                            " -ForegroundColor Cyan
Write-Host "                                                                               " -ForegroundColor Cyan
Write-Host "  Analyzes your connected accounts, privacy settings, and security            " -ForegroundColor Cyan
Write-Host "                                                                               " -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan

if (-not $Token) {
    Write-Host "`n[?] Enter your Discord token: " -ForegroundColor Yellow -NoNewline
    $Token = Read-Host
}

if (-not $Token) {
    Write-Host "`n[!] No token provided. Exiting." -ForegroundColor Red
    exit
}

# Validate token format
if ($Token -notmatch '^[A-Za-z0-9\._\-]+$') {
    Write-Host "`n[!] Invalid token format." -ForegroundColor Red
    exit
}

Write-Host "`n[*] Starting analysis..." -ForegroundColor Cyan

$connections = Get-ConnectedAccounts -Token $Token

if ($connections.Count -eq 0) {
    Write-Host "`n[!] No connected accounts found." -ForegroundColor Yellow
    exit
}

# Calculate Privacy Score
$scoreData = Get-PrivacyScore -Connections $connections

# Display Results
Show-AccountOverview -Connections $connections -ShowTokens $ShowTokens
Show-PrivacyScore -ScoreData $scoreData
Show-ActivityStatus -Connections $connections

# Export if requested
if ($ExportToFile) {
    Export-ConnectionsReport -Connections $connections -ScoreData $scoreData
}

Write-Host ""
Write-Host "[*] Analysis complete!" -ForegroundColor Green

# Only show "Press any key" if not in quiet mode (not called from another script)
if (-not $QuietMode) {
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
