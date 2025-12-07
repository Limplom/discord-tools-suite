# Discord Message Analytics Tool
# Analyzes your message patterns, channel activity, and communication statistics

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
    MaxMessagesPerChannel = 100  # Limit for message fetching per channel
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
        Write-Host "[+] Logged in as: $($user.username)#$($user.discriminator)" -ForegroundColor Green
        return $user
    }

    Write-Host "[!] Failed to fetch user info" -ForegroundColor Red
    return $null
}

function Get-DMChannels {
    param([string]$Token)

    Write-Host "[*] Fetching DM channels..." -ForegroundColor Cyan

    $channels = Invoke-DiscordAPI -Endpoint "/users/@me/channels" -Token $Token

    if (-not $channels) {
        Write-Host "[!] Failed to fetch DM channels" -ForegroundColor Red
        return @()
    }

    Write-Host "[+] Found $($channels.Count) DM channels" -ForegroundColor Green

    return $channels
}

function Get-UserGuilds {
    param([string]$Token)

    Write-Host "[*] Fetching guilds..." -ForegroundColor Cyan

    $guilds = Invoke-DiscordAPI -Endpoint "/users/@me/guilds" -Token $Token

    if (-not $guilds) {
        Write-Host "[!] Failed to fetch guilds" -ForegroundColor Red
        return @()
    }

    Write-Host "[+] Found $($guilds.Count) guilds" -ForegroundColor Green

    return $guilds
}

function Get-RecentMentions {
    param([string]$Token)

    Write-Host "[*] Fetching recent mentions..." -ForegroundColor Cyan

    $mentions = Invoke-DiscordAPI -Endpoint "/users/@me/mentions?limit=100" -Token $Token

    if (-not $mentions) {
        Write-Host "[!] Failed to fetch mentions" -ForegroundColor Red
        return @()
    }

    Write-Host "[+] Found $($mentions.Count) recent mentions" -ForegroundColor Green

    return $mentions
}

function Get-ChannelMessages {
    param(
        [string]$Token,
        [string]$ChannelId,
        [int]$Limit = 50
    )

    $messages = Invoke-DiscordAPI -Endpoint "/channels/$ChannelId/messages?limit=$Limit" -Token $Token

    Start-Sleep -Milliseconds 500  # Rate limiting

    return $messages
}

function Get-GuildChannels {
    param(
        [string]$Token,
        [string]$GuildId
    )

    $channels = Invoke-DiscordAPI -Endpoint "/guilds/$GuildId/channels" -Token $Token

    Start-Sleep -Milliseconds 300  # Rate limiting

    return $channels
}

