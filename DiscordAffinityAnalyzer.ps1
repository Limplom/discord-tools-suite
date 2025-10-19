# Discord Affinity & Mention Analyzer
# Analyzes guild affinities and shows mentions in high-activity servers

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
        [string]$Token
    )
    
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
        Write-Warning "API Error for $Endpoint : $_"
        return $null
    }
}

function Get-GuildAffinities {
    param([string]$Token)
    
    Write-Host "`n[*] Fetching guild affinities..." -ForegroundColor Cyan
    
    $affinities = Invoke-DiscordAPI -Endpoint "/users/@me/affinities/guilds" -Token $Token
    
    if (-not $affinities) {
        Write-Host "[!] Failed to fetch affinities" -ForegroundColor Red
        return @()
    }
    
    $sorted = $affinities.guild_affinities | Sort-Object -Property affinity -Descending
    
    Write-Host "[+] Found $($sorted.Count) guilds with affinity data" -ForegroundColor Green
    
    return $sorted
}

function Get-UserGuilds {
    param([string]$Token)
    
    Write-Host "[*] Fetching guild information..." -ForegroundColor Cyan
    
    $guilds = Invoke-DiscordAPI -Endpoint "/users/@me/guilds" -Token $Token
    
    if (-not $guilds) {
        Write-Host "[!] Failed to fetch guilds" -ForegroundColor Red
        return @{}
    }
    
    $guildMap = @{}
    foreach ($guild in $guilds) {
        $guildMap[$guild.id] = @{
            Name = $guild.name
            Icon = $guild.icon
            Owner = $guild.owner
            MemberCount = $guild.approximate_member_count
        }
    }
    
    Write-Host "[+] Loaded $($guildMap.Count) guilds" -ForegroundColor Green
    
    return $guildMap
}

function Get-UserMentions {
    param([string]$Token)
    
    Write-Host "[*] Fetching recent mentions..." -ForegroundColor Cyan
    
    $mentions = Invoke-DiscordAPI -Endpoint "/users/@me/mentions" -Token $Token
    
    if (-not $mentions) {
        Write-Host "[!] Failed to fetch mentions" -ForegroundColor Red
        return @()
    }
    
    Write-Host "[+] Found $($mentions.Count) recent mentions" -ForegroundColor Green
    
    return $mentions
}

function Get-GuildChannels {
    param(
        [string]$Token,
        [string]$GuildId
    )
    
    $channels = Invoke-DiscordAPI -Endpoint "/guilds/$GuildId/channels" -Token $Token
    
    if (-not $channels) {
        return @{}
    }
    
    $channelMap = @{}
    foreach ($channel in $channels) {
        $channelMap[$channel.id] = @{
            Name = $channel.name
            Type = $channel.type
            Position = $channel.position
        }
    }
    
    return $channelMap
}

function Format-AffinityBar {
    param([double]$Percentage)

    # Normalize percentage to 0-100 range
    $normalizedPercentage = [Math]::Min(100, [Math]::Max(0, $Percentage))
    $filled = [Math]::Floor($normalizedPercentage / 5)
    $empty = 20 - $filled

    $bar = "#" * $filled + "-" * $empty

    if ($normalizedPercentage -ge 50) {
        $color = "Green"
    } elseif ($normalizedPercentage -ge 25) {
        $color = "Yellow"
    } elseif ($normalizedPercentage -ge 10) {
        $color = "DarkYellow"
    } else {
        $color = "Gray"
    }

    return @{
        Bar = $bar
        Color = $color
        Percentage = [Math]::Round($normalizedPercentage, 2)
    }
}

function Format-Timestamp {
    param([string]$IsoTimestamp)
    
    try {
        $dt = [DateTime]::Parse($IsoTimestamp)
        $now = [DateTime]::Now
        $diff = $now - $dt
        
        if ($diff.TotalMinutes -lt 1) {
            return "just now"
        } elseif ($diff.TotalMinutes -lt 60) {
            return "$([Math]::Floor($diff.TotalMinutes))m ago"
        } elseif ($diff.TotalHours -lt 24) {
            return "$([Math]::Floor($diff.TotalHours))h ago"
        } elseif ($diff.TotalDays -lt 7) {
            return "$([Math]::Floor($diff.TotalDays))d ago"
        } else {
            return $dt.ToString("yyyy-MM-dd")
        }
    }
    catch {
        return "unknown"
    }
}

