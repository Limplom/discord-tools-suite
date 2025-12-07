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

    # Build guild member lookup (guild ID -> member IDs)
    Write-Host "[*] Analyzing server memberships..." -ForegroundColor Cyan
    $guildMemberMap = @{}

    $processedGuilds = 0
    foreach ($guild in $Guilds) {
        $processedGuilds++
        Write-Host "`r  Processing server $processedGuilds/$($Guilds.Count)..." -ForegroundColor Gray -NoNewline

        # Try to get members (may not work for all servers)
        $members = Get-GuildMembers -Token $Token -GuildId $guild.id -Limit 1000

        if ($members -and $members.Count -gt 0) {
            $memberIds = @()
            foreach ($member in $members) {
                if ($member.user -and $member.user.id) {
                    $memberIds += $member.user.id
                }
            }
            $guildMemberMap[$guild.id] = @{
                Name = $guild.name
                MemberIds = $memberIds
            }
        }
    }

    Write-Host "`r" -NoNewline
    Write-Host (" " * 70) -NoNewline
    Write-Host "`r" -NoNewline

    # Analyze each friend
    foreach ($friend in $Friends) {
        $friendId = $friend.user.id
        $friendName = if ($friend.user.global_name) {
            $friend.user.global_name
        } else {
            "$($friend.user.username)#$($friend.user.discriminator)"
        }

        # Find mutual servers
        $mutualServers = @()
        foreach ($guildId in $guildMemberMap.Keys) {
            $guildData = $guildMemberMap[$guildId]
            if ($guildData.MemberIds -contains $friendId) {
                $mutualServers += @{
                    Id = $guildId
                    Name = $guildData.Name
                }

                # Track friends by server
                if (-not $networkData.FriendsByServer.ContainsKey($guildId)) {
                    $networkData.FriendsByServer[$guildId] = @{
                        Name = $guildData.Name
                        Friends = @()
                    }
                }
                $networkData.FriendsByServer[$guildId].Friends += $friendName
            }
        }

        $friendData = @{
            Id = $friendId
            Name = $friendName
            Username = $friend.user.username
            Discriminator = $friend.user.discriminator
            MutualServers = $mutualServers
            MutualServerCount = $mutualServers.Count
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

    $serversWithFriends = $NetworkData.FriendsByServer.Count
    Write-Host "Servers with Friends: " -ForegroundColor White -NoNewline
    Write-Host $serversWithFriends -ForegroundColor Green

    # Friends with most mutual servers
    if ($NetworkData.FriendDetails.Count -gt 0) {
        Write-Host "`n=== TOP FRIENDS BY MUTUAL SERVERS ===" -ForegroundColor Yellow

        $topFriends = $NetworkData.FriendDetails |
                      Sort-Object -Property MutualServerCount -Descending |
                      Select-Object -First 10

        $rank = 1
        foreach ($friend in $topFriends) {
            if ($friend.MutualServerCount -gt 0) {
                Write-Host "  $rank. " -ForegroundColor White -NoNewline
                Write-Host "$($friend.Name): " -ForegroundColor Cyan -NoNewline
                Write-Host "$($friend.MutualServerCount) mutual servers" -ForegroundColor Green
                $rank++
            }
        }

        if ($rank -eq 1) {
            Write-Host "  (No mutual server data available)" -ForegroundColor Gray
        }
    }

    # Servers by friend count
    if ($NetworkData.FriendsByServer.Count -gt 0) {
        Write-Host "`n=== TOP SERVERS BY FRIEND COUNT ===" -ForegroundColor Yellow

        $serverStats = @()
        foreach ($guildId in $NetworkData.FriendsByServer.Keys) {
            $serverData = $NetworkData.FriendsByServer[$guildId]
            $serverStats += [PSCustomObject]@{
                Name = $serverData.Name
                FriendCount = $serverData.Friends.Count
                Friends = $serverData.Friends
            }
        }

        $topServers = $serverStats | Sort-Object -Property FriendCount -Descending | Select-Object -First 10

        $rank = 1
        foreach ($server in $topServers) {
            Write-Host "`n  $rank. " -ForegroundColor White -NoNewline
            Write-Host "$($server.Name)" -ForegroundColor Yellow
            Write-Host "     Friends in this server: " -ForegroundColor Gray -NoNewline
            Write-Host $server.FriendCount -ForegroundColor Green

            # Show friend names (up to 5)
            $friendsToShow = $server.Friends | Select-Object -First 5
            foreach ($friendName in $friendsToShow) {
                Write-Host "       - $friendName" -ForegroundColor Cyan
            }

            if ($server.FriendCount -gt 5) {
                Write-Host "       ... and $($server.FriendCount - 5) more" -ForegroundColor DarkGray
            }

            $rank++
        }
    }

    # Friend distribution
    Write-Host "`n=== FRIEND DISTRIBUTION ===" -ForegroundColor Yellow

    $friendsWithMutualServers = ($NetworkData.FriendDetails | Where-Object { $_.MutualServerCount -gt 0 }).Count
    $friendsWithoutMutualServers = $TotalFriends - $friendsWithMutualServers

    Write-Host "Friends with mutual servers: " -ForegroundColor White -NoNewline
    Write-Host $friendsWithMutualServers -ForegroundColor Green

    Write-Host "Friends without mutual servers: " -ForegroundColor White -NoNewline
    Write-Host $friendsWithoutMutualServers -ForegroundColor Yellow

    if ($TotalFriends -gt 0) {
        $percentage = [Math]::Round(($friendsWithMutualServers / $TotalFriends) * 100, 1)
        Write-Host "Percentage with mutual servers: " -ForegroundColor White -NoNewline
        Write-Host "$percentage%" -ForegroundColor Cyan
    }

    # Average mutual servers per friend
    if ($friendsWithMutualServers -gt 0) {
        $totalMutualServers = ($NetworkData.FriendDetails | Measure-Object -Property MutualServerCount -Sum).Sum
        $avgMutualServers = [Math]::Round($totalMutualServers / $TotalFriends, 2)

        Write-Host "Average mutual servers per friend: " -ForegroundColor White -NoNewline
        Write-Host $avgMutualServers -ForegroundColor Cyan
    }
}

function Show-DetailedFriendList {
    param(
        [array]$FriendDetails
    )

    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "                    DETAILED FRIEND LIST                                    " -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan

    # Group friends by mutual server count
    $friendsWithMutualServers = $FriendDetails |
                                Where-Object { $_.MutualServerCount -gt 0 } |
                                Sort-Object -Property MutualServerCount -Descending

    $friendsWithoutMutualServers = $FriendDetails | Where-Object { $_.MutualServerCount -eq 0 }

    if ($friendsWithMutualServers.Count -gt 0) {
        Write-Host "`n=== FRIENDS WITH MUTUAL SERVERS ===" -ForegroundColor Yellow
        Write-Host ""

        foreach ($friend in $friendsWithMutualServers) {
            Write-Host "  $($friend.Name)" -ForegroundColor Cyan -NoNewline
            Write-Host " ($($friend.MutualServerCount) mutual servers)" -ForegroundColor Gray

            if ($friend.MutualServers.Count -gt 0) {
                $serversToShow = $friend.MutualServers | Select-Object -First 3
                foreach ($server in $serversToShow) {
                    Write-Host "    - $($server.Name)" -ForegroundColor DarkGray
                }

                if ($friend.MutualServers.Count -gt 3) {
                    Write-Host "    ... and $($friend.MutualServers.Count - 3) more" -ForegroundColor DarkGray
                }
            }
            Write-Host ""
        }
    }

    if ($friendsWithoutMutualServers.Count -gt 0) {
        Write-Host "`n=== FRIENDS WITHOUT MUTUAL SERVERS (DM only) ===" -ForegroundColor Yellow
        Write-Host ""

        foreach ($friend in $friendsWithoutMutualServers) {
            Write-Host "  - $($friend.Name)" -ForegroundColor Gray
        }
    }
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