function Analyze-MessagePatterns {
    param(
        [array]$Messages,
        [string]$CurrentUserId
    )

    $stats = @{
        TotalMessages = $Messages.Count
        UserMessages = 0
        ReceivedMessages = 0
        AverageLength = 0
        TotalWords = 0
        EmojisUsed = @{}
        MessagesByHour = @{}
        MessagesByDay = @{}
        MessagesWithAttachments = 0
        MessagesWithEmbeds = 0
    }

    $totalLength = 0

    foreach ($msg in $Messages) {
        # Skip null messages
        if (-not $msg -or -not $msg.content) { continue }

        # Count user vs received messages
        if ($msg.author.id -eq $CurrentUserId) {
            $stats.UserMessages++
        } else {
            $stats.ReceivedMessages++
        }

        # Calculate length and word count
        $content = $msg.content
        $length = $content.Length
        $totalLength += $length

        $words = ($content -split '\s+').Count
        $stats.TotalWords += $words

        # Extract emojis (Custom Discord emojis and common Unicode emojis)
        $customEmojiPattern = '<a?:\w+:\d+>'

        # Find custom Discord emojis (always works)
        if ($content -match $customEmojiPattern) {
            $matches = [regex]::Matches($content, $customEmojiPattern)
            foreach ($match in $matches) {
                $emoji = $match.Value
                if (-not $stats.EmojisUsed.ContainsKey($emoji)) {
                    $stats.EmojisUsed[$emoji] = 0
                }
                $stats.EmojisUsed[$emoji]++
            }
        }

        # Find common Unicode emojis (using .NET char detection)
        # This is more compatible than regex patterns across PS versions
        try {
            for ($i = 0; $i -lt $content.Length; $i++) {
                $char = $content[$i]
                $charCode = [int][char]$char

                # Detect emoji ranges (common emojis)
                # Emoticons: 0x1F600-0x1F64F
                # Misc Symbols: 0x2600-0x26FF, 0x2700-0x27BF
                # Note: Full surrogate pair detection would be more complex
                if ($charCode -ge 0x2600 -and $charCode -le 0x27BF) {
                    $emoji = $char.ToString()
                    if (-not $stats.EmojisUsed.ContainsKey($emoji)) {
                        $stats.EmojisUsed[$emoji] = 0
                    }
                    $stats.EmojisUsed[$emoji]++
                }
            }
        }
        catch {
            # Silently skip emoji detection if it fails
        }

        # Time-based analysis
        try {
            $timestamp = [DateTime]::Parse($msg.timestamp)
            $hour = $timestamp.Hour
            $day = $timestamp.DayOfWeek

            if (-not $stats.MessagesByHour.ContainsKey($hour)) {
                $stats.MessagesByHour[$hour] = 0
            }
            $stats.MessagesByHour[$hour]++

            if (-not $stats.MessagesByDay.ContainsKey($day)) {
                $stats.MessagesByDay[$day] = 0
            }
            $stats.MessagesByDay[$day]++
        }
        catch {
            # Skip if timestamp parsing fails
        }

        # Count attachments and embeds
        if ($msg.attachments -and $msg.attachments.Count -gt 0) {
            $stats.MessagesWithAttachments++
        }

        if ($msg.embeds -and $msg.embeds.Count -gt 0) {
            $stats.MessagesWithEmbeds++
        }
    }

    # Calculate average
    if ($stats.TotalMessages -gt 0) {
        $stats.AverageLength = [Math]::Round($totalLength / $stats.TotalMessages, 2)
    }

    return $stats
}

function Analyze-DMActivity {
    param(
        [array]$DMChannels,
        [string]$Token,
        [string]$CurrentUserId
    )

    Write-Host "`n[*] Analyzing DM activity..." -ForegroundColor Cyan

    $dmStats = @()
    $processedCount = 0
    $maxDMsToAnalyze = [Math]::Min(10, $DMChannels.Count)  # Limit to prevent rate limiting

    foreach ($channel in $DMChannels | Select-Object -First $maxDMsToAnalyze) {
        $processedCount++
        Write-Host "  Processing DM $processedCount/$maxDMsToAnalyze..." -ForegroundColor Gray

        $messages = Get-ChannelMessages -Token $Token -ChannelId $channel.id -Limit 50

        if (-not $messages -or $messages.Count -eq 0) {
            continue
        }

        $recipient = $null
        if ($channel.recipients -and $channel.recipients.Count -gt 0) {
            $recipient = $channel.recipients[0]
        }

        $recipientName = if ($recipient) { "$($recipient.username)#$($recipient.discriminator)" } else { "Unknown User" }

        $stats = Analyze-MessagePatterns -Messages $messages -CurrentUserId $CurrentUserId

        $dmStats += [PSCustomObject]@{
            ChannelId = $channel.id
            RecipientName = $recipientName
            RecipientId = if ($recipient) { $recipient.id } else { "unknown" }
            TotalMessages = $stats.TotalMessages
            UserMessages = $stats.UserMessages
            ReceivedMessages = $stats.ReceivedMessages
            AverageLength = $stats.AverageLength
            LastMessageTime = if ($messages[0].timestamp) { $messages[0].timestamp } else { "Unknown" }
        }
    }

    Write-Host "[+] Analyzed $processedCount DM conversations" -ForegroundColor Green

    return $dmStats
}