function Show-AffinityReport {
    param(
        [array]$Affinities,
        [hashtable]$GuildMap,
        [array]$Mentions,
        [string]$Token
    )
    
    # Calculate total affinity for relative percentages (ALL guilds, not just those above threshold)
    $totalAffinity = ($Affinities | Measure-Object -Property affinity -Sum).Sum

    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "                    DISCORD AFFINITY ANALYSIS REPORT                        " -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""

    $results = @()
    $rank = 1

    foreach ($affinity in $Affinities) {
        $guildId = $affinity.guild_id
        $affinityScore = $affinity.affinity
        
        $guildInfo = $GuildMap[$guildId]
        if (-not $guildInfo) {
            continue
        }
        
        $guildMentions = $Mentions | Where-Object {
            $_.guild_id -eq $guildId
        }

        $channels = Get-GuildChannels -Token $Token -GuildId $guildId
        Start-Sleep -Milliseconds 300

        $mentionsByChannel = $guildMentions | Group-Object -Property channel_id

        # Calculate relative percentage
        $relativePercentage = if ($totalAffinity -gt 0) {
            ($affinityScore / $totalAffinity) * 100
        } else {
            0
        }

        $affinityBar = Format-AffinityBar -Percentage $relativePercentage

        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor White
        Write-Host "Rank #$rank - " -ForegroundColor White -NoNewline
        Write-Host "[$($guildInfo.Name)]" -ForegroundColor Yellow -NoNewline
        if ($guildInfo.Owner) {
            Write-Host " (Owner)" -ForegroundColor Magenta
        } else {
            Write-Host ""
        }

        # Show absolute affinity score
        Write-Host "Affinity Score: " -ForegroundColor White -NoNewline
        Write-Host "$([Math]::Round($affinityScore, 2))" -ForegroundColor Green

        # Show relative percentage with bar
        Write-Host "Relative Activity: " -ForegroundColor White -NoNewline
        Write-Host "$([Math]::Round($relativePercentage, 2))% " -ForegroundColor $affinityBar.Color -NoNewline
        Write-Host "[$($affinityBar.Bar)]" -ForegroundColor $affinityBar.Color

        # Show member count
        if ($guildInfo.MemberCount) {
            Write-Host "Members: " -ForegroundColor White -NoNewline
            Write-Host "$($guildInfo.MemberCount)" -ForegroundColor Green
        }

        Write-Host "Mentions: $($guildMentions.Count)" -ForegroundColor White
        Write-Host "Active Channels: $($mentionsByChannel.Count)" -ForegroundColor White
        
        if ($guildMentions.Count -gt 0) {
            Write-Host "`nRecent Mentions:" -ForegroundColor Cyan
            
            foreach ($channelGroup in $mentionsByChannel) {
                $channelId = $channelGroup.Name
                $channelInfo = $channels[$channelId]
                $channelName = if ($channelInfo) { $channelInfo.Name } else { "unknown-channel" }
                
                Write-Host "  >> #$channelName " -ForegroundColor Green -NoNewline
                Write-Host "($($channelGroup.Count) mentions)" -ForegroundColor Gray

                # Show all mentions in this channel, sorted by timestamp
                $sortedMentions = $channelGroup.Group | Sort-Object -Property timestamp -Descending

                foreach ($mention in $sortedMentions) {
                    $author = $mention.author.username
                    $timeAgo = Format-Timestamp -IsoTimestamp $mention.timestamp
                    $content = $mention.content
                    
                    if ($content.Length -gt 60) {
                        $content = $content.Substring(0, 60) + "..."
                    }
                    
                    Write-Host "     - " -ForegroundColor DarkGray -NoNewline
                    Write-Host "$author " -ForegroundColor Magenta -NoNewline
                    Write-Host "($timeAgo)" -ForegroundColor DarkGray
                    Write-Host "       $content" -ForegroundColor White
                }
            }
        }

        $results += [PSCustomObject]@{
            Rank = $rank
            GuildId = $guildId
            GuildName = $guildInfo.Name
            Affinity = $affinityScore
            MentionCount = $guildMentions.Count
            ActiveChannels = $mentionsByChannel.Count
            Mentions = $guildMentions
        }
        
        $rank++
    }
    
    # Show "Other Activity" - mentions in low-affinity guilds
    $lowAffinityMentions = @()
    $processedGuildIds = $results | ForEach-Object { $_.GuildId }

    foreach ($mention in $Mentions) {
        $guildId = $mention.guild_id
        if ($guildId -and $guildId -notin $processedGuildIds -and $GuildMap.ContainsKey($guildId)) {
            $lowAffinityMentions += $mention
        }
    }

    if ($lowAffinityMentions.Count -gt 0) {
        Write-Host "`n===============================================================================" -ForegroundColor Cyan
        Write-Host "                            OTHER ACTIVITY                                  " -ForegroundColor Cyan
        Write-Host "===============================================================================" -ForegroundColor Cyan
        Write-Host "`nMentions in guilds without affinity data:" -ForegroundColor Gray

        $groupedByGuild = $lowAffinityMentions | Group-Object -Property guild_id

        foreach ($guildGroup in $groupedByGuild) {
            $guildId = $guildGroup.Name
            $guildInfo = $GuildMap[$guildId]

            Write-Host "`n[$($guildInfo.Name)]" -ForegroundColor Yellow -NoNewline
            Write-Host " - $($guildGroup.Count) mentions" -ForegroundColor Gray

            foreach ($mention in $guildGroup.Group | Sort-Object -Property timestamp -Descending) {
                $author = $mention.author.username
                $timeAgo = Format-Timestamp -IsoTimestamp $mention.timestamp
                $content = $mention.content

                Write-Host "  - " -ForegroundColor DarkGray -NoNewline
                Write-Host "$author " -ForegroundColor Magenta -NoNewline
                Write-Host "($timeAgo)" -ForegroundColor DarkGray
                Write-Host "    $content" -ForegroundColor White
            }
        }
    }

    return @{
        Results = $results
        TotalAffinity = $totalAffinity
    }
}

