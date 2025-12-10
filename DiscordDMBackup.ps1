# Discord DM Backup Tool
# Exports and archives Discord DM conversations in multiple formats

param(
    [Parameter(Mandatory=$false)]
    [string]$Token,

    [Parameter(Mandatory=$false)]
    [ValidateSet("JSON", "HTML", "All")]
    [string]$Format = "HTML",

    [Parameter(Mandatory=$false)]
    [switch]$DownloadMedia,

    [Parameter(Mandatory=$false)]
    [switch]$QuietMode  # Suppresses "Press any key" when called from another script
)

# Configuration
$script:config = @{
    UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    MaxMessagesPerRequest = 100  # Discord API limit
    BaseOutputDirectory = Join-Path $PSScriptRoot "DM_Backups"
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

function Get-DMChannels {
    param([string]$Token)

    Write-Host "[*] Fetching DM channels..." -ForegroundColor Cyan

    $channels = Invoke-DiscordAPI -Endpoint "/users/@me/channels" -Token $Token

    if (-not $channels) {
        Write-Host "[!] Failed to fetch DM channels" -ForegroundColor Red
        return @()
    }

    # Filter only DM channels (type 1) and Group DMs (type 3)
    $dmChannels = $channels | Where-Object { $_.type -eq 1 -or $_.type -eq 3 }

    Write-Host "[+] Found $($dmChannels.Count) DM conversations" -ForegroundColor Green

    return $dmChannels
}

function Get-ChannelMessages {
    param(
        [string]$Token,
        [string]$ChannelId,
        [int]$Limit = 100
    )

    $allMessages = @()
    $lastMessageId = $null
    $hasMore = $true

    Write-Host "  Fetching messages..." -ForegroundColor Gray

    while ($hasMore) {
        $endpoint = if ($lastMessageId) {
            "/channels/$ChannelId/messages?limit=$Limit&before=$lastMessageId"
        } else {
            "/channels/$ChannelId/messages?limit=$Limit"
        }

        $messages = Invoke-DiscordAPI -Endpoint $endpoint -Token $Token

        if (-not $messages -or $messages.Count -eq 0) {
            $hasMore = $false
            break
        }

        $allMessages += $messages
        $lastMessageId = $messages[-1].id

        Write-Host "`r  Fetched $($allMessages.Count) messages..." -ForegroundColor Gray -NoNewline

        # Rate limiting
        Start-Sleep -Milliseconds 500

        # Stop if we got less than the limit (no more messages)
        if ($messages.Count -lt $Limit) {
            $hasMore = $false
        }

        # Safety limit to prevent infinite loops
        if ($allMessages.Count -ge 10000) {
            Write-Host "`n  [!] Reached safety limit of 10,000 messages" -ForegroundColor Yellow
            $hasMore = $false
        }
    }

    Write-Host "`r  Fetched $($allMessages.Count) messages total" -ForegroundColor Green

    # Reverse to get chronological order (oldest first)
    [Array]::Reverse($allMessages)

    return $allMessages
}

function Export-ToJSON {
    param(
        [string]$OutputPath,
        [array]$Messages,
        [hashtable]$ChannelInfo
    )

    $export = @{
        Channel = $ChannelInfo
        MessageCount = $Messages.Count
        ExportedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Messages = $Messages
    }

    $json = $export | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath $OutputPath -Encoding UTF8

    Write-Host "  [+] JSON export: $OutputPath" -ForegroundColor Green
}

function Export-ToHTML {
    param(
        [string]$OutputPath,
        [array]$Messages,
        [hashtable]$ChannelInfo,
        [string]$CurrentUserId
    )

    $sb = New-Object System.Text.StringBuilder

    # Build color map for users
    $userColors = @{}
    $colorPalette = @('#5865f2', '#57f287', '#fee75c', '#eb459e', '#ed4245', '#f26522', '#1abc9c', '#9b59b6')
    $colorIndex = 0

    foreach ($msg in $Messages) {
        if ($msg.author -and $msg.author.id -and -not $userColors.ContainsKey($msg.author.id)) {
            $userColors[$msg.author.id] = $colorPalette[$colorIndex % $colorPalette.Count]
            $colorIndex++
        }
    }

    # HTML Header
    $sb.AppendLine("<!DOCTYPE html>") | Out-Null
    $sb.AppendLine("<html lang='en'>") | Out-Null
    $sb.AppendLine("<head>") | Out-Null
    $sb.AppendLine("    <meta charset='UTF-8'>") | Out-Null
    $sb.AppendLine("    <meta name='viewport' content='width=device-width, initial-scale=1.0'>") | Out-Null
    $sb.AppendLine("    <title>Discord DM - $($ChannelInfo.Name)</title>") | Out-Null
    $sb.AppendLine("    <style>") | Out-Null
    $sb.AppendLine("        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #36393f; color: #dcddde; margin: 0; padding: 20px; }") | Out-Null
    $sb.AppendLine("        .container { max-width: 900px; margin: 0 auto; background: #2f3136; border-radius: 8px; padding: 20px; }") | Out-Null
    $sb.AppendLine("        .header { border-bottom: 2px solid #202225; padding-bottom: 20px; margin-bottom: 20px; }") | Out-Null
    $sb.AppendLine("        .header h1 { margin: 0; color: #fff; }") | Out-Null
    $sb.AppendLine("        .header p { margin: 5px 0; color: #b9bbbe; }") | Out-Null
    $sb.AppendLine("        .messages { display: flex; flex-direction: column; gap: 12px; }") | Out-Null
    $sb.AppendLine("        .message-wrapper { display: flex; width: 100%; }") | Out-Null
    $sb.AppendLine("        .message-wrapper.left { justify-content: flex-start; }") | Out-Null
    $sb.AppendLine("        .message-wrapper.right { justify-content: flex-end; }") | Out-Null
    $sb.AppendLine("        .message { max-width: 70%; padding: 12px; border-radius: 12px; background: #40444b; }") | Out-Null
    $sb.AppendLine("        .message.left { border-bottom-left-radius: 4px; }") | Out-Null
    $sb.AppendLine("        .message.right { border-bottom-right-radius: 4px; background: #5865f2; }") | Out-Null
    $sb.AppendLine("        .message-header { display: flex; align-items: baseline; margin-bottom: 6px; gap: 8px; }") | Out-Null
    $sb.AppendLine("        .author { font-weight: 600; font-size: 14px; }") | Out-Null
    $sb.AppendLine("        .timestamp { font-size: 11px; color: #a3a6aa; }") | Out-Null
    $sb.AppendLine("        .content { color: #dcddde; white-space: pre-wrap; word-wrap: break-word; line-height: 1.4; font-size: 15px; }") | Out-Null
    $sb.AppendLine("        .attachment { margin-top: 10px; padding: 8px 12px; background: #2b2d31; border-radius: 8px; }") | Out-Null
    $sb.AppendLine("        .attachment a { color: #00b0f4; text-decoration: none; font-size: 13px; }") | Out-Null
    $sb.AppendLine("        .attachment a:hover { text-decoration: underline; }") | Out-Null
    $sb.AppendLine("        .embed { margin-top: 10px; padding: 8px 12px; background: #2f3136; border-left: 4px solid #5865f2; border-radius: 4px; font-size: 13px; color: #b9bbbe; }") | Out-Null
    $sb.AppendLine("        .search-container { margin-bottom: 20px; padding: 15px; background: #40444b; border-radius: 8px; }") | Out-Null
    $sb.AppendLine("        .search-row { display: flex; gap: 10px; flex-wrap: wrap; }") | Out-Null
    $sb.AppendLine("        .search-input { flex: 1; min-width: 250px; padding: 10px; background: #2f3136; border: 1px solid #202225; border-radius: 4px; color: #dcddde; font-size: 14px; }") | Out-Null
    $sb.AppendLine("        .search-input:focus { outline: none; border-color: #5865f2; }") | Out-Null
    $sb.AppendLine("        .user-filter { padding: 10px; background: #2f3136; border: 1px solid #202225; border-radius: 4px; color: #dcddde; font-size: 14px; }") | Out-Null
    $sb.AppendLine("        .user-filter:focus { outline: none; border-color: #5865f2; }") | Out-Null
    $sb.AppendLine("        .message-wrapper.hidden { display: none; }") | Out-Null
    $sb.AppendLine("        .search-stats { margin-top: 10px; font-size: 13px; color: #b9bbbe; }") | Out-Null
    $sb.AppendLine("    </style>") | Out-Null
    $sb.AppendLine("</head>") | Out-Null
    $sb.AppendLine("<body>") | Out-Null
    $sb.AppendLine("    <div class='container'>") | Out-Null
    $sb.AppendLine("        <div class='header'>") | Out-Null
    $sb.AppendLine("            <h1>Discord DM Backup</h1>") | Out-Null
    $sb.AppendLine("            <p><strong>Conversation:</strong> $($ChannelInfo.Name)</p>") | Out-Null
    $sb.AppendLine("            <p><strong>Exported:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>") | Out-Null
    $sb.AppendLine("            <p><strong>Total Messages:</strong> $($Messages.Count)</p>") | Out-Null
    $sb.AppendLine("        </div>") | Out-Null

    # Build unique users list for filter
    $uniqueUsers = @{}
    foreach ($msg in $Messages) {
        if ($msg.author -and $msg.author.id) {
            $displayName = if ($msg.author.global_name) { $msg.author.global_name } else { "$($msg.author.username)#$($msg.author.discriminator)" }
            if (-not $uniqueUsers.ContainsKey($msg.author.id)) {
                $uniqueUsers[$msg.author.id] = $displayName
            }
        }
    }

    # Add search interface
    $sb.AppendLine("        <div class='search-container'>") | Out-Null
    $sb.AppendLine("            <div class='search-row'>") | Out-Null
    $sb.AppendLine("                <input type='text' id='searchInput' class='search-input' placeholder='🔍 Nachricht suchen...' />") | Out-Null
    $sb.AppendLine("                <select id='userFilter' class='user-filter'>") | Out-Null
    $sb.AppendLine("                    <option value=''>👥 Alle Benutzer</option>") | Out-Null
    foreach ($userId in $uniqueUsers.Keys) {
        $userName = [System.Web.HttpUtility]::HtmlEncode($uniqueUsers[$userId])
        $sb.AppendLine("                    <option value='$userId'>$userName</option>") | Out-Null
    }
    $sb.AppendLine("                </select>") | Out-Null
    $sb.AppendLine("            </div>") | Out-Null
    $sb.AppendLine("            <div class='search-stats' id='searchStats'></div>") | Out-Null
    $sb.AppendLine("        </div>") | Out-Null

    $sb.AppendLine("        <div class='messages' id='messagesContainer'>") | Out-Null

    # Messages
    foreach ($msg in $Messages) {
        $timestamp = if ($msg.timestamp) {
            [DateTime]::Parse($msg.timestamp, [System.Globalization.CultureInfo]::InvariantCulture).ToString("dd.MM.yyyy HH:mm")
        } else {
            "Unknown"
        }

        $isCurrentUser = ($msg.author -and $msg.author.id -eq $CurrentUserId)
        $alignment = if ($isCurrentUser) { "right" } else { "left" }

        $author = if ($msg.author) {
            if ($msg.author.global_name) {
                [System.Web.HttpUtility]::HtmlEncode($msg.author.global_name)
            } else {
                [System.Web.HttpUtility]::HtmlEncode("$($msg.author.username)#$($msg.author.discriminator)")
            }
        } else {
            "Unknown"
        }

        $authorColor = if ($msg.author -and $msg.author.id) {
            $userColors[$msg.author.id]
        } else {
            '#72767d'
        }

        $content = [System.Web.HttpUtility]::HtmlEncode($msg.content)
        $authorId = if ($msg.author -and $msg.author.id) { $msg.author.id } else { "" }

        $sb.AppendLine("            <div class='message-wrapper $alignment' data-author-id='$authorId' data-content='$content'>") | Out-Null
        $sb.AppendLine("                <div class='message $alignment'>") | Out-Null
        $sb.AppendLine("                    <div class='message-header'>") | Out-Null
        $sb.AppendLine("                        <span class='author' style='color: $authorColor;'>$author</span>") | Out-Null
        $sb.AppendLine("                        <span class='timestamp'>$timestamp</span>") | Out-Null
        $sb.AppendLine("                    </div>") | Out-Null
        $sb.AppendLine("                    <div class='content'>$content</div>") | Out-Null

        # Attachments
        if ($msg.attachments -and $msg.attachments.Count -gt 0) {
            foreach ($attachment in $msg.attachments) {
                $fileName = [System.Web.HttpUtility]::HtmlEncode($attachment.filename)
                $url = [System.Web.HttpUtility]::HtmlEncode($attachment.url)
                $extension = [System.IO.Path]::GetExtension($attachment.filename).ToLower()

                # Check if it's an image
                $imageExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp')
                # Check if it's a video
                $videoExtensions = @('.mp4', '.webm', '.mov', '.avi', '.mkv')

                if ($imageExtensions -contains $extension) {
                    # Embed image
                    $sb.AppendLine("                    <div class='attachment'>") | Out-Null
                    $sb.AppendLine("                        <a href='$url' target='_blank'>") | Out-Null
                    $sb.AppendLine("                            <img src='$url' alt='$fileName' style='max-width: 100%; border-radius: 8px; margin-top: 8px;'>") | Out-Null
                    $sb.AppendLine("                        </a>") | Out-Null
                    $sb.AppendLine("                        <div style='font-size: 12px; color: #a3a6aa; margin-top: 4px;'>📎 $fileName</div>") | Out-Null
                    $sb.AppendLine("                    </div>") | Out-Null
                }
                elseif ($videoExtensions -contains $extension) {
                    # Embed video
                    $videoType = $extension.TrimStart('.')
                    $sb.AppendLine("                    <div class='attachment'>") | Out-Null
                    $sb.AppendLine("                        <video controls style='max-width: 100%; border-radius: 8px; margin-top: 8px;'>") | Out-Null
                    $sb.AppendLine("                            <source src='$url' type='video/$videoType'>") | Out-Null
                    $sb.AppendLine("                            Your browser does not support the video tag.") | Out-Null
                    $sb.AppendLine("                        </video>") | Out-Null
                    $sb.AppendLine("                        <div style='font-size: 12px; color: #a3a6aa; margin-top: 4px;'>🎥 $fileName</div>") | Out-Null
                    $sb.AppendLine("                    </div>") | Out-Null
                }
                else {
                    # Regular file link
                    $sb.AppendLine("                    <div class='attachment'>📎 <a href='$url' target='_blank'>$fileName</a></div>") | Out-Null
                }
            }
        }

        # Embeds
        if ($msg.embeds -and $msg.embeds.Count -gt 0) {
            $sb.AppendLine("                    <div class='embed'>📋 Contains $($msg.embeds.Count) embed(s)</div>") | Out-Null
        }

        $sb.AppendLine("                </div>") | Out-Null
        $sb.AppendLine("            </div>") | Out-Null
    }

    $sb.AppendLine("        </div>") | Out-Null
    $sb.AppendLine("    </div>") | Out-Null

    # Add JavaScript for search and filter
    $sb.AppendLine("    <script>") | Out-Null
    $sb.AppendLine("        const searchInput = document.getElementById('searchInput');") | Out-Null
    $sb.AppendLine("        const userFilter = document.getElementById('userFilter');") | Out-Null
    $sb.AppendLine("        const searchStats = document.getElementById('searchStats');") | Out-Null
    $sb.AppendLine("        const messages = document.querySelectorAll('.message-wrapper');") | Out-Null
    $sb.AppendLine("        const totalMessages = messages.length;") | Out-Null
    $sb.AppendLine("") | Out-Null
    $sb.AppendLine("        function filterMessages() {") | Out-Null
    $sb.AppendLine("            const searchTerm = searchInput.value.toLowerCase();") | Out-Null
    $sb.AppendLine("            const selectedUser = userFilter.value;") | Out-Null
    $sb.AppendLine("            let visibleCount = 0;") | Out-Null
    $sb.AppendLine("") | Out-Null
    $sb.AppendLine("            messages.forEach(msg => {") | Out-Null
    $sb.AppendLine("                const content = msg.dataset.content.toLowerCase();") | Out-Null
    $sb.AppendLine("                const authorId = msg.dataset.authorId;") | Out-Null
    $sb.AppendLine("") | Out-Null
    $sb.AppendLine("                const matchesSearch = !searchTerm || content.includes(searchTerm);") | Out-Null
    $sb.AppendLine("                const matchesUser = !selectedUser || authorId === selectedUser;") | Out-Null
    $sb.AppendLine("") | Out-Null
    $sb.AppendLine("                if (matchesSearch && matchesUser) {") | Out-Null
    $sb.AppendLine("                    msg.classList.remove('hidden');") | Out-Null
    $sb.AppendLine("                    visibleCount++;") | Out-Null
    $sb.AppendLine("                } else {") | Out-Null
    $sb.AppendLine("                    msg.classList.add('hidden');") | Out-Null
    $sb.AppendLine("                }") | Out-Null
    $sb.AppendLine("            });") | Out-Null
    $sb.AppendLine("") | Out-Null
    $sb.AppendLine("            if (searchTerm || selectedUser) {") | Out-Null
    $sb.AppendLine("                searchStats.textContent = '📊 Zeige ' + visibleCount + ' von ' + totalMessages + ' Nachrichten';") | Out-Null
    $sb.AppendLine("            } else {") | Out-Null
    $sb.AppendLine("                searchStats.textContent = '';") | Out-Null
    $sb.AppendLine("            }") | Out-Null
    $sb.AppendLine("        }") | Out-Null
    $sb.AppendLine("") | Out-Null
    $sb.AppendLine("        searchInput.addEventListener('input', filterMessages);") | Out-Null
    $sb.AppendLine("        userFilter.addEventListener('change', filterMessages);") | Out-Null
    $sb.AppendLine("    </script>") | Out-Null
    $sb.AppendLine("</body>") | Out-Null
    $sb.AppendLine("</html>") | Out-Null

    $sb.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8

    Write-Host "  [+] HTML export: $OutputPath" -ForegroundColor Green
}

function Download-Media {
    param(
        [string]$MediaDirectory,
        [array]$Messages
    )

    Write-Host "  [*] Downloading media files..." -ForegroundColor Cyan

    if (-not (Test-Path $MediaDirectory)) {
        New-Item -ItemType Directory -Path $MediaDirectory -Force | Out-Null
    }

    $downloadCount = 0
    $totalAttachments = 0

    foreach ($msg in $Messages) {
        if ($msg.attachments -and $msg.attachments.Count -gt 0) {
            foreach ($attachment in $msg.attachments) {
                $totalAttachments++
                try {
                    $fileName = "$($msg.id)_$($attachment.filename)"
                    $filePath = Join-Path $MediaDirectory $fileName

                    Invoke-WebRequest -Uri $attachment.url -OutFile $filePath -ErrorAction Stop
                    $downloadCount++

                    Write-Host "`r    Downloaded $downloadCount/$totalAttachments files..." -ForegroundColor Gray -NoNewline
                }
                catch {
                    Write-Warning "Failed to download $($attachment.filename): $_"
                }

                Start-Sleep -Milliseconds 200  # Rate limiting
            }
        }
    }

    if ($downloadCount -gt 0) {
        Write-Host "`r  [+] Downloaded $downloadCount media files to: $MediaDirectory" -ForegroundColor Green
    } else {
        Write-Host "`r  [*] No media files to download" -ForegroundColor Gray
    }
}

function Show-DMChannelList {
    param([array]$Channels)

    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "                    YOUR DM CONVERSATIONS                                   " -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $Channels.Count; $i++) {
        $channel = $Channels[$i]

        $name = if ($channel.type -eq 1) {
            # DM channel
            if ($channel.recipients -and $channel.recipients.Count -gt 0) {
                $recipient = $channel.recipients[0]
                if ($recipient.global_name) {
                    $recipient.global_name
                } else {
                    "$($recipient.username)#$($recipient.discriminator)"
                }
            } else {
                "Unknown User"
            }
        } elseif ($channel.type -eq 3) {
            # Group DM
            $memberNames = @()
            foreach ($recipient in $channel.recipients) {
                if ($recipient.global_name) {
                    $memberNames += $recipient.global_name
                } else {
                    $memberNames += $recipient.username
                }
            }
            $memberList = $memberNames -join ", "

            if ($channel.name) {
                "$($channel.name) ($($channel.recipients.Count) members) [$memberList]"
            } else {
                "Group DM ($($channel.recipients.Count) members) [$memberList]"
            }
        } else {
            "Unknown Channel"
        }

        Write-Host "  [$($i + 1)] " -ForegroundColor White -NoNewline
        Write-Host "$name" -ForegroundColor Cyan
    }

    Write-Host ""
}

