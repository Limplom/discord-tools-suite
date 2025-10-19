# Discord API Explorer
# This tool helps you discover all available API endpoints and their responses

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Token,

    [Parameter(Mandatory=$false)]
    [switch]$SaveToFile,

    [Parameter(Mandatory=$false)]
    [switch]$QuietMode  # Suppresses help text when called from another script
)

function Test-DiscordAPI {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Token,
        
        [Parameter(Mandatory=$false)]
        [switch]$SaveToFile
    )
    
    $headers = @{
        "Content-Type" = "application/json"
        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        "Authorization" = $Token
    }
    
    # All Discord API endpoints to test
    $endpoints = @{
        "User Info" = "https://discord.com/api/v10/users/@me"
        "User Settings" = "https://discord.com/api/v10/users/@me/settings"
        "User Guilds" = "https://discord.com/api/v10/users/@me/guilds"
        "User Guilds (with counts)" = "https://discord.com/api/v6/users/@me/guilds?with_counts=true"
        "User Connections" = "https://discord.com/api/v10/users/@me/connections"
        "User Relationships" = "https://discord.com/api/v10/users/@me/relationships"
        "User Channels (DMs)" = "https://discord.com/api/v10/users/@me/channels"
        "Billing Subscriptions" = "https://discord.com/api/v6/users/@me/billing/subscriptions"
        "Billing Payment Sources" = "https://discord.com/api/v6/users/@me/billing/payment-sources"
        "Billing Payment History" = "https://discord.com/api/v6/users/@me/billing/payments"
        "Nitro Boost Slots" = "https://discord.com/api/v9/users/@me/guilds/premium/subscription-slots"
        "Applications" = "https://discord.com/api/v10/users/@me/applications"
        "User Profile" = "https://discord.com/api/v10/users/@me/profile"
        "Library Applications" = "https://discord.com/api/v10/users/@me/library"
        "Entitlements" = "https://discord.com/api/v10/users/@me/entitlements"
        "Promotions" = "https://discord.com/api/v10/users/@me/billing/promotions"
        "Affinities" = "https://discord.com/api/v10/users/@me/affinities/guilds"
        "Mentions" = "https://discord.com/api/v10/users/@me/mentions"
        "Consents" = "https://discord.com/api/v10/users/@me/consent"
        "Harvest" = "https://discord.com/api/v10/users/@me/harvest"
    }
    
    $results = @{}
    $outputFile = "discord_api_dump_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    
    Write-Host "`n=== Discord API Explorer ===" -ForegroundColor Cyan
    Write-Host "Testing $($endpoints.Count) endpoints...`n" -ForegroundColor Yellow
    
    foreach ($endpoint in $endpoints.Keys) {
        Write-Host "Testing: $endpoint" -ForegroundColor Gray
        
        try {
            $response = Invoke-RestMethod -Uri $endpoints[$endpoint] `
                                         -Method Get `
                                         -Headers $headers `
                                         -ErrorAction Stop
            
            # Extract fields safely
            $fields = @()
            if ($response -and $response -isnot [String]) {
                $fields = ($response | Get-Member -MemberType NoteProperty -ErrorAction SilentlyContinue).Name
            }

            $results[$endpoint] = @{
                Status = "Success"
                URL = $endpoints[$endpoint]
                Data = $response
                Fields = $fields
                DataType = if ($response) { $response.GetType().Name } else { "null" }
            }

            Write-Host "  Status: SUCCESS" -ForegroundColor Green

            # Show preview of data
            if ($response -is [Array]) {
                Write-Host "  Type: Array with $($response.Count) items" -ForegroundColor Cyan
                if ($response.Count -gt 0) {
                    $sampleFields = ($response[0] | Get-Member -MemberType NoteProperty -ErrorAction SilentlyContinue).Name
                    if ($sampleFields) {
                        Write-Host "  Sample Fields: $(($sampleFields | Select-Object -First 5) -join ', ')..." -ForegroundColor DarkGray
                    }
                } else {
                    Write-Host "  (Empty array)" -ForegroundColor DarkGray
                }
            } elseif ($response -and $fields) {
                Write-Host "  Fields ($($fields.Count)): $($fields -join ', ')" -ForegroundColor DarkGray
            } elseif (-not $response -or $response -eq "") {
                Write-Host "  (Empty response)" -ForegroundColor DarkGray
            }
            
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.Value__
            $results[$endpoint] = @{
                Status = "Failed"
                URL = $endpoints[$endpoint]
                Error = $_.Exception.Message
                StatusCode = $statusCode
            }
            
            if ($statusCode -eq 401) {
                Write-Host "  Status: FAILED (Unauthorized - Invalid Token)" -ForegroundColor Red
            } elseif ($statusCode -eq 403) {
                Write-Host "  Status: FAILED (Forbidden - No Access)" -ForegroundColor Yellow
            } elseif ($statusCode -eq 404) {
                Write-Host "  Status: FAILED (Not Found - Endpoint doesn't exist)" -ForegroundColor DarkYellow
            } else {
                Write-Host "  Status: FAILED ($statusCode - $($_.Exception.Message))" -ForegroundColor Red
            }
        }
        
        Write-Host ""
        Start-Sleep -Milliseconds 200  # Rate limiting
    }
    
    # Summary
    $successCount = ($results.Values | Where-Object { $_.Status -eq "Success" }).Count
    $failedCount = $results.Count - $successCount
    
    Write-Host "=== Summary ===" -ForegroundColor Cyan
    Write-Host "Total Endpoints: $($results.Count)" -ForegroundColor White
    Write-Host "Successful: $successCount" -ForegroundColor Green
    Write-Host "Failed: $failedCount" -ForegroundColor Red
    
    # Save to file if requested
    if ($SaveToFile) {
        $fullPath = Join-Path (Get-Location) $outputFile
        $results | ConvertTo-Json -Depth 10 | Out-File $outputFile
        Write-Host ""
        Write-Host "Results saved to:" -ForegroundColor Green
        Write-Host "  $fullPath" -ForegroundColor Cyan
    }
    
    return $results
}


function Show-EndpointDetails {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Results,
        
        [Parameter(Mandatory=$true)]
        [string]$EndpointName
    )
    
    if (-not $Results.ContainsKey($EndpointName)) {
        Write-Host "Endpoint not found: $EndpointName" -ForegroundColor Red
        return
    }
    
    $endpoint = $Results[$EndpointName]
    
    Write-Host "`n=== $EndpointName ===" -ForegroundColor Cyan
    Write-Host "URL: $($endpoint.URL)" -ForegroundColor Gray
    Write-Host "Status: $($endpoint.Status)" -ForegroundColor $(if ($endpoint.Status -eq "Success") { "Green" } else { "Red" })
    
    if ($endpoint.Status -eq "Success") {
        Write-Host "`nAvailable Fields:" -ForegroundColor Yellow
        foreach ($field in $endpoint.Fields) {
            $value = $endpoint.Data.$field
            $type = if ($value) { $value.GetType().Name } else { "null" }
            Write-Host "  - $field : $type" -ForegroundColor White
            
            # Show sample value for primitives
            if ($type -in @("String", "Int32", "Int64", "Boolean")) {
                Write-Host "      Value: $value" -ForegroundColor DarkGray
            }
        }
        
        Write-Host "`nFull Response:" -ForegroundColor Yellow
        $endpoint.Data | ConvertTo-Json -Depth 5 | Write-Host -ForegroundColor DarkGray
    } else {
        Write-Host "Error: $($endpoint.Error)" -ForegroundColor Red
        if ($endpoint.StatusCode) {
            Write-Host "Status Code: $($endpoint.StatusCode)" -ForegroundColor Red
        }
    }
}


# ============================================
# USAGE EXAMPLES
# ============================================

# Example 1: Basic API exploration
# Only show help if not in quiet mode (not called from another script)
if (-not $QuietMode) {
    Write-Host @"

=== Discord API Explorer ===

This tool will test all Discord API endpoints and show you what data is available.

Usage:
1. Run Test-DiscordAPI with your token
2. Use Show-EndpointDetails to inspect specific endpoints

"@ -ForegroundColor Cyan
}

# ============================================
# COMMON ENDPOINTS QUICK REFERENCE
# ============================================

# Only show endpoint reference if not in quiet mode (not called from another script)
if (-not $QuietMode) {
    Write-Host @"

=== Common Discord API Endpoints ===

User Information:
  GET /users/@me                              - Current user info
  GET /users/@me/settings                     - User settings
  GET /users/@me/profile                      - User profile

Guilds (Servers):
  GET /users/@me/guilds                       - User's servers
  GET /users/@me/guilds?with_counts=true      - Servers with member counts
  GET /guilds/{guild_id}                      - Specific server details

Social:
  GET /users/@me/relationships                - Friends list
  GET /users/@me/channels                     - DM channels
  GET /users/@me/connections                  - Connected accounts (Spotify, etc.)

Billing:
  GET /users/@me/billing/subscriptions        - Nitro subscriptions
  GET /users/@me/billing/payment-sources      - Payment methods
  GET /users/@me/billing/payments             - Payment history
  GET /users/@me/guilds/premium/subscription-slots - Server boosts

Applications:
  GET /users/@me/applications                 - User's applications
  GET /users/@me/library                      - Game library
  GET /users/@me/entitlements                 - Owned items/games

Other:
  GET /users/@me/mentions                     - Recent mentions
  GET /users/@me/consent                      - Privacy settings
  GET /users/@me/affinities/guilds            - Server affinity scores

"@ -ForegroundColor Gray
}

# Execute the API test
Write-Host ""
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "                    DISCORD API EXPLORER                                    " -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host ""

$results = Test-DiscordAPI -Token $Token -SaveToFile:$SaveToFile

Write-Host ""
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "[*] API exploration complete!" -ForegroundColor Green
Write-Host "===============================================================================" -ForegroundColor Cyan

Write-Host ""

# Only show "Press any key" if not in quiet mode (not called from another script)
if (-not $QuietMode) {
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}