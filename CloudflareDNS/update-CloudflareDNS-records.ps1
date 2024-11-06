# This script updates Cloudflare DNS records via Cloudflare API.
# You can configure ddns updater by configure running this script periodically by systemd timer.
# See also: https://developers.cloudflare.com/dns/manage-dns-records/how-to/managing-dynamic-ip-addresses/

# ++++++++++ Config ++++++++++
# Cloudflare API information
# Check zone id via your domain homepage in cloudflare.com
$zoneId = "your_zone_id"
# Create token via https://dash.cloudflare.com/profile/api-tokens
$apiToken = "your_api_token"

# List of DNS records to update
# Format: ("Type Name Content Comment")
# <myip> will be replaced with the current IP address (IPv4 or IPv6)
# <now> will be replaced with the current date and time (2000/01/01 00:00:00)
$dnsRecords = @(
    "A example.com <myip> This is an example A record (last update: <now>)"
    "AAAA example.com <myip> This is an example AAAA record (last update: <now>)"
    # Add more records here
)
# ++++++++++++++++++++++++++++


# Cloudflare API endpoint
$apiEndpoint = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records"

# Function to get IP address
function Get-IpAddress {
    param (
        [string]$ipType
    )
    if ($ipType -eq "A") {
        return (Invoke-RestMethod -Uri "https://ifconfig.co" -Method Get -Headers @{"Accept"="application/json"}).ip
    } elseif ($ipType -eq "AAAA") {
        return (Invoke-RestMethod -Uri "https://ifconfig.co" -Method Get -Headers @{"Accept"="application/json"}).ip
    }
}

# Function to get current datetime
function Get-CurrentDatetime {
    return (Get-Date).ToString("yyyy/MM/dd HH:mm:ss")
}

# Function to update DNS record
function Update-DnsRecord {
    param (
        [string]$type,
        [string]$name,
        [string]$content,
        [string]$comment
    )

    # Get IP address
    if ($content -eq "<myip>") {
        $content = Get-IpAddress -ipType $type
    }

    # Replace <now> placeholder with current datetime
    if ($comment -like "*<now>*") {
        $currentDatetime = Get-CurrentDatetime
        $comment = $comment -replace "<now>", $currentDatetime
    }

    # Get DNS record ID
    $recordId = (Invoke-RestMethod -Uri "$apiEndpoint?type=$type&name=$name" -Method Get -Headers @{"Authorization"="Bearer $apiToken"; "Content-Type"="application/json"}).result[0].id

    # Check if record ID was found
    if (-not $recordId) {
        Write-Output "Error: Could not find DNS record ID for $name"
        return
    }

    # Update DNS record
    $response = Invoke-RestMethod -Uri "$apiEndpoint/$recordId" -Method Patch -Headers @{"Authorization"="Bearer $apiToken"; "Content-Type"="application/json"} -Body (@{type=$type; name=$name; content=$content; comment=$comment} | ConvertTo-Json) -StatusCodeVariable statusCode

    # Check for errors
    if ($statusCode -ne 200) {
        Write-Output "Error: Failed to update DNS record for $name (HTTP status code: $statusCode)"
    } else {
        Write-Output "Success: Updated DNS record for $name"
    }
}

# Update each DNS record
foreach ($record in $dnsRecords) {
    # Split record into variables
    $parts = $record -split ' '
    $type = $parts[0]
    $name = $parts[1]
    $content = $parts[2]
    $comment = $parts[3..($parts.Length - 1)] -join ' '

    Update-DnsRecord -type $type -name $name -content $content -comment $comment
}
