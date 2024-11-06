#!/bin/bash

# This script updates Cloudflare DNS records via Cloudflare API.
# You can configure ddns updater by configure running this script periodically by systemd timer.
# See also: https://developers.cloudflare.com/dns/manage-dns-records/how-to/managing-dynamic-ip-addresses/

# ++++++++++ Config ++++++++++
# Cloudflare API information
# Check zone id via your domain homepage in cloudflare.com
ZONE_ID="your_zone_id"
# Create token via https://dash.cloudflare.com/profile/api-tokens
API_TOKEN="your_api_token"

# List of DNS records to update
# Format: ("Type Name Content Comment")
# <myip> will be replaced with the current IP address (IPv4 or IPv6)
# <now> will be replaced with the current date and time
DNS_RECORDS=(
    "A example.com <myip> This is an example A record (last update: <now>)"
    "AAAA example.com <myip> This is an example AAAA record (last update: <now>)"
    # Add more records here
)
# ++++++++++++++++++++++++++++


# Cloudflare API endpoint
API_ENDPOINT="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"

# Function to get IP address
get_ip() {
    local ip_type=$1
    if [ "$ip_type" == "A" ]; then
        curl -4 -s ifconfig.co
    elif [ "$ip_type" == "AAAA" ]; then
        curl -6 -s ifconfig.co
    fi
}

# Function to get current datetime
get_current_datetime() {
    date +"%Y/%m/%d %H:%M:%S"
}

# Function to update DNS record
update_dns_record() {
    local type=$1
    local name=$2
    local content=$3
    local comment=$4

    # Get IP address
    if [ "$content" == "<myip>" ]; then
        content=$(get_ip $type)
    fi

    # Replace <now> placeholder with current datetime
    if [[ "$comment" == *"<now>"* ]]; then
        current_datetime=$(get_current_datetime)
        comment=${comment//"<now>"/"$current_datetime"}
    fi

    # Get DNS record ID
    record_id=$(curl -s -X GET "$API_ENDPOINT?type=$type&name=$name" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" | jq -r '.result[0].id')

    # Check if record ID was found
    if [ -z "$record_id" ]; then
        echo "Error: Could not find DNS record ID for $name"
        return
    fi

    # Update DNS record
    response=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$API_ENDPOINT/$record_id" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"comment\":\"$comment\"}")

    # Check for errors
    if [ "$response" -ne 200 ]; then
        echo "Error: Failed to update DNS record for $name (HTTP status code: $response)"
    else
        echo "Success: Updated DNS record for $name"
    fi
}

# Update each DNS record
for record in "${DNS_RECORDS[@]}"; do
    # Split record into variables
    type=$(echo $record | awk '{print $1}')
    name=$(echo $record | awk '{print $2}')
    content=$(echo $record | awk '{print $3}')
    comment=$(echo $record | cut -d ' ' -f 4-)

    update_dns_record $type $name $content "$comment"
done