function Backup-SelectedDMs {
    param(
        [array]$Channels,
        [string]$Token,
        [string]$Format,
        [bool]$DownloadMediaFiles,
        [string]$CurrentUserId
    )

    Write-Host "[?] Enter DM numbers to backup (e.g., 1,3,5 or 'all'): " -ForegroundColor Yellow -NoNewline
    $selection = Read-Host

    $selectedIndices = @()

    if ($selection.ToLower() -eq "all") {
        $selectedIndices = 0..($Channels.Count - 1)
    } else {
        $parts = $selection -split ','
        foreach ($part in $parts) {
            $num = $part.Trim()
            if ($num -match '^\d+$') {
                $index = [int]$num - 1
                if ($index -ge 0 -and $index -lt $Channels.Count) {
                    $selectedIndices += $index
                }
            }
        }
    }

    if ($selectedIndices.Count -eq 0) {
        Write-Host "[!] No valid selections made" -ForegroundColor Yellow
        return
    }

    Write-Host "`n[*] Backing up $($selectedIndices.Count) conversation(s)..." -ForegroundColor Cyan

    # Create output directory with user ID
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $userDirectory = Join-Path $script:config.BaseOutputDirectory $CurrentUserId
    $outputDir = Join-Path $userDirectory "Backup_$timestamp"

    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    foreach ($index in $selectedIndices) {
        $channel = $Channels[$index]

        # Get channel name
        $channelName = if ($channel.type -eq 1) {
            if ($channel.recipients -and $channel.recipients.Count -gt 0) {
                $recipient = $channel.recipients[0]
                if ($recipient.global_name) {
                    $recipient.global_name
                } else {
                    "$($recipient.username)#$($recipient.discriminator)"
                }
            } else {
                "Unknown_User"
            }
        } elseif ($channel.type -eq 3) {
            if ($channel.name) {
                $channel.name
            } else {
                "GroupDM_$($channel.id)"
            }
        } else {
            "Channel_$($channel.id)"
        }

        # Sanitize filename
        $channelName = $channelName -replace '[\\/:*?"<>|]', '_'

        Write-Host "`n[*] Backing up: $channelName" -ForegroundColor Yellow

        # Fetch messages
        $messages = Get-ChannelMessages -Token $Token -ChannelId $channel.id

        if ($messages.Count -eq 0) {
            Write-Host "  [!] No messages found in this conversation" -ForegroundColor Yellow
            continue
        }

        $channelInfo = @{
            Name = $channelName
            Id = $channel.id
            Type = $channel.type
        }

        # Export based on format
        if ($Format -eq "JSON" -or $Format -eq "All") {
            $jsonPath = Join-Path $outputDir "$channelName.json"
            Export-ToJSON -OutputPath $jsonPath -Messages $messages -ChannelInfo $channelInfo
        }

        if ($Format -eq "HTML" -or $Format -eq "All") {
            $htmlPath = Join-Path $outputDir "$channelName.html"
            Export-ToHTML -OutputPath $htmlPath -Messages $messages -ChannelInfo $channelInfo -CurrentUserId $CurrentUserId
        }

        # Download media if requested
        if ($DownloadMediaFiles) {
            $mediaDir = Join-Path $outputDir "$channelName`_media"
            Download-Media -MediaDirectory $mediaDir -Messages $messages
        }
    }

    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "[+] Backup complete!" -ForegroundColor Green
    Write-Host "[+] Output directory: $outputDir" -ForegroundColor Green
    Write-Host "===============================================================================" -ForegroundColor Cyan
}

