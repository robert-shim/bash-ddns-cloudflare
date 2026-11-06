# bash-ddns-cloudflare
Simple bash script to dynamically (and periodically) update an existing Cloudflare DNS record via API

# Credit goes to: fire1ce (Stas Yakobov)
# <https://github.com/fire1ce/DDNS-Cloudflare-Bash>

All I did here was to take his script and make small modifications to fit my purpose.
My intention is to use Raspberry Pi 4 for dynamic DNS, using Cloudflare in this case.

Reference for Cloudflare API:
<https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/edit/>

My approach in this simple bash script is to work with an existing Cloudflare DNS record,
  and continuously updating it (PATCH) via API rather than overwriting it.
