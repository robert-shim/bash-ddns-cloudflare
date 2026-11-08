#!/bin/bash

# Get the current external IP address
## Note: It seems like CH TXT flags are required for whoami.cloudflare
external_ip_string=$(dig +short txt ch whoami.cloudflare @1.0.0.1)

# Test if dig worked, exit if failed
## Dig seems to return 0 even when a lookup fails. So, test for empty result, instead of $?
if [[ -z $external_ip_string ]]; then
    echo "[Error]: Dig failed to get public IP address!"
    exit 1
else
    # Remove quotation marks
    external_ip=${external_ip_string:1:-1}
    echo $external_ip
    exit 0
fi
