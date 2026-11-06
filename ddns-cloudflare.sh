#!/bin/bash

#############################################
###  Dynamic DNS-Cloudflare Script v0.01  ###
#############################################

## Please make sure the "dig" command works before running this script.

# Configuration
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd -P)

if [[ -z "$1" ]]; then
    DEFAULT_CONFIG_FILE="ddns-cloudflare.conf"
    ## Here, I am assuming default config file is in the same directory as this script file.
    ## If not, change CONFIG_FILE_PATH accordingly.
    CONFIG_FILE_PATH="$SCRIPT_DIR/$DEFAULT_CONFIG_FILE"
else
    ## Here, I am assuming user config file is in the same directory as this script file.
    ## If not, change CONFIG_FILE_PATH accordingly.
    CONFIG_FILE_PATH="${SCRIPT_DIR}/$1"
fi

# Exit if config file is missing or invalid
if ! source $CONFIG_FILE_PATH; then
    echo "[Error]: Missing or invalid $CONFIG_FILE_PATH"
    exit 1
else
    if [[ "$CLOUDFLARE_ZONE_ID" == "changeme" ]]; then
        echo "[Error]: Please update config file at $CONFIG_FILE_PATH"
        exit 1
    fi
fi

# Declare functions
get_cloudflare_dns() {
    # Load-balance two Cloudflare name servers
    local coin_flip=$((RANDOM % 2))
    local cloudflare_dns=$(dig +short $FQDN @${CLOUDFLARE_NAMESERVERS[coin_flip]})
    # Test if dig worked, exit if failed
    ## Dig seems to return 0 even when a lookup fails. So, check for empty result
    if [[ -z $cloudflare_dns ]]; then
        echo "[Error]: Dig failed to connect to ${CLOUDFLARE_NAMESERVERS[coin_flip]}!"
        exit 1
    fi

    # Write to local memory cache file
    echo $cloudflare_dns > "$MEMORY_FILE_CLOUDFLARE_DNS"
    return 0
}

# Initialize if memory file does not exist
if [[ ! -f "$MEMORY_FILE_CLOUDFLARE_DNS" ]]; then
    echo "Creating memory file..."
    get_cloudflare_dns
fi

# Read persistent memory
cached_cloudflare_dns=$(cat "$MEMORY_FILE_CLOUDFLARE_DNS")

# Get the current external IP address
## Note: It seems like CH TXT flags are required for whoami.cloudflare
external_ip_string=$(dig +short txt ch whoami.cloudflare @1.0.0.1)
# Test if dig worked, exit if failed
## Dig seems to return 0 even when a lookup fails. So, check for empty result
if [[ -z $external_ip_string ]]; then
    echo "[Error]: Dig failed to get public IP address!"
    exit 1
fi
external_ip=${external_ip_string:1:-1}

# Compare (cached) Cloudflare DNS record vs. current external IP address
if [[ "$cached_cloudflare_dns" == "$external_ip" ]]; then
    echo "[OK]: IP address match"
else
    echo "<IP address mismatch!>"
    echo "Updating to: <$external_ip> ..."
    # Push new IP address into Cloudflare using API
    ## Reference:
    ## https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/edit/
    update_cloudflare_dns_record=$(curl -s -X PATCH \
        https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$CLOUDFLARE_DNS_RECORD_ID \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -d "{\"content\": $external_ip_string}")

    #echo ${update_cloudflare_dns_record}
    success="${update_cloudflare_dns_record#*\"success\":}"
    success="${success%%,*}"
    # Cloudflare server responds with either "success":true or false
    if [[ "$success" == "true" ]]; then
        echo "[UPDATE]: Dynamic DNS update was successful"

        # Cache the updated Cloudflare DNS record, after giving it 10 seconds
        echo "Waiting..."
        for i in {1..10}
        do
            echo "$i"
            sleep 1
        done
        get_cloudflare_dns

        # Double-check the updated DNS record
        cached_cloudflare_dns=$(cat "$MEMORY_FILE_CLOUDFLARE_DNS")
        if [[ "$cached_cloudflare_dns" == "$external_ip" ]]; then
            echo "[OK]: IP address match"
            exit 0
        else
            echo "[Error]: IP address mismatch still after update!"
            exit 1
        fi

    else
        echo "[Error]: Failed to update Cloudflare DNS record!"
        exit 1
    fi
fi