function Analyze-MentionPatterns {
    param(
        [array]$Mentions,
        [hashtable]$GuildMap
    )

    $mentionStats = @{
        TotalMentions = $Mentions.Count
        ByGuild = @{}
        ByChannel = @{}
        ByUser = @{}
        ByType = @{
            DirectMention = 0
            RoleMention = 0
            EveryoneMention = 0
        }
    }

    foreach ($mention in $Mentions) {
        # Guild statistics
        $guildId = $mention.guild_id
        if ($guildId) {
            if (-not $mentionStats.ByGuild.ContainsKey($guildId)) {
                $guildName = if ($GuildMap.ContainsKey($guildId)) { $GuildMap[$guildId].name } else { "Unknown Guild" }
                $mentionStats.ByGuild[$guildId] = @{
                    Name = $guildName
                    Count = 0
                }
            }
            $mentionStats.ByGuild[$guildId].Count++
        }

        # Channel statistics
        $channelId = $mention.channel_id
        if ($channelId) {
            if (-not $mentionStats.ByChannel.ContainsKey($channelId)) {
                $mentionStats.ByChannel[$channelId] = 0
            }
            $mentionStats.ByChannel[$channelId]++
        }

        # User statistics
        if ($mention.author) {
            $authorName = "$($mention.author.username)#$($mention.author.discriminator)"
            if (-not $mentionStats.ByUser.ContainsKey($authorName)) {
                $mentionStats.ByUser[$authorName] = 0
            }
            $mentionStats.ByUser[$authorName]++
        }

        # Mention type detection
        if ($mention.mention_everyone) {
            $mentionStats.ByType.EveryoneMention++
        }
        if ($mention.mention_roles -and $mention.mention_roles.Count -gt 0) {
            $mentionStats.ByType.RoleMention++
        }
        if ($mention.mentions -and $mention.mentions.Count -gt 0) {
            $mentionStats.ByType.DirectMention++
        }
    }

    return $mentionStats
}

