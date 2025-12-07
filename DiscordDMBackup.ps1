# Discord DM Backup Tool
# Exports and archives Discord DM conversations in multiple formats

param(
    [Parameter(Mandatory=$false)]
    [string]$Token,

    [Parameter(Mandatory=$false)]
    [ValidateSet("JSON", "TXT", "HTML", "All")]
    [string]$Format = "JSON",

    [Parameter(Mandatory=$false)]
    [switch]$DownloadMedia,

    [Parameter(Mandatory=$false)]
    [switch]$QuietMode  # Suppresses "Press any key" when called from another script
)

# Configuration
$script:config = @{
    UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    MaxMessagesPerRequest = 100  # Discord API limit
    OutputDirectory = ".\DM_Backups"
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

function Export-ToTXT {
    param(
        [string]$OutputPath,
        [array]$Messages,
        [hashtable]$ChannelInfo
    )

    $sb = New-Object System.Text.StringBuilder

    $sb.AppendLine("=" * 80) | Out-Null
    $sb.AppendLine("Discord DM Backup - $($ChannelInfo.Name)") | Out-Null
    $sb.AppendLine("Exported: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
    $sb.AppendLine("Total Messages: $($Messages.Count)") | Out-Null
    $sb.AppendLine("=" * 80) | Out-Null
    $sb.AppendLine("") | Out-Null

    foreach ($msg in $Messages) {
        $timestamp = if ($msg.timestamp) {
            [DateTime]::Parse($msg.timestamp, [System.Globalization.CultureInfo]::InvariantCulture).ToString("yyyy-MM-dd HH:mm:ss")
        } else {
            "Unknown"
        }

        $author = if ($msg.author) {
            if ($msg.author.global_name) {
                $msg.author.global_name
            } else {
                "$($msg.author.username)#$($msg.author.discriminator)"
            }
        } else {
            "Unknown"
        }

        $sb.AppendLine("[$timestamp] $author") | Out-Null
        $sb.AppendLine($msg.content) | Out-Null

        # Add attachments info
        if ($msg.attachments -and $msg.attachments.Count -gt 0) {
            foreach ($attachment in $msg.attachments) {
                $sb.AppendLine("  [Attachment: $($attachment.filename) - $($attachment.url)]") | Out-Null
            }
        }

        # Add embeds info
        if ($msg.embeds -and $msg.embeds.Count -gt 0) {
            $sb.AppendLine("  [Embed: $($msg.embeds.Count) embed(s)]") | Out-Null
        }

        $sb.AppendLine("") | Out-Null
    }

    $sb.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8

    Write-Host "  [+] TXT export: $OutputPath" -ForegroundColor Green
}

function Export-ToHTML {
    param(
        [string]$OutputPath,
        [array]$Messages,
        [hashtable]$ChannelInfo
    )

    $sb = New-Object System.Text.StringBuilder

    # HTML Header
    $sb.AppendLine("<!DOCTYPE html>") | Out-Null
    $sb.AppendLine("<html lang='en'>") | Out-Null
    $sb.AppendLine("<head>") | Out-Null
    $sb.AppendLine("    <meta charset='UTF-8'>") | Out-Null
    $sb.AppendLine("    <meta name='viewport' content='width=device-width, initial-scale=1.0'>") | Out-Null
    $sb.AppendLine("    <title>Discord DM - $($ChannelInfo.Name)</title>") | Out-Null
    $sb.AppendLine("    <style>") | Out-Null
    $sb.AppendLine("        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #36393f; color: #dcddde; margin: 0; padding: 20px; }") | Out-Null
    $sb.AppendLine("        .container { max-width: 1000px; margin: 0 auto; background: #2f3136; border-radius: 8px; padding: 20px; }") | Out-Null
    $sb.AppendLine("        .header { border-bottom: 2px solid #202225; padding-bottom: 20px; margin-bottom: 20px; }") | Out-Null
    $sb.AppendLine("        .header h1 { margin: 0; color: #fff; }") | Out-Null
    $sb.AppendLine("        .header p { margin: 5px 0; color: #b9bbbe; }") | Out-Null
    $sb.AppendLine("        .message { margin-bottom: 20px; padding: 10px; border-left: 3px solid #5865f2; background: #40444b; border-radius: 4px; }") | Out-Null
    $sb.AppendLine("        .message-header { display: flex; align-items: baseline; margin-bottom: 5px; }") | Out-Null
    $sb.AppendLine("        .author { font-weight: bold; color: #5865f2; margin-right: 10px; }") | Out-Null
    $sb.AppendLine("        .timestamp { font-size: 0.75rem; color: #72767d; }") | Out-Null
    $sb.AppendLine("        .content { color: #dcddde; white-space: pre-wrap; word-wrap: break-word; }") | Out-Null
    $sb.AppendLine("        .attachment { margin-top: 10px; padding: 8px; background: #202225; border-radius: 4px; color: #00b0f4; }") | Out-Null
    $sb.AppendLine("        .attachment a { color: #00b0f4; text-decoration: none; }") | Out-Null
    $sb.AppendLine("        .attachment a:hover { text-decoration: underline; }") | Out-Null
    $sb.AppendLine("        .embed { margin-top: 10px; padding: 8px; background: #2f3136; border-left: 4px solid #5865f2; border-radius: 4px; font-size: 0.9rem; color: #b9bbbe; }") | Out-Null
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

    # Messages
    foreach ($msg in $Messages) {
        $timestamp = if ($msg.timestamp) {
            [DateTime]::Parse($msg.timestamp, [System.Globalization.CultureInfo]::InvariantCulture).ToString("yyyy-MM-dd HH:mm:ss")
        } else {
            "Unknown"
        }

        $author = if ($msg.author) {
            if ($msg.author.global_name) {
                [System.Web.HttpUtility]::HtmlEncode($msg.author.global_name)
            } else {
                [System.Web.HttpUtility]::HtmlEncode("$($msg.author.username)#$($msg.author.discriminator)")
            }
        } else {
            "Unknown"
        }

        $content = [System.Web.HttpUtility]::HtmlEncode($msg.content)

        $sb.AppendLine("        <div class='message'>") | Out-Null
        $sb.AppendLine("            <div class='message-header'>") | Out-Null
        $sb.AppendLine("                <span class='author'>$author</span>") | Out-Null
        $sb.AppendLine("                <span class='timestamp'>$timestamp</span>") | Out-Null
        $sb.AppendLine("            </div>") | Out-Null
        $sb.AppendLine("            <div class='content'>$content</div>") | Out-Null

        # Attachments
        if ($msg.attachments -and $msg.attachments.Count -gt 0) {
            foreach ($attachment in $msg.attachments) {
                $fileName = [System.Web.HttpUtility]::HtmlEncode($attachment.filename)
                $url = [System.Web.HttpUtility]::HtmlEncode($attachment.url)
                $sb.AppendLine("            <div class='attachment'>📎 <a href='$url' target='_blank'>$fileName</a></div>") | Out-Null
            }
        }

        # Embeds
        if ($msg.embeds -and $msg.embeds.Count -gt 0) {
            $sb.AppendLine("            <div class='embed'>📋 Contains $($msg.embeds.Count) embed(s)</div>") | Out-Null
        }

        $sb.AppendLine("        </div>") | Out-Null
    }

    $sb.AppendLine("    </div>") | Out-Null
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
            if ($channel.name) {
                $channel.name
            } else {
                "Group DM ($($channel.recipients.Count) members)"
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
        [bool]$DownloadMediaFiles
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

    # Create output directory
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $outputDir = Join-Path $script:config.OutputDirectory "Backup_$timestamp"

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

        if ($Format -eq "TXT" -or $Format -eq "All") {
            $txtPath = Join-Path $outputDir "$channelName.txt"
            Export-ToTXT -OutputPath $txtPath -Messages $messages -ChannelInfo $channelInfo
        }

        if ($Format -eq "HTML" -or $Format -eq "All") {
            $htmlPath = Join-Path $outputDir "$channelName.html"
            Export-ToHTML -OutputPath $htmlPath -Messages $messages -ChannelInfo $channelInfo
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
                   -DownloadMediaFiles $DownloadMedia

# Only show "Press any key" if not in quiet mode
if (-not $QuietMode) {
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
