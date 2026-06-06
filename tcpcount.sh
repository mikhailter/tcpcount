#!/bin/sh

DEFAULT_PORT=443
CACHE="/tmp/rdns.cache"
touch "$CACHE"

PORT=$1
[ -z "$PORT" ] && PORT="$DEFAULT_PORT"

printf "%-5s %-15s %-35s\n" "CNT" "IP" "HOSTNAME/ISP"

OS=$(uname)

if [ "$OS" = "FreeBSD" ]; then
    MY_IP=$(ifconfig | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}')
    CONNS=$(netstat -an -f inet | grep ESTABLISHED | grep "$MY_IP.$PORT " | awk '{print $5}' | sed 's/\.[0-9]*$//')
else
    CONNS=$(ss -tn state established "sport = :$PORT" | tail -n +2 \
        | awk '{print $NF}' \
        | sed -E 's/^\[//;s/\]$//' \
        | sed 's/:.*//')
fi

echo "$CONNS" | sort | uniq -c | sort -nr | while read count ip; do
    [ -z "$ip" ] && continue

    # кеш lookup (без regex)
    host=$(awk -v ip="$ip" '$1 == ip {print $2}' "$CACHE")

    if [ -z "$host" ] || [ "$host" = "no-rdns" ]; then

        # rDNS
        host=$(getent hosts "$ip" 2>/dev/null | awk '{print $2}')

        # фильтр мусорных PTR (in-addr.arpa)
        case "$host" in
            *in-addr.arpa*|*ip6.arpa*)
                host=""
                ;;
        esac

        # fallback: whois
        if [ -z "$host" ]; then
            host=$(whois "$ip" 2>/dev/null \
                | grep -Ei 'OrgName|org-name|descr|netname' \
                | head -n1 \
                | awk -F: '{print $2}' \
                | sed 's/^ *//;s/ *$//')
        fi

        host=${host:-no-rdns}

        # кешируем только валидные значения
        echo "$ip $host" >> "$CACHE"
    fi

    printf "%-5s %-15s %-35s\n" "$count" "$ip" "$host"
done
