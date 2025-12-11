# Discord Tools Suite

A comprehensive collection of PowerShell tools for Discord API analysis and security testing.

## ⚠️ Security Notice

These tools are designed for **educational purposes and security research only**. Use them responsibly and only on accounts you own or have explicit permission to test.

---

## 📋 Table of Contents

- [Tools Overview](#tools-overview)
- [Installation](#installation)
- [Tool Documentation](#tool-documentation)
  - [1. Discord Token Search](#1-discord-token-search)
  - [2. Discord API Explorer](#2-discord-api-explorer)
  - [3. Discord Affinity Analyzer](#3-discord-affinity-analyzer)
  - [4. Discord Connections Analyzer](#4-discord-connections-analyzer)
  - [5. Discord Message Analytics](#5-discord-message-analytics)
  - [6. Discord Friend Network Analyzer](#6-discord-friend-network-analyzer)
  - [7. Discord DM Backup](#7-discord-dm-backup)
- [Common Use Cases](#common-use-cases)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)
- [Testing](#testing)

---

## 🛠️ Tools Overview

| Tool | Purpose | Key Features |
|------|---------|--------------|
| **DiscordToolsLauncher.ps1** | 🚀 Main launcher (START HERE!) | Interactive menu, token management, help |
| **DiscordTokenSearch.ps1** | Find Discord tokens on your system | Searches Discord, browsers, and other apps |
| **DiscordAPIExplorer.ps1** | Explore available Discord API endpoints | Tests 20+ endpoints, shows available data |
| **DiscordAffinityAnalyzer.ps1** | Analyze server activity and mentions | Shows affinity scores, mention statistics |
| **DiscordConnectionsAnalyzer.ps1** | Audit connected accounts & privacy | Privacy scoring, token exposure detection |
| **DiscordMessageAnalyzer.ps1** | Analyze messaging patterns & activity | DM stats, emoji usage, time-based analysis |
| **DiscordFriendNetworkAnalyzer.ps1** | Map friend relationships & networks | Mutual servers, friend distribution, social graph |
| **DiscordDMBackup.ps1** | Export & archive DM conversations | JSON/HTML export, search functionality, media visualization, organized backups |

---

## 📦 Installation

### Prerequisites

- **Windows PowerShell 5.1** or **PowerShell 7+**
  - PowerShell 7+ wird empfohlen für bessere Performance und Kompatibilität
  - [📥 PowerShell 7 Download (Microsoft)](https://learn.microsoft.com/de-de/powershell/scripting/install/install-powershell-on-windows?view=powershell-7.5)
- **Windows 10/11** (for best experience with Windows Terminal)
- **Execution Policy** set to allow scripts:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

### Quick Start

**Option 1: Batch File Launcher (Easiest - Windows Terminal Support)**

1. Clone or download this repository
2. Double-click `LaunchDiscordTools.bat`

The batch launcher:
- ✨ Automatically opens Windows Terminal with optimal window size (79x35)
- 🚀 Starts the interactive PowerShell launcher
- 📏 Perfect formatting for the menu display

**Option 2: PowerShell Launcher (Traditional)**

1. Clone or download this repository
2. Open PowerShell in the tools directory
3. Run the main launcher:

```powershell
.\DiscordToolsLauncher.ps1
```

The launcher provides:
- 🎯 Interactive menu to select tools
- 🔑 Token management (set once, use everywhere)
- 📚 Built-in help and documentation
- ✅ Input validation and error handling
- 📐 Auto-adjusts window size for optimal display

**Option 3: Run Tools Individually**

```powershell
# Example
.\DiscordAffinityAnalyzer.ps1 -Token "YOUR_DISCORD_TOKEN_HERE"

# With QuietMode (suppresses "Press any key" prompts - useful when calling from other scripts)
.\DiscordAffinityAnalyzer.ps1 -Token "YOUR_DISCORD_TOKEN_HERE" -QuietMode
```

---

## 📖 Tool Documentation

### 1. Discord Token Search

**File:** `DiscordTokenSearch.ps1`

Advanced token search tool that finds, validates, and displays Discord authentication tokens with usernames. Automatically filters out invalid/expired tokens.

#### Features

**Scans Multiple Platforms:**
- Discord clients (Stable, Canary, PTB, Lightcord)
- Browsers (Chrome, Edge, Opera, Opera GX, Brave, Yandex, Vivaldi)

**Encryption Support:**
- Detects AES-GCM encrypted tokens (Discord's new security)
- Automatically extracts master keys from Local State files
- Decrypts tokens using DPAPI + AES-GCM (requires PowerShell 7+)

**Smart Detection:**
- Finds unencrypted tokens (old format)
- Finds encrypted tokens (new format: `dQw4w9WgXcQ:base64`)
- Offers to install PowerShell 7 if encrypted tokens detected

**Token Validation:**
- Validates all found tokens via Discord API
- Displays username/global name for each valid token
- Shows Discord ID for each account
- Automatically filters out invalid/expired tokens
- Progress indicator during validation

#### Requirements

- **PowerShell 5.1+** for basic token search
- **PowerShell 7+** for encrypted token decryption

#### Usage

```powershell
.\DiscordTokenSearch.ps1
```

**Note:** If encrypted tokens are found on PowerShell 5.1, the script offers automatic PowerShell 7 installation via winget.

#### How It Works

1. Scans LevelDB Storage (`.ldb` and `.log` files)
2. Extracts Master Key from `Local State` file (DPAPI decryption)
3. Detects Token Format:
   - Unencrypted: `[24 chars].[6 chars].[27+ chars]`
   - Encrypted: `dQw4w9WgXcQ:[base64 data]`
4. Decrypts AES-GCM tokens using master key + nonce (PS7+ only)
5. Displays all found tokens by platform

#### Output Example

```
Checking: Discord
  Master key loaded
  Found 2 encrypted token(s), decrypting...
  Successfully decrypted 2 token(s)
  Found 2 token(s)

Checking: Chrome
  Master key loaded
  Found 1 token(s)

========================================
Gefundene Tokens:
========================================

[Discord]
  MXXXXXXXXXXXXXXXXXX.XXXXXX.XXXXXXXXXXXXXXXXXXXXXXXXXXX
  OXXXXXXXXXXXXXXXXXX.XXXXXX.XXXXXXXXXXXXXXXXXXXXXXXXXXX

[Chrome]
  NXXXXXXXXXXXXXXXXXX.XXXXXX.XXXXXXXXXXXXXXXXXXXXXXXXXXX
```

#### Encrypted Token Format

Discord now uses **AES-256-GCM** encryption:

```
Prefix: "dQw4w9WgXcQ:"
Format: v10/v11 + 12-byte nonce + ciphertext + 16-byte tag
Encryption: AES-GCM with DPAPI-protected master key
```

---

### 2. Discord API Explorer

**File:** `DiscordAPIExplorer.ps1`

Comprehensive API endpoint testing tool that discovers what data is accessible via the Discord API.

#### Usage

```powershell
# Basic usage
.\DiscordAPIExplorer.ps1 -Token "YOUR_TOKEN"

# Save results to JSON file
.\DiscordAPIExplorer.ps1 -Token "YOUR_TOKEN" -SaveToFile
```

**Advanced Usage (Dot-Sourcing):**

For interactive exploration, you can load the functions into your session:

```powershell
# Load functions
. .\DiscordAPIExplorer.ps1 -Token "YOUR_TOKEN"

# Run the test and save results in variable
$results = Test-DiscordAPI -Token "YOUR_TOKEN" -SaveToFile

# View specific endpoint details
Show-EndpointDetails -Results $results -EndpointName "User Info"
```

#### Tested Endpoints

- **User Data:** Info, Settings, Profile, Connections
- **Social:** Guilds, Relationships, DM Channels
- **Billing:** Subscriptions, Payment Methods, Payment History
- **Gaming:** Applications, Library, Entitlements
- **Activity:** Mentions, Affinities, Consents

#### Output Example

```
=== Discord API Explorer ===
Testing 20 endpoints...

Testing: User Info
  Status: SUCCESS
  Fields (10): id, username, avatar, email, phone, verified, mfa_enabled, ...

Testing: User Guilds
  Status: SUCCESS
  Type: Array with 25 items
  Sample Fields: id, name, icon, owner, permissions...
```

---

### 3. Discord Affinity Analyzer

**File:** `DiscordAffinityAnalyzer.ps1`

Analyzes your Discord server activity using Discord's internal affinity scoring system and mention tracking.

#### Usage

```powershell
.\DiscordAffinityAnalyzer.ps1 -Token "YOUR_TOKEN"
```

#### Features

- **Affinity Scoring:** Shows Discord's internal activity metrics per server
  - **Absolute Scores:** Raw affinity values from Discord API
  - **Relative Activity:** Percentage of your total Discord activity per server
  - **Visual Bars:** Progress bars showing relative activity distribution
- **Server Information:**
  - Owner status indicator
  - Member counts
  - Active channel lists
- **Mention Tracking:** Complete mention history with context
- **Channel Analysis:** Most active channels per server
- **Top Mentioners:** Identifies who mentions you most
- **No Limits:** Shows all data (no artificial thresholds)

#### Output Example

```
===============================================================================
                    DISCORD AFFINITY & MENTION ANALYZER
===============================================================================

[*] Fetching guild affinities...
[+] Found affinities for 10 guilds
[*] Fetching mentions (last 25)...
[+] Found 42 mentions

===============================================================================
                          TOP GUILDS BY AFFINITY
===============================================================================
Total Affinity Score: 4087.01

-------------------------------------------------------------------------------
Rank #1 - [My Server] (Owner)
Affinity Score: 1746.21
Relative Activity: 42.7% [########-----------]
Members: 1,234
Mentions: 23 mentions across 5 channels

Most Active Channels:
  #general: 15 mentions
  #memes: 5 mentions
  #bot-commands: 3 mentions

Recent Mentions:
  [2024-01-15 14:23] @Friend: Hey @you check this out!
  [2024-01-15 12:45] @Admin: @you can you help with this?

-------------------------------------------------------------------------------
Rank #2 - [Gaming Guild]
Affinity Score: 892.45
Relative Activity: 21.8% [####--------------]
Members: 567
Mentions: 12 mentions across 3 channels

===============================================================================
                          MENTION STATISTICS
===============================================================================

Total Mentions: 42 across 10 servers

Top People Who Mention You:
  1. Friend (8 times)
  2. Admin (6 times)
  3. BotName (4 times)

Guilds with Most Mentions:
  1. My Server: 23 mentions
  2. Gaming Guild: 12 mentions
  3. Dev Server: 7 mentions

===============================================================================
                               SUMMARY
===============================================================================

Total Guilds Analyzed: 10
Total Mentions: 42

Affinity Scores (Discord's activity metric):
  Average: 523.45
  Highest: 1746.21 (My Server)
```

---

### 4. Discord Connections Analyzer

**File:** `DiscordConnectionsAnalyzer.ps1`

Privacy and security auditing tool for connected third-party accounts (Spotify, Steam, etc.).

#### Usage

```powershell
# Basic analysis
.\DiscordConnectionsAnalyzer.ps1 -Token "YOUR_TOKEN"

# Export results to file
.\DiscordConnectionsAnalyzer.ps1 -Token "YOUR_TOKEN" -ExportToFile
```

#### Features

- **Account Overview:** Status, verification, visibility
- **Privacy Score:** 0-100 scale with letter grade (A-F)
- **Security Warnings:** Detects exposed access tokens
- **Activity Status:** Shows which accounts display activity
- **Metadata Display:** Steam games, LoL stats, etc.
- **Token Exposure:** Highlights critical security issues

#### Privacy Scoring

| Issue | Score Penalty | Severity |
|-------|--------------|----------|
| Public Visibility | -5 points | Medium |
| Friend Sync Enabled | -5 points | Low |
| Access Token Exposed | -15 points | **CRITICAL** |
| Revoked with Token | -10 points | High |

#### Output Example

```
===============================================================================
                    CONNECTED ACCOUNTS OVERVIEW
===============================================================================

Total Accounts: 5
Active: 5 | Revoked: 0 | Public: 3

WARNING: 2 accounts have exposed access tokens!

===============================================================================
                          ACCOUNT DETAILS
===============================================================================

SPOTIFY - JohnDoe
    Status: Active | Verified: Yes
    Visibility: Public | Activity: ON | Friend Sync: OFF
    WARNING: Access Token Exposed!
    Token: BQC2QVINw-TLxsY2UvOL2lAH5sIoBRVAl41_QcVXtanlJ2Z...

LEAGUEOFLEGENDS - Player123#EUW
    Status: Active | Verified: Yes
    Visibility: Public | Activity: ON | Friend Sync: OFF
    Metadata: summonerLevel=57, profileIconId=6760

===============================================================================
                          PRIVACY & SECURITY SCORE
===============================================================================

Score: 40/100 (Grade: D)

Issues Found:
  - Public account: leagueoflegends
  - Public account: spotify
  - Access token exposed: spotify
  - Public account: twitch
  - Access token exposed: twitch

Recommendations:
  ! CRITICAL: Revoke and re-link accounts with exposed tokens
  - Consider making sensitive accounts private

===============================================================================
                          ACTIVITY DISPLAY STATUS
===============================================================================

Accounts Showing Activity:
  [+] spotify - JohnDoe
  [+] leagueoflegends - Player123#EUW
  [+] riotgames - Player123#EUW
```

---

### 5. Discord Message Analytics

**File:** `DiscordMessageAnalyzer.ps1`

Comprehensive tool for analyzing your Discord messaging patterns, DM activity, emoji usage, and communication statistics.

#### Usage

```powershell
# Basic usage
.\DiscordMessageAnalyzer.ps1 -Token "YOUR_TOKEN"

# Export results to JSON file
.\DiscordMessageAnalyzer.ps1 -Token "YOUR_TOKEN" -ExportToFile
```

#### Features

- **Message Statistics:**
  - Total mentions received and breakdown by type
  - DM conversation analysis with send/receive ratios
  - Message length and word count statistics

- **Top Metrics:**
  - Top servers by mention count
  - Top users who mention you
  - Most active DM conversations

- **Emoji Analysis:**
  - Most used emojis (Unicode + custom Discord emojis)
  - Frequency tracking across all messages

- **Time-Based Analysis:**
  - Activity patterns by hour of day
  - Activity distribution by day of week
  - Identifies your most active communication times

- **DM Activity:**
  - Analyzes up to 10 most recent DM conversations
  - Shows message counts (sent vs received)
  - Average message length per conversation
  - Last message timestamps

#### Output Example

```
===============================================================================
                    MESSAGE ANALYTICS DASHBOARD
===============================================================================

=== OVERALL STATISTICS ===
Total Mentions Received: 42
Total DM Conversations Analyzed: 8
Total DM Messages: 156

=== MENTION TYPE BREAKDOWN ===
Direct Mentions (@you): 35
Role Mentions: 5
@everyone/@here Mentions: 2

=== TOP SERVERS BY MENTIONS ===
  1. My Server: 23 mentions
  2. Gaming Guild: 12 mentions
  3. Dev Server: 7 mentions

=== TOP USERS WHO MENTION YOU ===
  1. Friend#1234: 8 mentions
  2. Admin#5678: 6 mentions
  3. Bot#0000: 4 mentions

=== TOP DM CONVERSATIONS ===

  1. Friend#1234
     Total Messages: 45
     Your Messages: 22 | Received: 23
     Avg Message Length: 67.3 characters

  2. Colleague#5678
     Total Messages: 38
     Your Messages: 20 | Received: 18
     Avg Message Length: 52.1 characters

=== DM vs SERVER ACTIVITY ===
Total DM Messages Sent: 82
Total DM Messages Received: 74
Send/Receive Ratio: 1.11 (Balanced)

=== EMOJI USAGE (from mentions) ===
  1. 😂 - used 15 times
  2. 👍 - used 12 times
  3. ❤️ - used 8 times
  4. <:custom:123456789> - used 6 times
  5. 🔥 - used 5 times

=== ACTIVITY BY HOUR (from mentions) ===
Most Active Hours:
  18:00 | #################### (12 messages)
  20:00 | ################# (10 messages)
  14:00 | ########### (6 messages)

=== ACTIVITY BY DAY OF WEEK (from mentions) ===
  Monday | ########### (8 messages)
  Tuesday | ############### (11 messages)
  Wednesday | ################## (13 messages)
  Thursday | ########## (7 messages)
  Friday | ################# (12 messages)
  Saturday | ###### (4 messages)
  Sunday | ### (2 messages)
```

#### Data Sources

The tool analyzes:
- **Recent Mentions:** Last 100 mentions across all servers
- **DM Channels:** Up to 10 most recent DM conversations (50 messages each)
- **Guild Information:** Server membership and metadata

#### Privacy & Rate Limiting

- Built-in rate limiting (300-500ms between API calls)
- Analyzes only YOUR data (no third-party access)
- Optional JSON export for further analysis
- All data stays local unless exported

---

### 6. Discord Friend Network Analyzer

**File:** `DiscordFriendNetworkAnalyzer.ps1`

Comprehensive tool for analyzing your Discord friend network, mapping relationships, and discovering mutual connections across servers.

#### Usage

```powershell
# Basic usage
.\DiscordFriendNetworkAnalyzer.ps1 -Token "YOUR_TOKEN"

# Export results to JSON file
.\DiscordFriendNetworkAnalyzer.ps1 -Token "YOUR_TOKEN" -ExportToFile
```

#### Features

- **Friend Analysis:**
  - Complete friend list with relationship data
  - Identifies mutual servers for each friend
  - Ranks friends by number of mutual servers
  - Separates server friends from DM-only friends

- **Server Analytics:**
  - Top servers by friend count
  - Shows which friends are in each server
  - Server-based friend clustering
  - Identifies your most social servers

- **Network Statistics:**
  - Total friends and servers overview
  - Friend distribution analysis
  - Average mutual servers per friend
  - Percentage of friends with mutual servers

- **Social Patterns:**
  - Discovers friend clustering patterns
  - Maps your social network structure
  - Identifies isolated vs. connected friends

#### Output Example

```
===============================================================================
                    FRIEND NETWORK ANALYSIS
===============================================================================

=== OVERALL STATISTICS ===
Total Friends: 42
Total Servers: 16
Servers with Friends: 8

=== TOP FRIENDS BY MUTUAL SERVERS ===
  1. BestFriend: 8 mutual servers
  2. GamingBuddy: 6 mutual servers
  3. Colleague: 4 mutual servers
  4. ClassMate: 3 mutual servers
  5. Teammate: 2 mutual servers

=== TOP SERVERS BY FRIEND COUNT ===

  1. Gaming Community
     Friends in this server: 15
       - BestFriend
       - GamingBuddy
       - Player123
       - ProGamer
       - StreamerFriend
       ... and 10 more

  2. Developer Hub
     Friends in this server: 8
       - Colleague
       - CodeMaster
       - DevFriend
       ... and 5 more

=== FRIEND DISTRIBUTION ===
Friends with mutual servers: 35
Friends without mutual servers: 7
Percentage with mutual servers: 83.3%
Average mutual servers per friend: 2.4

===============================================================================
                    DETAILED FRIEND LIST
===============================================================================

=== FRIENDS WITH MUTUAL SERVERS ===

  BestFriend (8 mutual servers)
    - Gaming Community
    - Developer Hub
    - Movie Nights
    ... and 5 more

  GamingBuddy (6 mutual servers)
    - Gaming Community
    - FPS Squad
    - Strategy Games

=== FRIENDS WITHOUT MUTUAL SERVERS (DM only) ===
  - RandomPerson
  - OldFriend
  - DMContact
```

#### Data Sources

The tool analyzes:
- **Friend Relationships:** Complete friend list from Discord API
- **Server Memberships:** Your server list and member data
- **Mutual Connections:** Cross-references friends across servers

#### Privacy & Limitations

- Analyzes only YOUR friend list and server memberships
- Server member data may be limited based on server permissions
- Large servers may have partial member data
- All data stays local unless exported
- Built-in rate limiting to respect Discord API

---

### 7. Discord DM Backup

**File:** `DiscordDMBackup.ps1`

Comprehensive backup tool for exporting and archiving Discord DM conversations with interactive search, media visualization, and organized storage per Discord account.

#### Usage

```powershell
# Basic usage (HTML export - default)
.\DiscordDMBackup.ps1 -Token "YOUR_TOKEN"

# Export as JSON
.\DiscordDMBackup.ps1 -Token "YOUR_TOKEN" -Format JSON

# Export as HTML (with search functionality)
.\DiscordDMBackup.ps1 -Token "YOUR_TOKEN" -Format HTML

# Export all formats
.\DiscordDMBackup.ps1 -Token "YOUR_TOKEN" -Format All

# With media downloads
.\DiscordDMBackup.ps1 -Token "YOUR_TOKEN" -DownloadMedia
```

#### Features

- **🔍 Interactive Search (HTML):**
  - Text-based search through message content
  - Filter messages by specific user
  - Live filtering without page reload
  - Search statistics display
  - Combine text search + user filter

- **🎨 Modern HTML Export:**
  - Discord-themed dark mode design
  - Chat-style layout (left/right alignment)
  - Unique colors for each user
  - **Embedded media visualization:**
    - Images (PNG, JPG, GIF, WEBP, BMP) display inline
    - Videos (MP4, WEBM, MOV) with playback controls
    - Clickable for full view/download
  - Full date/time stamps (dd.MM.yyyy HH:mm)
  - Responsive and mobile-friendly

- **📁 Organized Storage:**
  - Backups organized by Discord User ID
  - Structure: `DM_Backups/[USER_ID]/Backup_TIMESTAMP/`
  - Multiple accounts get separate folders
  - Stored in script directory (not user home)

- **📦 Export Formats:**
  - **HTML**: Beautiful chat interface with search (default)
  - **JSON**: Complete message data with full metadata
  - **All**: Exports both formats simultaneously

- **💬 Selective Backup:**
  - View all DM conversations with member lists
  - Group DMs show all participants
  - Choose specific conversations to backup
  - Backup all conversations at once
  - Interactive selection interface

- **🎬 Media Support:**
  - Optional media file downloads
  - Preserves attachment URLs in exports
  - Organizes media by conversation
  - Supports all file types

- **⚡ Smart Features:**
  - Chronological message ordering (oldest first)
  - Handles large conversations (up to 10,000 messages)
  - Rate limiting to respect Discord API
  - Culture-invariant date parsing
  - Sanitized filenames for compatibility

#### Output Example

**JSON Format:**
```json
{
  "Channel": {
    "Name": "Friend#1234",
    "Id": "123456789",
    "Type": 1
  },
  "MessageCount": 150,
  "ExportedAt": "2025-12-07 15:30:00",
  "Messages": [
    {
      "id": "123456789",
      "content": "Hello!",
      "timestamp": "2025-01-01T10:00:00.000Z",
      "author": {
        "username": "Friend",
        "global_name": "Friend#1234"
      }
    }
  ]
}
```

**HTML Format:**
```html
<!-- Modern chat-style interface with: -->
- 🔍 Search bar with user filter dropdown
- 💬 Left-aligned messages from others (gray)
- 💬 Right-aligned messages from you (blue)
- 🎨 Unique color for each user
- 🖼️ Embedded images (clickable)
- 🎥 Embedded videos (with playback)
- 📊 Live search statistics
- 📅 Full timestamps (dd.MM.yyyy HH:mm)
```

**Search Functionality Example:**
```
┌─────────────────────────────────────────┐
│ 🔍 Nachricht suchen...  | 👥 Alle ▼    │
├─────────────────────────────────────────┤
│ 📊 Zeige 45 von 5211 Nachrichten       │
└─────────────────────────────────────────┘

[Search for "hello" + filter by "Friend"]
→ Shows only messages containing "hello" from Friend
```

#### Directory Structure

```
discord-tools-suite/
└── DM_Backups/
    ├── 123456789012345678/          # User ID 1
    │   ├── Backup_20251207_153000/
    │   │   ├── Friend_Name.json
    │   │   ├── Friend_Name.html    # With search & media
    │   │   ├── Friend_Name_media/
    │   │   │   ├── 123456_image.png
    │   │   │   ├── 123457_video.mp4
    │   │   │   └── ...
    │   │   └── Group_Chat.html
    │   └── Backup_20251207_210000/
    │       └── ...
    └── 987654321098765432/          # User ID 2
        └── Backup_20251208_093000/
            └── ...
```

**Benefits:**
- ✅ Each Discord account gets its own folder
- ✅ Multiple backups from same account stay organized
- ✅ Easy to manage multi-account backups
- ✅ Stored in script directory for portability

#### Interactive Selection

When you run the tool, you'll see:
```
===============================================================================
                    YOUR DM CONVERSATIONS
===============================================================================

  [1] Friend#1234
  [2] Colleague#5678
  [3] Group DM (3 members) [Alice, Bob, Charlie]
  [4] Gaming Squad (5 members) [Player1, Player2, Player3, Player4, Player5]
  [5] Work Team (8 members) [...]
  ...

[?] Enter DM numbers to backup (e.g., 1,3,5 or 'all'):
```

**Group DM Display:**
- Shows member count
- Lists all participants in brackets
- Makes it easy to identify which group chat is which

#### Performance Notes

- Fetches messages in batches of 100 (Discord API limit)
- Rate limited to prevent API abuse (500ms delay between requests)
- Large conversations may take several minutes
- Safety limit of 10,000 messages per conversation
- Media downloads add additional time (200ms per file)

#### Use Cases

- **Backup Important Conversations**: Archive valuable discussions
- **Before Account Changes**: Save DMs before deleting account
- **Legal/Compliance**: Document business communications
- **Nostalgia**: Save old conversations with friends
- **Migration**: Move conversations to another platform

---

## 🎯 Common Use Cases

### Security Audit

```powershell
# 1. Find tokens on your system
.\DiscordTokenSearch.ps1

# 2. Analyze privacy settings
.\DiscordConnectionsAnalyzer.ps1 -Token "TOKEN" -ExportToFile

# 3. Check for exposed data
$results = Test-DiscordAPI -Token "TOKEN" -SaveToFile
```

### Activity Analysis

```powershell
# Analyze server engagement
.\DiscordAffinityAnalyzer.ps1 -Token "TOKEN"

# Analyze messaging patterns
.\DiscordMessageAnalyzer.ps1 -Token "TOKEN"

# Analyze friend network
.\DiscordFriendNetworkAnalyzer.ps1 -Token "TOKEN"

# Backup DM conversations
.\DiscordDMBackup.ps1 -Token "TOKEN" -Format All

# Export for further analysis
.\DiscordConnectionsAnalyzer.ps1 -Token "TOKEN" -ExportToFile
.\DiscordMessageAnalyzer.ps1 -Token "TOKEN" -ExportToFile
.\DiscordFriendNetworkAnalyzer.ps1 -Token "TOKEN" -ExportToFile
```

### Data Backup

```powershell
# Backup all DMs in all formats
.\DiscordDMBackup.ps1 -Token "TOKEN" -Format All

# Backup specific DM with media
.\DiscordDMBackup.ps1 -Token "TOKEN" -Format HTML -DownloadMedia

# Quick JSON backup
.\DiscordDMBackup.ps1 -Token "TOKEN"
```

### API Research

```powershell
# Discover available endpoints
$results = Test-DiscordAPI -Token "TOKEN"

# View specific endpoint
Show-EndpointDetails -Results $results -EndpointName "User Guilds"

# Export all data
Test-DiscordAPI -Token "TOKEN" -SaveToFile
```

---

## 🔒 Security Best Practices

### For Users

1. **Never share your Discord token** - It's equivalent to your password
2. **Enable 2FA** - Adds extra security layer
3. **Regular audits** - Check connected accounts monthly
4. **Monitor sessions** - Review active devices in Discord settings
5. **Revoke exposed tokens** - If a token leaks, regenerate it immediately

### For Developers

1. **Never hardcode tokens** - Use environment variables
2. **Implement rate limiting** - Respect Discord's API limits
3. **Secure webhooks** - Don't expose webhook URLs publicly
4. **Log securely** - Never log tokens or sensitive data
5. **Validate input** - Always sanitize user input

### Discord Token Format

Valid Discord token structure:
```
[24 chars].[6 chars].[27+ chars]
Example: MXXXXXXXXXXXXXXXXXX.XXXXXX.XXXXXXXXXXXXXXXXXXXXXXXXXXX
```

---

## 🐛 Troubleshooting

### Common Issues

#### "Unauthorized (401)" Error

**Problem:** Invalid or expired token

**Solution:**
```powershell
# Get fresh token using token search
.\DiscordTokenSearch.ps1
```

#### "Rate Limited (429)" Error

**Problem:** Too many API requests

**Solution:** Wait 60 seconds, scripts have built-in rate limiting

#### "Execution Policy" Error

**Problem:** PowerShell script execution blocked

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### No Tokens Found

**Problem:** Discord not installed or no saved sessions

**Solution:**
1. Open Discord and log in
2. Close Discord completely
3. Run token search again

#### Unicode Display Issues

**Problem:** Characters show as `?` or boxes

**Solution:** Use PowerShell 7+ or Windows Terminal for better Unicode support

---

## 📊 API Rate Limits

Discord API has the following limits:

| Action | Limit | Window |
|--------|-------|--------|
| Global | 50 requests | 1 second |
| Per Route | 5 requests | 1 second |
| Auth Login | 5 attempts | 5 minutes |

All tools include automatic rate limiting and retry logic.

---

## 🔗 Useful Resources

- [Discord API Documentation](https://discord.com/developers/docs)
- [Discord Developer Portal](https://discord.com/developers/applications)
- [PowerShell Documentation](https://docs.microsoft.com/powershell/)

---

## 🧪 Testing

This project includes a comprehensive test suite using **Pester 5.x** - PowerShell's native testing framework.

### Test Coverage

- **40+ test cases** covering critical security functions
- **100% function coverage** for DiscordTokenSearch.ps1
- **Integration tests** for end-to-end workflows
- **Automated CI/CD** testing on every commit

### Quick Start

```powershell
# Install Pester (one-time setup)
Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck

# Run all tests
./Tests/Run-Tests.ps1

# Run with code coverage
./Tests/Run-Tests.ps1 -Coverage

# Run specific test file
./Tests/Run-Tests.ps1 -TestFile "DiscordTokenSearch.Tests.ps1"
```

### What's Tested

| Function | Test Cases | Coverage |
|----------|-----------|----------|
| `Test-TokenValidity` | 8 | Token validation, API errors, network failures |
| `Get-MasterKey` | 6 | Master key extraction, DPAPI decryption |
| `ConvertFrom-EncryptedToken` | 5 | AES-GCM decryption (PS7+), format validation |
| `Get-Tokens` | 20+ | Token detection, regex patterns, file handling |

### Documentation

For detailed test information, see:
- [`Tests/README.md`](Tests/README.md) - Setup and usage guide
- [`Tests/TEST_COVERAGE.md`](Tests/TEST_COVERAGE.md) - Detailed coverage documentation

### Continuous Integration

Tests run automatically on GitHub Actions for:
- ✅ PowerShell 5.1 and 7.4
- ✅ Every push and pull request
- ✅ Multiple operating systems

View test status: ![Tests](https://github.com/Limplom/discord-tools-suite/actions/workflows/run-tests.yml/badge.svg)

---

## 📝 Legal Disclaimer

These tools are provided for **educational and security research purposes only**.

- ✅ Use on your own accounts
- ✅ Use with explicit permission
- ✅ Use for security research
- ❌ Do not use for unauthorized access
- ❌ Do not use for credential harvesting
- ❌ Do not distribute maliciously

The authors are not responsible for misuse of these tools.

---

## 🤝 Contributing

Found a bug or have a feature request? Feel free to:

1. Report issues
2. Submit pull requests
3. Suggest improvements
4. Share feedback

---

## 📜 License

This project is provided as-is for educational purposes. Use responsibly.

---

## 🎓 Learning Resources

### Understanding Discord Tokens

Discord tokens are JWT-like credentials containing:
- **User ID** (first segment, base64)
- **Timestamp** (second segment)
- **HMAC signature** (third segment)

### How Storage Works

Discord stores tokens in LevelDB (`.ldb` and `.log` files) located at:
```
%APPDATA%\discord\Local Storage\leveldb\
```

### API Authentication

Tokens are sent in the `Authorization` header:
```
Authorization: YOUR_TOKEN_HERE
```

---

**Last Updated:** December 2025
**Version:** 1.3
