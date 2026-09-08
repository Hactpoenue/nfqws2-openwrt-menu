#!/bin/sh

VERSION="1.0.0-openwrt"

REPO="https://raw.githubusercontent.com/Hactpoenue/nfqws2-openwrt-menu/main"
STRATEGIES_DIR="$REPO/strategies"

NFQWS_PACKAGE="nfqws2-keenetic"
NFQWS_SERVICE="nfqws2-keenetic"

NFQWS_CONFIG="/etc/nfqws2/nfqws2.conf"
NFQWS_DIR="/etc/nfqws2"

LOCAL_STRATEGIES="/etc/nfqws2/strategies"
LOCAL_BLOBS="/etc/nfqws2/blobs"
LOCAL_LISTS="/etc/nfqws2/lists"
BACKUP_DIR="/etc/nfqws2/backup"

C_RESET="$(printf '\033[0m')"
C_RED="$(printf '\033[31m')"
C_GREEN="$(printf '\033[32m')"
C_YELLOW="$(printf '\033[33m')"
C_BLUE="$(printf '\033[34m')"
C_CYAN="$(printf '\033[36m')"
C_BOLD="$(printf '\033[1m')"

mkdir -p "$LOCAL_STRATEGIES"
mkdir -p "$LOCAL_BLOBS"
mkdir -p "$LOCAL_LISTS"
mkdir -p "$BACKUP_DIR"

pause()
{
    echo
    printf "Нажмите Enter..."
    read -r _
}

is_installed()
{
    apk info -e "$NFQWS_PACKAGE" >/dev/null 2>&1
}

service_status()
{
    if [ -x "/etc/init.d/$NFQWS_SERVICE" ]; then
        service "$NFQWS_SERVICE" status >/dev/null 2>&1
        return $?
    fi

    return 1
}

get_version()
{
    apk info "$NFQWS_PACKAGE" 2>/dev/null |
        sed -n 's/^Installed-Version: //p' |
        head -n1
}

detect_wan_interface()
{
    ip route show default 2>/dev/null |
        awk '
        /^default/ {
            for (i=1;i<=NF;i++)
                if ($i=="dev") {
                    print $(i+1)
                    exit
                }
        }'
}

header()
{
    clear 2>/dev/null || true

    echo
    printf "%s╔══════════════════════════════════════════════╗%s\n" \
        "$C_CYAN" "$C_RESET"

    printf "%s║%s          NFQWS2 OPENWRT MENU          %s║%s\n" \
        "$C_CYAN" "$C_BOLD" "$C_CYAN" "$C_RESET"

    printf "%s║%s              version %-10s           %s║%s\n" \
        "$C_CYAN" "$C_YELLOW" "$VERSION" "$C_CYAN" "$C_RESET"

    printf "%s╚══════════════════════════════════════════════╝%s\n" \
        "$C_CYAN" "$C_RESET"

    echo
}

show_status()
{
    printf "%sNFQWS2:%s " "$C_BOLD" "$C_RESET"

    if is_installed; then
        printf "%sinstalled%s" "$C_GREEN" "$C_RESET"

        VERSION_INSTALLED="$(get_version)"

        [ -n "$VERSION_INSTALLED" ] &&
            printf " (%s)" "$VERSION_INSTALLED"

        if service_status; then
            printf " %s● RUNNING%s" "$C_GREEN" "$C_RESET"
        else
            printf " %s● STOPPED%s" "$C_RED" "$C_RESET"
        fi
    else
        printf "%snot installed%s" "$C_RED" "$C_RESET"
    fi

    echo

    WAN="$(detect_wan_interface)"

    printf "%sWAN interface:%s %s\n" \
        "$C_BOLD" "$C_RESET" "${WAN:-unknown}"

    echo
}

install_nfqws2()
{
    echo
    echo "=============================================="
    echo " Установка NFQWS2"
    echo "=============================================="
    echo

    if is_installed; then
        echo "NFQWS2 уже установлен."
        pause
        return
    fi

    echo "Добавляем официальный репозиторий NFQWS2..."
    echo

    apk --update-cache add ca-certificates wget-ssl

    mkdir -p /etc/apk/keys
    mkdir -p /etc/apk/repositories.d

    wget -O \
        "/etc/apk/keys/nfqws2-keenetic.pem" \
        "https://nfqws.github.io/nfqws2-keenetic/openwrt/nfqws2-keenetic.pem"

    echo \
        "https://nfqws.github.io/nfqws2-keenetic/openwrt/packages.adb" \
        > /etc/apk/repositories.d/nfqws2-keenetic.list

    echo
    echo "Обновление списка пакетов..."

    apk update

    echo
    echo "Установка $NFQWS_PACKAGE..."

    apk add "$NFQWS_PACKAGE"

    if [ -x "/etc/init.d/$NFQWS_SERVICE" ]; then
        service "$NFQWS_SERVICE" enable
    fi

    echo
    printf "%sNFQWS2 установлен.%s\n" \
        "$C_GREEN" "$C_RESET"

    pause
}

