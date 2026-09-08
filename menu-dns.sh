#!/bin/sh

# =============================================================================
# NFQWS2 OpenWrt Menu
# DNS manager: DoH / DoT
#
# Использует официальный пакет OpenWrt dnsproxy.
# dnsproxy поддерживает DoH, DoT, DoQ и DNSCrypt.
# =============================================================================

DNSPKG="dnsproxy"
DNSCFG="/etc/config/dnsproxy"
DHCP_CFG="/etc/config/dhcp"

DNS_LIST="/etc/nfqws2/dns-upstreams.conf"

DNSPROXY_ADDR="127.0.0.1"
DNSPROXY_PORT="5353"

GREEN="$(printf '\033[32m')"
RED="$(printf '\033[31m')"
YELLOW="$(printf '\033[33m')"
CYAN="$(printf '\033[36m')"
BOLD="$(printf '\033[1m')"
RESET="$(printf '\033[0m')"

msg()
{
    printf "%s\n" "$1"
}

ok()
{
    printf "%s[ OK ]%s %s\n" "$GREEN" "$RESET" "$1"
}

warn()
{
    printf "%s[WARN]%s %s\n" "$YELLOW" "$RESET" "$1"
}

error()
{
    printf "%s[ERROR]%s %s\n" "$RED" "$RESET" "$1"
}

pause()
{
    echo
    printf "Нажмите Enter..."
    read -r _
}

header()
{
    clear 2>/dev/null || true

    echo
    printf "%s╔══════════════════════════════════════════════════╗%s\n" \
        "$CYAN" "$RESET"

    printf "%s║%s                 DNS MANAGER                   %s║%s\n" \
        "$CYAN" "$BOLD" "$CYAN" "$RESET"

    printf "%s║%s                    DoH / DoT                  %s║%s\n" \
        "$CYAN" "$BOLD" "$CYAN" "$RESET"

    printf "%s╚══════════════════════════════════════════════════╝%s\n" \
        "$CYAN" "$RESET"

    echo
}

is_installed()
{
    apk info -e "$DNSPKG" >/dev/null 2>&1
}

install_dnsproxy()
{
    header

    echo "=============================================="
    echo " Установка DNS Proxy"
    echo "=============================================="
    echo

    if is_installed; then
        warn "dnsproxy уже установлен."
        pause
        return
    fi

    echo "Устанавливаем официальный пакет OpenWrt:"
    echo
    echo "  dnsproxy"
    echo

    apk update || {
        error "apk update завершился ошибкой."
        pause
        return
    }

    apk add "$DNSPKG" || {
        error "Не удалось установить dnsproxy."
        pause
        return
    }

    ok "dnsproxy установлен."

    setup_default_config

    pause
}

remove_dnsproxy()
{
    header

    echo "=============================================="
    echo " Удаление DNS Proxy"
    echo "=============================================="
    echo

    if ! is_installed; then
        warn "dnsproxy не установлен."
        pause
        return
    fi

    printf "Удалить dnsproxy? [y/N]: "
    read -r answer

    case "$answer" in
        y|Y|д|Д)
            ;;
        *)
            return
            ;;
    esac

    /etc/init.d/dnsproxy stop >/dev/null 2>&1 || true
    /etc/init.d/dnsproxy disable >/dev/null 2>&1 || true

    apk del "$DNSPKG"

    ok "dnsproxy удалён."

    pause
}

setup_default_config()
{
    mkdir -p /etc/nfqws2

    cat > "$DNSCFG" <<'EOF'
config global 'global'
    option enabled '1'
    option listen_addr '127.0.0.1'
    option listen_port '5353'
    option cache '1'
    option cache_size '4194304'
    option upstream_mode 'parallel'
    option dnssec '1'
    option timeout '5s'

config upstreams 'upstreams'
    list upstream 'https://cloudflare-dns.com/dns-query'
    list upstream 'https://dns.google/dns-query'
    list upstream 'tls://1dot1dot1dot1.cloudflare-dns.com'
    list upstream 'tls://dns.google'
EOF

    uci -q delete dhcp.@dnsmasq[0].noresolv
    uci -q set dhcp.@dnsmasq[0].noresolv='1'

    uci -q delete dhcp.@dnsmasq[0].server

    uci add_list dhcp.@dnsmasq[0].server="127.0.0.1#5353"

    uci commit dhcp

    cat > "$DNS_LIST" <<'EOF'
# DoH
https://cloudflare-dns.com/dns-query
https://dns.google/dns-query

# DoT
tls://1dot1dot1dot1.cloudflare-dns.com
tls://dns.google
EOF

    /etc/init.d/dnsproxy enable >/dev/null 2>&1 || true
    /etc/init.d/dnsproxy restart >/dev/null 2>&1 || true

    /etc/init.d/dnsmasq restart >/dev/null 2>&1 || true

    ok "Базовая DNS-конфигурация создана."
}

