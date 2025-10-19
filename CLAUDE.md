# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a collection of PowerShell tools for analyzing Discord user data and API endpoints. The tools are designed for defensive security analysis and personal account auditing.

## Key Scripts

### DiscordAffinityAnalyzer.ps1
The main analysis tool that examines Discord guild (server) affinities and mention patterns.

**Usage:**
```powershell
# Basic usage - will prompt for token
.\DiscordAffinityAnalyzer.ps1

# With parameters
.\DiscordAffinityAnalyzer.ps1 -Token "YOUR_TOKEN" -ExportToFile

# Quiet mode (no "Press any key" prompt - for scripting)
.\DiscordAffinityAnalyzer.ps1 -Token "YOUR_TOKEN" -QuietMode

# Parameters:
#   -Token <string>      Discord authorization token
#   -ExportToFile        Export results to JSON file
#   -QuietMode           Suppress interactive prompts (for automation)
```

### DiscordTokenSearch.ps1
Searches local browser and Discord client storage for Discord authentication tokens.

**Usage:**
```powershell
.\DiscordTokenSearch.ps1
# No parameters - automatically scans common locations
```

### DiscordAPIExplorer.ps1
API exploration tool that tests all Discord API endpoints and displays available data.

**Usage:**
```powershell
# Direct execution
.\DiscordAPIExplorer.ps1 -Token "YOUR_TOKEN" -SaveToFile

# Or source the file to load functions for interactive use
. .\DiscordAPIExplorer.ps1

# Test all endpoints
$results = Test-DiscordAPI -Token "YOUR_TOKEN" -SaveToFile

# Inspect specific endpoint
Show-EndpointDetails -Results $results -EndpointName "User Info"
```

## Architecture Patterns

### API Communication Pattern
All scripts that interact with Discord API follow this pattern:

1. **Centralized API Function**: `Invoke-DiscordAPI` handles all HTTP requests
2. **Retry Logic**: Automatic retry with exponential backoff for 5xx errors
3. **Rate Limiting**:
   - Respects HTTP 429 (Too Many Requests) with `Retry-After` header
   - Configurable delay between requests (`RateLimitDelayMs`)
4. **Error Handling**: Try-catch blocks with detailed error messages

### Configuration System
DiscordAffinityAnalyzer uses a simplified `$script:config` hashtable:
```powershell
$script:config = @{
    UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
}
```

DiscordConnectionsAnalyzer uses a more complete config:
```powershell
$script:config = @{
    UserAgent = "..."
    MaxRetries = 3
    RetryDelayMs = 1000
}
```

### Data Processing Optimization
DiscordAffinityAnalyzer optimizes mention processing:
- **Mentions are grouped once** by `guild_id` before the main loop (O(n) instead of O(n²))
- Uses `Group-Object -AsHashTable -AsString` for fast lookup
- Avoids repeated filtering operations

### Output Formatting
Visual output uses:
- **Color coding**: Green (success), Red (error), Yellow (warning), Cyan (headers)
- **Progress bars**: `█` (filled) and `░` (empty) characters
- **Structured sections**: Separated by `===` and `---` lines

## Discord API Specifics

### Token Format
Discord tokens follow the pattern: `{24 chars}.{6 chars}.{27+ chars}`
- Example: `MXXXXXXXXXXXXXXXXXX.XXXXXX.XXXXXXXXXXXXXXXXXXXXXXXXXXX`
- Validated using regex: `^[A-Za-z0-9\._\-]+$`

### Key API Endpoints Used
- `/users/@me/affinities/guilds` - Guild affinity scores (activity indicators)
- `/users/@me/guilds` - User's guild list with metadata
- `/users/@me/mentions` - Recent mentions across all guilds
- `/guilds/{id}/channels` - Channel information for a specific guild

### API Response Structure
Scripts expect Discord API responses as JSON objects with specific structures. Key assumptions:
- Affinities have `.guild_affinities[]` array with `.affinity` and `.guild_id` properties
- Mentions have `.guild_id`, `.channel_id`, `.author.username`, `.timestamp`, `.content`
- Guilds have `.id`, `.name`, `.icon`, `.owner`, `.approximate_member_count`

## Security Considerations

**Token Handling:**
- Tokens are validated but stored in memory as plain strings
- Never commit tokens to version control
- Scripts prompt for tokens if not provided as parameters
- Token search tool is for defensive analysis only (finding your own leaked tokens)

**Defensive Use Only:**
- These tools are for analyzing your own Discord account
- Do not use for credential harvesting or unauthorized access
- Respect Discord's Terms of Service and rate limits

## Common Modifications

### Adjusting Rate Limits
Edit `$script:config.RateLimitDelayMs` in DiscordAffinityAnalyzer.ps1 (default: 500ms)

### Changing Visual Output
- Bar length: Modify `$script:config.BarLength` (default: 20 characters)
- Content preview length: Modify `$script:config.ContentMaxLength` (default: 80 characters)

### Adding New Discord Endpoints
In CheckDiscordApi.ps1, add to the `$endpoints` hashtable:
```powershell
$endpoints = @{
    "Endpoint Name" = "https://discord.com/api/v10/path/to/endpoint"
    # ...
}
```

## Error Patterns

**Common Issues:**
1. **401 Unauthorized**: Invalid or expired token
2. **429 Rate Limit**: Too many requests - automatically retried with backoff
3. **403 Forbidden**: Token lacks permissions for endpoint
4. **Empty Results**: Check MinAffinity threshold - may be filtering all results