remove_nfqws2()
{
    echo
    echo "=============================================="
    echo " Удаление NFQWS2"
    echo "=============================================="
    echo

    if ! is_installed; then
        echo "NFQWS2 не установлен."
        pause
        return
    fi

    printf "%sУдалить NFQWS2? [y/N]: %s" "$C_YELLOW" "$C_RESET"
    read -r answer

    case "$answer" in
        y|Y|д|Д)
            ;;
        *)
            return
            ;;
    esac

    if [ -x "/etc/init.d/$NFQWS_SERVICE" ]; then
        service "$NFQWS_SERVICE" stop 2>/dev/null || true
        service "$NFQWS_SERVICE" disable 2>/dev/null || true
    fi

    apk del "$NFQWS_PACKAGE"

    echo
    echo "NFQWS2 удалён."

    pause
}

start_nfqws2()
{
    if ! is_installed; then
        echo
        echo "NFQWS2 не установлен."
        pause
        return
    fi

    service "$NFQWS_SERVICE" start

    echo
    echo "NFQWS2 запущен."

    pause
}

stop_nfqws2()
{
    if ! is_installed; then
        echo
        echo "NFQWS2 не установлен."
        pause
        return
    fi

    service "$NFQWS_SERVICE" stop

    echo
    echo "NFQWS2 остановлен."

    pause
}

restart_nfqws2()
{
    if ! is_installed; then
        echo
        echo "NFQWS2 не установлен."
        pause
        return
    fi

    service "$NFQWS_SERVICE" restart

    echo
    echo "NFQWS2 перезапущен."

    pause
}

update_nfqws2()
{
    echo
    echo "Обновление NFQWS2..."
    echo

    apk update
    apk upgrade "$NFQWS_PACKAGE"

    echo
    echo "Готово."

    pause
}

status_nfqws2()
{
    echo
    echo "=============================================="
    echo " Статус NFQWS2"
    echo "=============================================="
    echo

    if is_installed; then
        echo "Пакет: установлен"
        echo "Версия: $(get_version)"
    else
        echo "Пакет: НЕ установлен"
    fi

    echo

    if [ -x "/etc/init.d/$NFQWS_SERVICE" ]; then
        service "$NFQWS_SERVICE" status || true
    else
        echo "Init script отсутствует."
    fi

    echo

    echo "Конфигурация:"
    [ -f "$NFQWS_CONFIG" ] &&
        echo "$NFQWS_CONFIG" ||
        echo "не найдена"

    pause
}

strategies_menu()
{
    echo
    echo "=============================================="
    echo " Стратегии NFQWS2"
    echo "=============================================="
    echo
    echo "Эта часть будет подключена следующим шагом."
    echo
    echo "Источник:"
    echo "$STRATEGIES_DIR/nfqws2/"
    echo

    pause
}

dns_menu()
{
    if [ -f "$(dirname "$0")/menu-dns.sh" ]; then
        sh "$(dirname "$0")/menu-dns.sh"
    else
        sh /usr/lib/nfqws2-openwrt-menu/menu-dns.sh
    fi
}

diagnostics()
{
    echo
    echo "=============================================="
    echo " Диагностика"
    echo "=============================================="
    echo

    . /etc/openwrt_release

    echo "OpenWrt:"
    echo "$DISTRIB_DESCRIPTION"

    echo
    echo "Kernel:"
    uname -a

    echo
    echo "Architecture:"
    uname -m

    echo
    echo "WAN interface:"
    detect_wan_interface

    echo
    echo "NFQWS2:"
    is_installed &&
        echo "installed $(get_version)" ||
        echo "not installed"

    echo
    echo "Memory:"
    free

    echo
    echo "Disk:"
    df -h

    pause
}

main_menu()
{
    while true; do
        header
        show_status

        echo " [ NFQWS2 ]"
        echo
        echo " 1) Установить NFQWS2"
        echo " 2) Удалить NFQWS2"
        echo " 3) Обновить NFQWS2"
        echo " 4) Запустить"
        echo " 5) Остановить"
        echo " 6) Перезапустить"
        echo " 7) Статус"
        echo
        echo " [ СТРАТЕГИИ ]"
        echo
        echo "10) Выбор стратегии"
        echo "11) Обновить стратегии"
        echo "12) Обновить blobs"
        echo "13) Обновить lists"
        echo
        echo " [ DNS ]"
        echo
        echo "20) DoH / DoT"
        echo
        echo " [ СИСТЕМА ]"
        echo
        echo "30) Диагностика"
        echo
        echo " 0) Выход"
        echo

        printf "Выбор: "
        read -r choice

        case "$choice" in
            1) install_nfqws2 ;;
            2) remove_nfqws2 ;;
            3) update_nfqws2 ;;
            4) start_nfqws2 ;;
            5) stop_nfqws2 ;;
            6) restart_nfqws2 ;;
            7) status_nfqws2 ;;
            10) strategies_menu ;;
            20) dns_menu ;;
            30) diagnostics ;;
            0) exit 0 ;;
            *) ;;
        esac
    done
}

main_menu
