#!/bin/bash

# A bash script to update a Cloudflare DNS A record with the external IP of the source machine
# Used to provide DDNS service for my home
# Needs the DNS record pre-creating on Cloudflare
# Proxy - uncomment and provide details if using a proxy
#export https_proxy=http://<proxyuser>:<proxypassword>@<proxyip>:<proxyport>

# Cloudflare zone is the zone which holds the record
zone=DOMAIN.COM
# dnsrecord is the A record which will be updated
dnsrecord=SUB.DOMAIN.COM

## Cloudflare authentication details
## keep these private
cloudflare_auth_email=YOUR@MAIL.com
api_key=YOUR-API-Token

needed_progs=(host jq)

## check if all commands are installed
for prog in ${needed_progs[@]}; do
  if ! command -v $prog &> /dev/null; then
    echo "$prog could not be found, please install it"
    exit 1
  fi
done

# Get the current external IP address
ip=$(curl -s -X GET https://checkip.amazonaws.com)
ip_from_dns=$(host $dnsrecord | awk '{print $NF}')

if [ $ip == $ip_from_dns ]; then
  echo "IP on DNS Server is already up to date, IP: $ip"
  exit 0
else
  echo "Actual IP on DNS-Server for $dnsrecord is $ip_from_dns new ip is $ip"
fi

zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone&s                                                                                                                                                             tatus=active" \
     -H "Authorization: Bearer $api_key" \
     -H "Content-Type:application/json" | jq -r '{"result"}[] | .[0] | .id')

echo "Zoneid for $zone is $zoneid"

dnsrecordid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid                                                                                                                                                             /dns_records?type=A&name=$dnsrecord" \
     -H "Authorization: Bearer $api_key" \
     -H "Content-Type:application/json" | jq -r '{"result"}[] | .[0] | .id')

echo "DNSrecordid for $dnsrecord is $dnsrecordid"

ip_cloudflare=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone                                                                                                                                                             id/dns_records?type=A&name=$dnsrecord" \
     -H "Authorization: Bearer $api_key" \
     -H "Content-Type:application/json" | jq -r '{"result"}[] | .[0] | .content'                                                                                                                                                             )

if [ $ip == $ip_cloudflare ]; then
  echo "IP is already up to date IP: $ip"
  exit 0
else
  echo "Actual IP on Cloudflare for $dnsrecord is $ip_cloudflare new ip is $ip"
fi

# update DNS record
curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$                                                                                                                                                             dnsrecordid" \
     -H "Authorization: Bearer $api_key" \
     -H "Content-Type:application/json" \
  --data "{\"type\":\"A\",\"name\":\"$dnsrecord\",\"content\":\"$ip\",\"ttl\":1,                                                                                                                                                             \"proxied\":false}" | jq

exit 0