function Show-MessageStatistics {
    param(
        [hashtable]$MentionStats,
        [array]$DMStats,
        [array]$Messages,
        [string]$CurrentUserId
    )

    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "                    MESSAGE ANALYTICS DASHBOARD                             " -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan

    # Overall Statistics
    Write-Host "`n=== OVERALL STATISTICS ===" -ForegroundColor Yellow
    Write-Host "Total Mentions Received: " -ForegroundColor White -NoNewline
    Write-Host $MentionStats.TotalMentions -ForegroundColor Green

    Write-Host "Total DM Conversations Analyzed: " -ForegroundColor White -NoNewline
    Write-Host $DMStats.Count -ForegroundColor Green

    $totalDMMessages = ($DMStats | Measure-Object -Property TotalMessages -Sum).Sum
    Write-Host "Total DM Messages: " -ForegroundColor White -NoNewline
    Write-Host $totalDMMessages -ForegroundColor Green

    # Mention Type Breakdown
    Write-Host "`n=== MENTION TYPE BREAKDOWN ===" -ForegroundColor Yellow
    Write-Host "Direct Mentions (@you): " -ForegroundColor White -NoNewline
    Write-Host $MentionStats.ByType.DirectMention -ForegroundColor Cyan

    Write-Host "Role Mentions: " -ForegroundColor White -NoNewline
    Write-Host $MentionStats.ByType.RoleMention -ForegroundColor Cyan

    Write-Host "@everyone/@here Mentions: " -ForegroundColor White -NoNewline
    Write-Host $MentionStats.ByType.EveryoneMention -ForegroundColor Cyan

    # Top Guilds by Mentions
    if ($MentionStats.ByGuild.Count -gt 0) {
        Write-Host "`n=== TOP SERVERS BY MENTIONS ===" -ForegroundColor Yellow

        $topGuilds = $MentionStats.ByGuild.GetEnumerator() |
                     Sort-Object { $_.Value.Count } -Descending |
                     Select-Object -First 10

        $rank = 1
        foreach ($guild in $topGuilds) {
            Write-Host "  $rank. " -ForegroundColor White -NoNewline
            Write-Host "$($guild.Value.Name): " -ForegroundColor Yellow -NoNewline
            Write-Host "$($guild.Value.Count) mentions" -ForegroundColor Green
            $rank++
        }
    }

    # Top Users Who Mention You
    if ($MentionStats.ByUser.Count -gt 0) {
        Write-Host "`n=== TOP USERS WHO MENTION YOU ===" -ForegroundColor Yellow

        $topUsers = $MentionStats.ByUser.GetEnumerator() |
                    Sort-Object Value -Descending |
                    Select-Object -First 10

        $rank = 1
        foreach ($user in $topUsers) {
            Write-Host "  $rank. " -ForegroundColor White -NoNewline
            Write-Host "$($user.Key): " -ForegroundColor Magenta -NoNewline
            Write-Host "$($user.Value) mentions" -ForegroundColor Green
            $rank++
        }
    }

    # DM Activity Analysis
    if ($DMStats.Count -gt 0) {
        Write-Host "`n=== TOP DM CONVERSATIONS ===" -ForegroundColor Yellow

        $topDMs = $DMStats | Sort-Object -Property TotalMessages -Descending | Select-Object -First 10

        $rank = 1
        foreach ($dm in $topDMs) {
            Write-Host "`n  $rank. " -ForegroundColor White -NoNewline
            Write-Host "$($dm.RecipientName)" -ForegroundColor Cyan

            Write-Host "     Total Messages: " -ForegroundColor Gray -NoNewline
            Write-Host $dm.TotalMessages -ForegroundColor White

            Write-Host "     Your Messages: " -ForegroundColor Gray -NoNewline
            Write-Host $dm.UserMessages -ForegroundColor Green -NoNewline

            Write-Host " | Received: " -ForegroundColor Gray -NoNewline
            Write-Host $dm.ReceivedMessages -ForegroundColor Yellow

            if ($dm.AverageLength -gt 0) {
                Write-Host "     Avg Message Length: " -ForegroundColor Gray -NoNewline
                Write-Host "$($dm.AverageLength) characters" -ForegroundColor White
            }

            $rank++
        }

        # DM vs Server Comparison
        Write-Host "`n=== DM vs SERVER ACTIVITY ===" -ForegroundColor Yellow

        $totalUserDMs = ($DMStats | Measure-Object -Property UserMessages -Sum).Sum
        $totalReceivedDMs = ($DMStats | Measure-Object -Property ReceivedMessages -Sum).Sum

        Write-Host "Total DM Messages Sent: " -ForegroundColor White -NoNewline
        Write-Host $totalUserDMs -ForegroundColor Green

        Write-Host "Total DM Messages Received: " -ForegroundColor White -NoNewline
        Write-Host $totalReceivedDMs -ForegroundColor Yellow

        if ($totalUserDMs -gt 0 -and $totalReceivedDMs -gt 0) {
            $ratio = [Math]::Round($totalUserDMs / $totalReceivedDMs, 2)
            Write-Host "Send/Receive Ratio: " -ForegroundColor White -NoNewline
            Write-Host "$ratio" -ForegroundColor Cyan -NoNewline

            if ($ratio -gt 1.5) {
                Write-Host " (You send more)" -ForegroundColor Gray
            } elseif ($ratio -lt 0.66) {
                Write-Host " (You receive more)" -ForegroundColor Gray
            } else {
                Write-Host " (Balanced)" -ForegroundColor Gray
            }
        }
    }

    # Analyze message patterns from mentions
    if ($Messages.Count -gt 0) {
        $messagePatterns = Analyze-MessagePatterns -Messages $Messages -CurrentUserId $CurrentUserId

        if ($messagePatterns.EmojisUsed.Count -gt 0) {
            Write-Host "`n=== EMOJI USAGE (from mentions) ===" -ForegroundColor Yellow

            $topEmojis = $messagePatterns.EmojisUsed.GetEnumerator() |
                         Sort-Object Value -Descending |
                         Select-Object -First 15

            $rank = 1
            foreach ($emoji in $topEmojis) {
                Write-Host "  $rank. " -ForegroundColor White -NoNewline
                Write-Host "$($emoji.Key) " -ForegroundColor Yellow -NoNewline
                Write-Host "- used $($emoji.Value) times" -ForegroundColor Green
                $rank++
            }
        }

        # Time-based analysis
        if ($messagePatterns.MessagesByHour.Count -gt 0) {
            Write-Host "`n=== ACTIVITY BY HOUR (from mentions) ===" -ForegroundColor Yellow

            $hourlyActivity = $messagePatterns.MessagesByHour.GetEnumerator() |
                             Sort-Object Value -Descending |
                             Select-Object -First 5

            Write-Host "Most Active Hours:" -ForegroundColor Cyan
            foreach ($hour in $hourlyActivity) {
                $hourFormatted = "{0:D2}:00" -f [int]$hour.Key
                $bar = "#" * [Math]::Min(20, $hour.Value)

                Write-Host "  $hourFormatted | " -ForegroundColor White -NoNewline
                Write-Host "$bar " -ForegroundColor Green -NoNewline
                Write-Host "($($hour.Value) messages)" -ForegroundColor Gray
            }
        }

        if ($messagePatterns.MessagesByDay.Count -gt 0) {
            Write-Host "`n=== ACTIVITY BY DAY OF WEEK (from mentions) ===" -ForegroundColor Yellow

            $dayOrder = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")

            foreach ($dayName in $dayOrder) {
                $count = 0
                foreach ($key in $messagePatterns.MessagesByDay.Keys) {
                    if ($key.ToString() -eq $dayName) {
                        $count = $messagePatterns.MessagesByDay[$key]
                        break
                    }
                }

                if ($count -gt 0) {
                    $bar = "#" * [Math]::Min(20, $count)
                    Write-Host "  $dayName | " -ForegroundColor White -NoNewline
                    Write-Host "$bar " -ForegroundColor Cyan -NoNewline
                    Write-Host "($count messages)" -ForegroundColor Gray
                }
            }
        }
    }
}