function Show-Summary {
    param(
        [array]$Results,
        [double]$TotalAffinity
    )

    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "                              SUMMARY STATISTICS                            " -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan

    $totalMentions = ($Results | Measure-Object -Property MentionCount -Sum).Sum
    $displayedAffinity = ($Results | Measure-Object -Property Affinity -Sum).Sum
    $avgAffinity = ($Results | Measure-Object -Property Affinity -Average).Average
    $topGuild = $Results | Sort-Object -Property Affinity -Descending | Select-Object -First 1

    Write-Host "`nTotal Analyzed Guilds: " -ForegroundColor White -NoNewline
    Write-Host $Results.Count -ForegroundColor Green

    Write-Host "Total Mentions: " -ForegroundColor White -NoNewline
    Write-Host $totalMentions -ForegroundColor Green

    Write-Host "`nAffinity Scores (Discord's activity metric):" -ForegroundColor Cyan
    Write-Host "  Total (all guilds): " -ForegroundColor White -NoNewline
    Write-Host "$([Math]::Round($TotalAffinity, 2))" -ForegroundColor Yellow

    Write-Host "  Displayed (above threshold): " -ForegroundColor White -NoNewline
    Write-Host "$([Math]::Round($displayedAffinity, 2))" -ForegroundColor Cyan

    Write-Host "  Average: " -ForegroundColor White -NoNewline
    Write-Host "$([Math]::Round($avgAffinity, 2))" -ForegroundColor Yellow

    if ($topGuild) {
        $topPercentage = if ($TotalAffinity -gt 0) { ($topGuild.Affinity / $TotalAffinity) * 100 } else { 0 }
        Write-Host "  Highest: " -ForegroundColor White -NoNewline
        Write-Host "$([Math]::Round($topGuild.Affinity, 2)) " -ForegroundColor Green -NoNewline
        Write-Host "($($topGuild.GuildName) - $([Math]::Round($topPercentage, 2))% of total)" -ForegroundColor Yellow
    }

    # Mention Statistics
    if ($totalMentions -gt 0) {
        Write-Host "`n===============================================================================" -ForegroundColor Cyan
        Write-Host "                           MENTION STATISTICS                               " -ForegroundColor Cyan
        Write-Host "===============================================================================" -ForegroundColor Cyan

        # Get all mentions from all results
        $allMentions = $Results | Where-Object { $_.Mentions -and $_.Mentions.Count -gt 0 } | ForEach-Object { $_.Mentions }

        # Top Mentioners (show all, sorted by count)
        $topMentioners = $allMentions | Group-Object -Property { $_.author.username } |
                         Sort-Object Count -Descending

        if ($topMentioners) {
            Write-Host "`nTop Mentioners:" -ForegroundColor Cyan
            $position = 1
            foreach ($mentioner in $topMentioners) {
                Write-Host "  $position. " -ForegroundColor White -NoNewline
                Write-Host "$($mentioner.Name): " -ForegroundColor Magenta -NoNewline
                Write-Host "$($mentioner.Count) mentions" -ForegroundColor Gray
                $position++
            }
        }

        # Guilds with most mentions (show all with mentions)
        $guildsByMentions = $Results | Where-Object { $_.MentionCount -gt 0 } |
                            Sort-Object -Property MentionCount -Descending

        if ($guildsByMentions) {
            Write-Host "`nGuilds with Mentions:" -ForegroundColor Cyan
            $position = 1
            foreach ($guild in $guildsByMentions) {
                Write-Host "  $position. " -ForegroundColor White -NoNewline
                Write-Host "$($guild.GuildName): " -ForegroundColor Yellow -NoNewline
                Write-Host "$($guild.MentionCount) mentions" -ForegroundColor Gray
                $position++
            }
        }
    }
}

