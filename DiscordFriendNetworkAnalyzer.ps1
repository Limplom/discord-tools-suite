# Discord Friend Network Analyzer
# Analyzes friend relationships, mutual servers, and social network patterns

param(
    [Parameter(Mandatory=$false)]
    [string]$Token,

    [Parameter(Mandatory=$false)]
    [switch]$ExportToFile,

    [Parameter(Mandatory=$false)]
    [switch]$QuietMode  # Suppresses "Press any key" when called from another script
)

# Configuration
$script:config = @{
    UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
}

function Invoke-DiscordAPI {
    param(
        [string]$Endpoint,
        [string]$Token,
        [string]$Method = "Get"
    )

    try {
        $headers = @{
            "Content-Type" = "application/json"
            "User-Agent" = $script:config.UserAgent
            "Authorization" = $Token
        }

        $response = Invoke-RestMethod -Uri "https://discord.com/api/v10$Endpoint" `
                                     -Method $Method `
                                     -Headers $headers `
                                     -ErrorAction Stop

        return $response
    }
    catch {
        Write-Warning "API Error for $Endpoint : $_"
        return $null
    }
}

function Get-UserInfo {
    param([string]$Token)

    Write-Host "[*] Fetching user information..." -ForegroundColor Cyan

    $user = Invoke-DiscordAPI -Endpoint "/users/@me" -Token $Token

    if ($user) {
        $displayName = if ($user.global_name) { $user.global_name } else { $user.username }
        Write-Host "[+] Logged in as: $displayName" -ForegroundColor Green
        return $user
    }

    Write-Host "[!] Failed to fetch user info" -ForegroundColor Red
    return $null
}

function Get-UserRelationships {
    param([string]$Token)

    Write-Host "[*] Fetching friend relationships..." -ForegroundColor Cyan

    $relationships = Invoke-DiscordAPI -Endpoint "/users/@me/relationships" -Token $Token

    if (-not $relationships) {
        Write-Host "[!] Failed to fetch relationships" -ForegroundColor Red
        return @()
    }

    # Filter only friends (type = 1)
    $friends = $relationships | Where-Object { $_.type -eq 1 }

    Write-Host "[+] Found $($friends.Count) friends" -ForegroundColor Green

    return $friends
}

function Get-UserGuilds {
    param([string]$Token)

    Write-Host "[*] Fetching your servers..." -ForegroundColor Cyan

    $guilds = Invoke-DiscordAPI -Endpoint "/users/@me/guilds" -Token $Token

    if (-not $guilds) {
        Write-Host "[!] Failed to fetch guilds" -ForegroundColor Red
        return @()
    }

    Write-Host "[+] Found $($guilds.Count) servers" -ForegroundColor Green

    return $guilds
}

function Get-GuildMembers {
    param(
        [string]$Token,
        [string]$GuildId,
        [int]$Limit = 1000
    )

    # Note: This endpoint may require special permissions
    # We'll try to fetch members, but it might not work for all servers
    $members = Invoke-DiscordAPI -Endpoint "/guilds/$GuildId/members?limit=$Limit" -Token $Token

    Start-Sleep -Milliseconds 300  # Rate limiting

    return $members
}

function Analyze-FriendNetwork {
    param(
        [array]$Friends,
        [array]$Guilds,
        [string]$Token,
        [string]$CurrentUserId
    )

    Write-Host "`n[*] Analyzing friend network..." -ForegroundColor Cyan

    $networkData = @{
        FriendDetails = @()
        MutualServers = @{}
        FriendsByServer = @{}
    }

    # Note: Regular user tokens cannot fetch server member lists (API limitation)
    # We'll analyze friends based on available data without server member lookups

    # Analyze each friend
    foreach ($friend in $Friends) {
        $friendId = $friend.user.id
        $friendName = if ($friend.user.global_name) {
            $friend.user.global_name
        } else {
            "$($friend.user.username)#$($friend.user.discriminator)"
        }

        $friendData = @{
            Id = $friendId
            Name = $friendName
            Username = $friend.user.username
            Discriminator = $friend.user.discriminator
            Avatar = $friend.user.avatar
            MutualServers = @()
            MutualServerCount = 0
            Since = $friend.since
        }

        $networkData.FriendDetails += $friendData
    }

    Write-Host "[+] Network analysis complete!" -ForegroundColor Green

    return $networkData
}

function Show-NetworkStatistics {
    param(
        [hashtable]$NetworkData,
        [array]$Guilds,
        [int]$TotalFriends
    )

    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "                    FRIEND NETWORK ANALYSIS                                 " -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan

    # Overall Statistics
    Write-Host "`n=== OVERALL STATISTICS ===" -ForegroundColor Yellow
    Write-Host "Total Friends: " -ForegroundColor White -NoNewline
    Write-Host $TotalFriends -ForegroundColor Green

    Write-Host "Total Servers: " -ForegroundColor White -NoNewline
    Write-Host $Guilds.Count -ForegroundColor Green

    # Friend alphabetical list with details
    if ($NetworkData.FriendDetails.Count -gt 0) {
        Write-Host "`n=== FRIEND LIST (Alphabetical) ===" -ForegroundColor Yellow

        $sortedFriends = $NetworkData.FriendDetails | Sort-Object -Property Name

        $displayCount = [Math]::Min(20, $sortedFriends.Count)

        for ($i = 0; $i -lt $displayCount; $i++) {
            $friend = $sortedFriends[$i]
            Write-Host "  $($i + 1). " -ForegroundColor White -NoNewline
            Write-Host "$($friend.Name)" -ForegroundColor Cyan -NoNewline
            Write-Host " (@$($friend.Username))" -ForegroundColor DarkGray
        }

        if ($sortedFriends.Count -gt 20) {
            Write-Host "`n  ... and $($sortedFriends.Count - 20) more friends" -ForegroundColor Gray
            Write-Host "  (Total: $($sortedFriends.Count) friends)" -ForegroundColor Gray
        }
    }

    # Server overview
    if ($Guilds.Count -gt 0) {
        Write-Host "`n=== YOUR SERVERS ===" -ForegroundColor Yellow
        Write-Host "You are a member of $($Guilds.Count) servers:" -ForegroundColor White
        Write-Host ""

        $displayServerCount = [Math]::Min(10, $Guilds.Count)

        for ($i = 0; $i -lt $displayServerCount; $i++) {
            $guild = $Guilds[$i]
            Write-Host "  $($i + 1). " -ForegroundColor White -NoNewline
            Write-Host "$($guild.name)" -ForegroundColor Yellow -NoNewline

            if ($guild.owner) {
                Write-Host " (Owner)" -ForegroundColor Magenta
            } else {
                Write-Host ""
            }
        }

        if ($Guilds.Count -gt 10) {
            Write-Host "`n  ... and $($Guilds.Count - 10) more servers" -ForegroundColor Gray
        }
    }

    # Note about limitations
    Write-Host "`n=== NOTE ===" -ForegroundColor Yellow
    Write-Host "Mutual server analysis is not available due to Discord API limitations." -ForegroundColor Gray
    Write-Host "Regular user tokens cannot access server member lists." -ForegroundColor Gray
    Write-Host "This tool shows your friends list and server memberships." -ForegroundColor Gray
}

function Show-DetailedFriendList {
    param(
        [array]$FriendDetails
    )

    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "                    COMPLETE FRIEND LIST                                    " -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan

    if ($FriendDetails.Count -eq 0) {
        Write-Host "`nNo friends found." -ForegroundColor Gray
        return
    }

    Write-Host "`nShowing all $($FriendDetails.Count) friends:" -ForegroundColor White
    Write-Host ""

    # Sort friends alphabetically
    $sortedFriends = $FriendDetails | Sort-Object -Property Name

    foreach ($friend in $sortedFriends) {
        Write-Host "  • " -ForegroundColor Gray -NoNewline
        Write-Host "$($friend.Name)" -ForegroundColor Cyan -NoNewline
        Write-Host " (@$($friend.Username)#$($friend.Discriminator))" -ForegroundColor DarkGray

        if ($friend.Id) {
            Write-Host "    ID: $($friend.Id)" -ForegroundColor DarkGray
        }
    }

    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "Total: $($FriendDetails.Count) friends" -ForegroundColor Green
}

function Export-Results {
    param(
        [hashtable]$NetworkData,
        [int]$TotalFriends,
        [int]$TotalServers
    )

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $filename = "discord_friend_network_$timestamp.json"

    $export = @{
        GeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Statistics = @{
            TotalFriends = $TotalFriends
            TotalServers = $TotalServers
            ServersWithFriends = $NetworkData.FriendsByServer.Count
        }
        FriendDetails = $NetworkData.FriendDetails
        ServerFriendCounts = @{}
    }

    # Add server friend counts
    foreach ($guildId in $NetworkData.FriendsByServer.Keys) {
        $serverData = $NetworkData.FriendsByServer[$guildId]
        $export.ServerFriendCounts[$serverData.Name] = $serverData.Friends.Count
    }

    $export | ConvertTo-Json -Depth 10 | Out-File $filename

    Write-Host "`n[+] Network analysis exported to: " -ForegroundColor Green -NoNewline
    Write-Host $filename -ForegroundColor Yellow
}

# ============================================
# MAIN EXECUTION
# ============================================

Clear-Host

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "                                                                               " -ForegroundColor Cyan
Write-Host "                Discord Friend Network Analyzer v1.0                           " -ForegroundColor Cyan
Write-Host "                ----------------------------------------                       " -ForegroundColor Cyan
Write-Host "                                                                               " -ForegroundColor Cyan
Write-Host "  Analyzes friend relationships, mutual servers, and                          " -ForegroundColor Cyan
Write-Host "  social network patterns                                                     " -ForegroundColor Cyan
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

Write-Host "`n[*] Starting friend network analysis..." -ForegroundColor Cyan

# Fetch user info
$userInfo = Get-UserInfo -Token $Token
if (-not $userInfo) {
    Write-Host "`n[!] Failed to authenticate. Please check your token." -ForegroundColor Red
    exit
}

# Fetch data
$friends = Get-UserRelationships -Token $Token
$guilds = Get-UserGuilds -Token $Token

if ($friends.Count -eq 0) {
    Write-Host "`n[!] No friends found or unable to access relationships." -ForegroundColor Yellow
    Write-Host "[*] Analysis cannot continue without friend data." -ForegroundColor Gray
    exit
}

# Analyze network
$networkData = Analyze-FriendNetwork -Friends $friends `
                                     -Guilds $guilds `
                                     -Token $Token `
                                     -CurrentUserId $userInfo.id

# Show results
Show-NetworkStatistics -NetworkData $networkData `
                       -Guilds $guilds `
                       -TotalFriends $friends.Count

Show-DetailedFriendList -FriendDetails $networkData.FriendDetails

# Export if requested
if ($ExportToFile) {
    Export-Results -NetworkData $networkData `
                   -TotalFriends $friends.Count `
                   -TotalServers $guilds.Count
}

Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "[*] Friend network analysis complete!" -ForegroundColor Green
Write-Host "===============================================================================" -ForegroundColor Cyan

# Only show "Press any key" if not in quiet mode
if (-not $QuietMode) {
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