configure_dnsproxy()
{
    local mode="$1"

    mkdir -p /etc/nfqws2

    cat > "$DNSCFG" <<EOF
config global 'global'
    option enabled '1'
    option listen_addr '127.0.0.1'
    option listen_port '$DNSPROXY_PORT'
    option cache '1'
    option cache_size '4194304'
    option upstream_mode '$mode'
    option dnssec '1'
    option timeout '5s'

config upstreams 'upstreams'
EOF

    while IFS= read -r upstream; do
        case "$upstream" in
            ""|\#*)
                continue
                ;;
        esac

        printf "    list upstream '%s'\n" "$upstream" >> "$DNSCFG"
    done < "$DNS_LIST"

    uci -q delete dhcp.@dnsmasq[0].noresolv
    uci -q set dhcp.@dnsmasq[0].noresolv='1'

    uci -q delete dhcp.@dnsmasq[0].server
    uci add_list dhcp.@dnsmasq[0].server="127.0.0.1#$DNSPROXY_PORT"

    uci commit dhcp

    /etc/init.d/dnsproxy enable >/dev/null 2>&1 || true
    /etc/init.d/dnsproxy restart

    /etc/init.d/dnsmasq restart

    ok "DNS настроен."
}

show_upstreams()
{
    echo
    echo "Текущие upstream DNS:"
    echo

    if [ -f "$DNS_LIST" ]; then
        grep -vE '^[[:space:]]*(#|$)' "$DNS_LIST" |
            nl -ba
    else
        echo "Список отсутствует."
    fi

    echo
}

add_upstream()
{
    header

    echo "=============================================="
    echo " Добавить DNS"
    echo "=============================================="
    echo

    echo "Примеры:"
    echo
    echo "DoH:"
    echo "  https://cloudflare-dns.com/dns-query"
    echo "  https://dns.google/dns-query"
    echo
    echo "DoT:"
    echo "  tls://1dot1dot1dot1.cloudflare-dns.com"
    echo "  tls://dns.google"
    echo

    printf "Введите upstream: "
    read -r upstream

    [ -z "$upstream" ] && return

    case "$upstream" in
        https://*|tls://*)
            ;;
        *)
            error "Разрешены только https:// и tls://"
            pause
            return
            ;;
    esac

    if grep -Fxq "$upstream" "$DNS_LIST" 2>/dev/null; then
        warn "Такой upstream уже есть."
        pause
        return
    fi

    printf '%s\n' "$upstream" >> "$DNS_LIST"

    ok "Upstream добавлен."

    pause
}

remove_upstream()
{
    header

    echo "=============================================="
    echo " Удалить DNS"
    echo "=============================================="
    echo

    if [ ! -f "$DNS_LIST" ]; then
        warn "Список пуст."
        pause
        return
    fi

    grep -vE '^[[:space:]]*(#|$)' "$DNS_LIST" |
        nl -ba

    echo
    printf "Номер для удаления: "
    read -r num

    [ -z "$num" ] && return

    tmp="/tmp/dns-upstreams.$$.tmp"

    awk -v n="$num" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ {
        print
        next
    }
    {
        count++
        if (count != n)
            print
    }
    ' "$DNS_LIST" > "$tmp"

    mv "$tmp" "$DNS_LIST"

    ok "Upstream удалён."

    pause
}

select_mode()
{
    header

    echo "=============================================="
    echo " Режим работы upstream"
    echo "=============================================="
    echo

    echo "1) parallel"
    echo "   Запрос отправляется нескольким DNS."
    echo
    echo "2) load_balance"
    echo "   Балансировка между DNS."
    echo
    echo "3) fastest_addr"
    echo "   Использование самого быстрого ответа."
    echo

    printf "Выбор [1-3]: "
    read -r choice

    case "$choice" in
        1)
            configure_dnsproxy "parallel"
            ;;
        2)
            configure_dnsproxy "load_balance"
            ;;
        3)
            configure_dnsproxy "fastest_addr"
            ;;
        *)
            warn "Неверный выбор."
            ;;
    esac

    pause
}