function Export-Results {
    param([array]$Results)
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $filename = "discord_affinity_report_$timestamp.json"
    
    $export = @{
        GeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        TotalGuilds = $Results.Count
        Results = $Results
    }
    
    $export | ConvertTo-Json -Depth 10 | Out-File $filename
    
    Write-Host "`n[+] Report exported to: " -ForegroundColor Green -NoNewline
    Write-Host $filename -ForegroundColor Yellow
}

# ============================================
# MAIN EXECUTION
# ============================================

Clear-Host

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "                                                                               " -ForegroundColor Cyan
Write-Host "              Discord Affinity & Mention Analyzer v1.0                         " -ForegroundColor Cyan
Write-Host "              -----------------------------------------                        " -ForegroundColor Cyan
Write-Host "                                                                               " -ForegroundColor Cyan
Write-Host "  Analyzes your Discord activity patterns and tracks mentions                 " -ForegroundColor Cyan
Write-Host "  in your most active servers                                                 " -ForegroundColor Cyan
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

Write-Host "`n[*] Starting analysis..." -ForegroundColor Cyan

$affinities = Get-GuildAffinities -Token $Token
$guilds = Get-UserGuilds -Token $Token
$mentions = Get-UserMentions -Token $Token

if ($affinities.Count -eq 0) {
    Write-Host "`n[!] No affinity data available. Exiting." -ForegroundColor Red
    exit
}

$reportData = Show-AffinityReport -Affinities $affinities `
                                  -GuildMap $guilds `
                                  -Mentions $mentions `
                                  -Token $Token

Show-Summary -Results $reportData.Results -TotalAffinity $reportData.TotalAffinity

if ($ExportToFile) {
    Export-Results -Results $reportData.Results
}

Write-Host "`n[*] Analysis complete!" -ForegroundColor Green

# Only show "Press any key" if not in quiet mode (not called from another script)
if (-not $QuietMode) {
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}