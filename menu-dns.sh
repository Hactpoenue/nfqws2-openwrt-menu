#!/bin/sh

set -u

HDP_CONFIG="/etc/config/https-dns-proxy"
STUBBY_CONFIG="/etc/config/stubby"

DNS_BACKUP="/etc/nfqws2/backup/dns"

mkdir -p "$DNS_BACKUP"

pause()
{
    echo
    printf "Нажмите Enter..."
    read -r _
}

install_doh()
{
    echo
    echo "=============================================="
    echo " Установка DoH"
    echo "=============================================="
    echo

    echo "Устанавливаем https-dns-proxy..."

    apk update
    apk add https-dns-proxy

    echo
    echo "Пакет установлен."

    pause
}

install_dot()
{
    echo
    echo "=============================================="
    echo " Установка DoT"
    echo "=============================================="
    echo

    echo "Устанавливаем stubby..."

    apk update
    apk add stubby

    echo
    echo "Пакет установлен."

    pause
}

remove_doh()
{
    echo
    printf "Удалить https-dns-proxy? [y/N]: "
    read -r answer

    case "$answer" in
        y|Y|д|Д)
            service https-dns-proxy stop 2>/dev/null || true
            apk del https-dns-proxy
            ;;
    esac

    pause
}

remove_dot()
{
    echo
    printf "Удалить stubby? [y/N]: "
    read -r answer

    case "$answer" in
        y|Y|д|Д)
            service stubby stop 2>/dev/null || true
            apk del stubby
            ;;
    esac

    pause
}

doh_config()
{
    echo
    echo "=============================================="
    echo " DoH"
    echo "=============================================="
    echo
    echo "1) Cloudflare"
    echo "2) Google"
    echo "3) Quad9"
    echo "4) AdGuard"
    echo "5) Ввести URL"
    echo "0) Назад"
    echo

    printf "Выбор: "
    read -r choice

    case "$choice" in
        1)
            URL="https://cloudflare-dns.com/dns-query"
            ;;
        2)
            URL="https://dns.google/dns-query"
            ;;
        3)
            URL="https://dns.quad9.net/dns-query"
            ;;
        4)
            URL="https://dns.adguard-dns.com/dns-query"
            ;;
        5)
            printf "DoH URL: "
            read -r URL
            ;;
        0)
            return
            ;;
        *)
            return
            ;;
    esac

    if ! apk info -e https-dns-proxy >/dev/null 2>&1; then
        apk update
        apk add https-dns-proxy
    fi

    mkdir -p /etc/config

    cat > "$HDP_CONFIG" <<EOF
config main 'config'
        option force_dns '1'
        option listen_addr '127.0.0.1'
        option listen_port '5053'

config https-dns-proxy 'main'
        option resolver_url '$URL'
        option listen_addr '127.0.0.1'
        option listen_port '5053'
EOF

    /etc/init.d/https-dns-proxy enable
    /etc/init.d/https-dns-proxy restart

    echo
    echo "DoH включён:"
    echo "$URL"

    pause
}

dot_config()
{
    echo
    echo "=============================================="
    echo " DoT"
    echo "=============================================="
    echo
    echo "1) Cloudflare"
    echo "2) Quad9"
    echo "3) AdGuard"
    echo "0) Назад"
    echo

    printf "Выбор: "
    read -r choice

    case "$choice" in
        1)
            IP="1.1.1.1"
            SNI="cloudflare-dns.com"
            ;;
        2)
            IP="9.9.9.9"
            SNI="dns.quad9.net"
            ;;
        3)
            IP="94.140.14.14"
            SNI="dns.adguard-dns.com"
            ;;
        0)
            return
            ;;
        *)
            return
            ;;
    esac

    if ! apk info -e stubby >/dev/null 2>&1; then
        apk update
        apk add stubby
    fi

    mkdir -p /etc/config

    cat > "$STUBBY_CONFIG" <<EOF
config stubby 'global'
        option manual '0'
        option tls_authentication '1'
        option round_robin_upstreams '1'
        list listen_address '127.0.0.1@5453'

config resolver
        option address '$IP'
        option tls_auth_name '$SNI'
        option tls_port '853'
EOF

    /etc/init.d/stubby enable
    /etc/init.d/stubby restart

    echo
    echo "DoT включён:"
    echo "$IP"
    echo "SNI: $SNI"

    pause
}

dns_status()
{
    echo
    echo "=============================================="
    echo " DNS STATUS"
    echo "=============================================="
    echo

    echo "https-dns-proxy:"
    if apk info -e https-dns-proxy >/dev/null 2>&1; then
        service https-dns-proxy status 2>/dev/null || true
    else
        echo "не установлен"
    fi

    echo
    echo "stubby:"
    if apk info -e stubby >/dev/null 2>&1; then
        service stubby status 2>/dev/null || true
    else
        echo "не установлен"
    fi

    echo
    echo "DNS listeners:"
    netstat -lnptu 2>/dev/null |
        grep -E ':53 |:5053 |:5453 ' ||
        true

    pause
}

main()
{
    while true; do
        clear 2>/dev/null || true

        echo
        echo "╔══════════════════════════════════════════════╗"
        echo "║                 DNS MENU                     ║"
        echo "╚══════════════════════════════════════════════╝"
        echo
        echo " 1) Установить / настроить DoH"
        echo " 2) Установить / настроить DoT"
        echo " 3) Удалить DoH"
        echo " 4) Удалить DoT"
        echo " 5) DNS статус"
        echo
        echo " 0) Назад"
        echo

        printf "Выбор: "
        read -r choice

        case "$choice" in
            1) doh_config ;;
            2) dot_config ;;
            3) remove_doh ;;
            4) remove_dot ;;
            5) dns_status ;;
            0) return ;;
        esac
    done
}

main
