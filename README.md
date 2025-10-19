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
- [Common Use Cases](#common-use-cases)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)

---

## 🛠️ Tools Overview

| Tool | Purpose | Key Features |
|------|---------|--------------|
| **DiscordToolsLauncher.ps1** | 🚀 Main launcher (START HERE!) | Interactive menu, token management, help |
| **DiscordTokenSearch.ps1** | Find Discord tokens on your system | Searches Discord, browsers, and other apps |
| **DiscordAPIExplorer.ps1** | Explore available Discord API endpoints | Tests 20+ endpoints, shows available data |
| **DiscordAffinityAnalyzer.ps1** | Analyze server activity and mentions | Shows affinity scores, mention statistics |
| **DiscordConnectionsAnalyzer.ps1** | Audit connected accounts & privacy | Privacy scoring, token exposure detection |

---

## 📦 Installation

### Prerequisites

- **Windows PowerShell 5.1** or **PowerShell 7+**
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

Advanced token search tool that finds both unencrypted AND encrypted Discord authentication tokens.

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

# Export for further analysis
.\DiscordConnectionsAnalyzer.ps1 -Token "TOKEN" -ExportToFile
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

**Last Updated:** October 2025
**Version:** 1.0