function Export-Results {
    param(
        [hashtable]$MentionStats,
        [array]$DMStats
    )

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $filename = "discord_message_analytics_$timestamp.json"

    $export = @{
        GeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        MentionStatistics = $MentionStats
        DMStatistics = $DMStats
    }

    $export | ConvertTo-Json -Depth 10 | Out-File $filename

    Write-Host "`n[+] Analytics exported to: " -ForegroundColor Green -NoNewline
    Write-Host $filename -ForegroundColor Yellow
}

# ============================================
# MAIN EXECUTION
# ============================================

Clear-Host

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "                                                                               " -ForegroundColor Cyan
Write-Host "                Discord Message Analytics Tool v1.0                            " -ForegroundColor Cyan
Write-Host "                --------------------------------------                         " -ForegroundColor Cyan
Write-Host "                                                                               " -ForegroundColor Cyan
Write-Host "  Analyzes your Discord messaging patterns, DM activity,                      " -ForegroundColor Cyan
Write-Host "  and communication statistics                                                " -ForegroundColor Cyan
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

Write-Host "`n[*] Starting message analysis..." -ForegroundColor Cyan

# Fetch user info
$userInfo = Get-UserInfo -Token $Token
if (-not $userInfo) {
    Write-Host "`n[!] Failed to authenticate. Please check your token." -ForegroundColor Red
    exit
}

# Fetch all data
$guilds = Get-UserGuilds -Token $Token
$guildMap = @{}
foreach ($guild in $guilds) {
    $guildMap[$guild.id] = $guild
}

$mentions = Get-RecentMentions -Token $Token
$dmChannels = Get-DMChannels -Token $Token

# Analyze DM activity
$dmStats = Analyze-DMActivity -DMChannels $dmChannels -Token $Token -CurrentUserId $userInfo.id

# Analyze mention patterns
$mentionStats = Analyze-MentionPatterns -Mentions $mentions -GuildMap $guildMap

# Show statistics
Show-MessageStatistics -MentionStats $mentionStats `
                       -DMStats $dmStats `
                       -Messages $mentions `
                       -CurrentUserId $userInfo.id

# Export if requested
if ($ExportToFile) {
    Export-Results -MentionStats $mentionStats -DMStats $dmStats
}

Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "[*] Message analysis complete!" -ForegroundColor Green
Write-Host "===============================================================================" -ForegroundColor Cyan

# Only show "Press any key" if not in quiet mode
if (-not $QuietMode) {
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
