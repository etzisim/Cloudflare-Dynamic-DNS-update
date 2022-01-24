#!/bin/bash

# A bash script to update a Cloudflare DNS A record with the external IP of the source machine
# Used to provide DDNS service for my home
# Needs the DNS record pre-creating on Cloudflare
§
# Proxy - uncomment and provide details if using a proxy
#export https_proxy=http://<proxyuser>:<proxypassword>@<proxyip>:<proxyport>

# Cloudflare zone is the zone which holds the record
zone=DOMAIN.COM
# dnsrecord is the A record which will be updated
dnsrecord=SUB.DOMAIN.COM

## Cloudflare authentication details
## keep these private
cloudflare_auth_email=YOUR@mail.com
cloudflare_auth_key=PAI-Token


# Get the current external IP address
ip=$(curl -s -X GET https://checkip.amazonaws.com)

echo "Current IP is $ip"

zoneid=$(curl -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone&status=active" \
     -H "Authorization: Bearer $cloudflare_auth_key" \
     -H "Content-Type:application/json" | jq -r '{"result"}[] | .[0] | .id')

echo "Zoneid for $zone is $zoneid"

dnsrecordid=$(curl -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$dnsrecord" \
     -H "Authorization: Bearer $cloudflare_auth_key" \
     -H "Content-Type:application/json" | jq -r '{"result"}[] | .[0] | .id')

echo "DNSrecordid for $dnsrecord is $dnsrecordid"

curl -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dnsrecordid" \
     -H "Authorization: Bearer $cloudflare_auth_key" \
     -H "Content-Type:application/json" \
  --data "{\"type\":\"A\",\"name\":\"$dnsrecord\",\"content\":\"$ip\",\"ttl\":1,\"proxied\":false}" | jq
  