force_dns()
{
    header

    echo "=============================================="
    echo " Принудительный DNS для клиентов"
    echo "=============================================="
    echo

    echo "Будет включён принудительный DNS:"
    echo
    echo "LAN → router:53"
    echo "LAN → внешний DNS:53  → router"
    echo "LAN → внешний DNS:853 → router"
    echo

    printf "Включить? [Y/n]: "
    read -r answer

    case "$answer" in
        n|N|н|Н)
            return
            ;;
    esac

    # UCI firewall4 redirect.
    #
    # Все DNS-запросы клиентов по UDP/TCP 53
    # перенаправляются на dnsmasq роутера.
    #

    uci -q delete firewall.nfqws2_dns_redirect
    uci set firewall.nfqws2_dns_redirect='redirect'
    uci set firewall.nfqws2_dns_redirect.name='NFQWS2 Force DNS'
    uci set firewall.nfqws2_dns_redirect.src='lan'
    uci set firewall.nfqws2_dns_redirect.src_dport='53'
    uci set firewall.nfqws2_dns_redirect.proto='tcp udp'
    uci set firewall.nfqws2_dns_redirect.family='any'
    uci set firewall.nfqws2_dns_redirect.target='DNAT'
    uci set firewall.nfqws2_dns_redirect.dest_port='53'
    uci set firewall.nfqws2_dns_redirect.reflection='0'

    # DoT невозможно DNAT-ить на обычный DNS без
    # дополнительного TLS-сервера. Поэтому 853 блокируем.
    #
    # Клиенты должны использовать DNS роутера.

    uci -q delete firewall.nfqws2_dot_block
    uci set firewall.nfqws2_dot_block='rule'
    uci set firewall.nfqws2_dot_block.name='NFQWS2 Block external DoT'
    uci set firewall.nfqws2_dot_block.src='lan'
    uci set firewall.nfqws2_dot_block.dest='wan'
    uci set firewall.nfqws2_dot_block.dest_port='853'
    uci set firewall.nfqws2_dot_block.proto='tcp udp'
    uci set firewall.nfqws2_dot_block.target='REJECT'

    uci commit firewall

    /etc/init.d/firewall reload

    ok "Принудительный DNS включён."

    pause
}

disable_force_dns()
{
    header

    echo "=============================================="
    echo " Отключение принудительного DNS"
    echo "=============================================="
    echo

    uci -q delete firewall.nfqws2_dns_redirect
    uci -q delete firewall.nfqws2_dot_block

    uci commit firewall

    /etc/init.d/firewall reload

    ok "Принудительный DNS отключён."

    pause
}

show_status()
{
    header

    echo "=============================================="
    echo " DNS статус"
    echo "=============================================="
    echo

    if is_installed; then
        echo "dnsproxy: установлен"
    else
        echo "dnsproxy: НЕ установлен"
        pause
        return
    fi

    echo
    echo "dnsproxy:"
    /etc/init.d/dnsproxy status 2>/dev/null || true

    echo
    echo "dnsmasq:"
    /etc/init.d/dnsmasq status 2>/dev/null || true

    echo
    echo "DNS listener:"
    netstat -ln 2>/dev/null |
        grep ":$DNSPROXY_PORT " ||
        ss -ln 2>/dev/null |
        grep ":$DNSPROXY_PORT " ||
        echo "listener не найден"

    echo
    echo "Upstreams:"
    show_upstreams

    echo "dnsmasq upstream:"
    uci show dhcp 2>/dev/null |
        grep -E 'noresolv|server' |
        head -20

    echo
    echo "Firewall DNS rules:"
    uci show firewall 2>/dev/null |
        grep -E 'nfqws2_(dns_redirect|dot_block)' ||
        echo "не настроены"

    pause
}

test_dns()
{
    header

    echo "=============================================="
    echo " Проверка DNS"
    echo "=============================================="
    echo

    echo "1. Проверяем локальный dnsproxy..."
    echo

    if command -v nslookup >/dev/null 2>&1; then
        nslookup example.com 127.0.0.1#$DNSPROXY_PORT
    elif command -v drill >/dev/null 2>&1; then
        drill @127.0.0.1 -p "$DNSPROXY_PORT" example.com
    else
        warn "nslookup/drill отсутствует."
    fi

    echo
    echo "2. Проверяем процесс..."

    if pgrep dnsproxy >/dev/null 2>&1; then
        ok "dnsproxy работает."
    else
        error "dnsproxy НЕ работает."
    fi

    echo
    echo "3. Последние DNS-сообщения..."

    logread 2>/dev/null |
        grep -i dnsproxy |
        tail -20

    pause
}

main()
{
    while true; do
        header

        if is_installed; then
            printf "%sdnsproxy:%s %sустановлен%s\n" \
                "$BOLD" "$RESET" "$GREEN" "$RESET"
        else
            printf "%sdnsproxy:%s %sне установлен%s\n" \
                "$BOLD" "$RESET" "$RED" "$RESET"
        fi

        echo

        show_upstreams

        echo
        echo "1) Установить dnsproxy"
        echo "2) Удалить dnsproxy"
        echo
        echo "3) Добавить DoH / DoT"
        echo "4) Удалить DoH / DoT"
        echo "5) Режим upstream"
        echo
        echo "6) Включить принудительный DNS"
        echo "7) Отключить принудительный DNS"
        echo
        echo "8) Статус"
        echo "9) Проверить DNS"
        echo
        echo "0) Назад"
        echo

        printf "Выбор: "
        read -r choice

        case "$choice" in
            1)
                install_dnsproxy
                ;;
            2)
                remove_dnsproxy
                ;;
            3)
                add_upstream
                ;;
            4)
                remove_upstream
                ;;
            5)
                select_mode
                ;;
            6)
                force_dns
                ;;
            7)
                disable_force_dns
                ;;
            8)
                show_status
                ;;
            9)
                test_dns
                ;;
            0|"")
                exit 0
                ;;
            *)
                warn "Неверный выбор."
                sleep 1
                ;;
        esac
    done
}

main
