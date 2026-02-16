#!/bin/bash

DEFAULT_PORT=443
CACHE="/tmp/rdns.cache"
touch "$CACHE"

# ----

PORT=$1

printf "%-5s %-15s %-35s\n" "CNT" "IP" "HOSTNAME/ISP"

if [ -z "$PORT" ]; then
        PORT="$DEFAULT_PORT"
fi

# list active connections
ss -tn state established "sport = :$PORT" \
| tail -n +2 \
| awk '{print $NF}' \
| sed 's/:.*$//' \
| sort | uniq -c | sort -nr \
| while read count ip; do
    [ -z "$ip" ] && continue

    # check for cache
    host=$(grep "^$ip " "$CACHE" | awk '{print $2}')

    if [ -z "$host" ] || [ "$host" = "no-rdns" ]; then
        # PTR lookup
        host=$(getent hosts "$ip" | awk '{print $2}')

        if [ -z "$host" ]; then
            # fallback: whois
            host=$(whois "$ip" 2>/dev/null \
                | grep -Ei 'OrgName|org-name|descr|netname' \
                | head -n1 \
                | awk -F: '{print $2}' \
                | sed 's/^ *//;s/ *$//')
        fi

        host=${host:-no-rdns}

        # save to cache
        echo "$ip $host" >> "$CACHE"
    fi

    printf "%-5s %-15s %-35s\n" "$count" "$ip" "$host"
done
