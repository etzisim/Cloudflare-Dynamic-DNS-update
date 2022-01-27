#!/bin/bash

# A bash script to update a Cloudflare DNS A record with the external IP of the source machine
# Used to provide DDNS service for my home
# Needs the DNS record pre-creating on Cloudflare
# Proxy - uncomment and provide details if using a proxy
#export https_proxy=http://<proxyuser>:<proxypassword>@<proxyip>:<proxyport>

# Cloudflare zone is the zone which holds the record
zone=DOMAIN.COM
# group of records to update is the A record which will be updated
dnsrecords=(home wiki public nas)

## Cloudflare authentication details
## keep these private
cloudflare_auth_email=YOUR@MAIL.com
api_key=YOUR-API-Token
proxied=true

needed_progs=(host jq)

## check if all commands are installed
for prog in ${needed_progs[@]}; do
    if ! command -v $prog &>/dev/null; then
        echo "$prog could not be found, please install it"
        exit 1
    fi
done

ip=$(curl -s -X GET https://checkip.amazonaws.com)

for dnsrecord in ${dnsrecords[@]}; do
    dnsrecord=$dnsrecord.$zone

    skip=false

    echo "start with $dnsrecord"
    if ! $proxied; then
        # Get the current external IP address
        ip_from_dns=$(host -4 $dnsrecord 1.1.1.1 | awk '{print $NF}' | tail -n 1)

        if [ $ip == $ip_from_dns ]; then
            echo "IP on DNS Server is already up to date, IP: $ip"
            skip=true
        else
            echo "Actual IP on DNS-Server for $dnsrecord is $ip_from_dns new ip is $ip"
        fi
    fi
    zoneid=$(
        curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone&status=active" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type:application/json" | jq -r '{"result"}[] | .[0] | .id'
    )

    echo "Zoneid for $zone is $zoneid"

    dnsrecordid=$(
        curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$dnsrecord" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type:application/json" | jq -r '{"result"}[] | .[0] | .id'
    )

    echo "DNSrecordid for $dnsrecord is $dnsrecordid"

    ip_cloudflare=$(
        curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$dnsrecord" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type:application/json" | jq -r '{"result"}[] | .[0] | .content'
    )

    echo "Cloudflare: $ip_cloudflare"
    echo "actual ip : $ip"

    if [ $ip == $ip_cloudflare ]; then
        echo "IP is already up to date IP: $ip"
        skip=true
    else
        echo "Actual IP on Cloudflare for $dnsrecord is $ip_cloudflare new ip is $ip"
    fi

    if ! $skip; then
        # update DNS record
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dnsrecordid" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type:application/json" \
        --data "{\"type\":\"A\",\"name\":\"$dnsrecord\",\"content\":\"$ip\",\"ttl\":1,\"proxied\":$proxied}" | jq
    fi
done
exit 0