# ============================================
# MAIN EXECUTION
# ============================================

Clear-Host

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "                                                                               " -ForegroundColor Cyan
Write-Host "                    Discord DM Backup Tool v1.0                                " -ForegroundColor Cyan
Write-Host "                    -----------------------------                              " -ForegroundColor Cyan
Write-Host "                                                                               " -ForegroundColor Cyan
Write-Host "  Export and archive your Discord DM conversations                            " -ForegroundColor Cyan
Write-Host "  Supports JSON, TXT, and HTML formats                                        " -ForegroundColor Cyan
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

Write-Host "`n[*] Starting DM backup tool..." -ForegroundColor Cyan

# Fetch user info
$userInfo = Get-UserInfo -Token $Token
if (-not $userInfo) {
    Write-Host "`n[!] Failed to authenticate. Please check your token." -ForegroundColor Red
    exit
}

# Fetch DM channels
$dmChannels = Get-DMChannels -Token $Token

if ($dmChannels.Count -eq 0) {
    Write-Host "`n[!] No DM conversations found." -ForegroundColor Yellow
    exit
}

# Show DM list
Show-DMChannelList -Channels $dmChannels

# Backup selected DMs
Backup-SelectedDMs -Channels $dmChannels `
                   -Token $Token `
                   -Format $Format `
                   -DownloadMediaFiles $DownloadMedia `
                   -CurrentUserId $userInfo.id

# Only show "Press any key" if not in quiet mode
if (-not $QuietMode) {
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
