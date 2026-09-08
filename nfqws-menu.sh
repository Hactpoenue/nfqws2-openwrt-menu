#!/bin/sh

VERSION="2.0.0"

RAW="https://raw.githubusercontent.com/Hactpoenue/nfqws2-openwrt-menu/main"
STRATEGIES="$RAW/strategies/nfqws2"
BLOBS="$RAW/strategies/blobs"
LISTS="$RAW/strategies/lists"

PKG="nfqws2-keenetic"
SERVICE="nfqws2-keenetic"

CONF="/etc/nfqws2/nfqws2.conf"
DIR="/etc/nfqws2"

DNS_MENU="/usr/lib/nfqws2-openwrt-menu/menu-dns.sh"

OFFICIAL_REPO="https://nfqws.github.io/nfqws2-keenetic/openwrt/packages.adb"
OFFICIAL_KEY="https://nfqws.github.io/nfqws2-keenetic/openwrt/nfqws2-keenetic.pem"

C="\033[36m"
G="\033[32m"
Y="\033[33m"
R="\033[31m"
B="\033[1m"
N="\033[0m"

msg() {
    printf "%s\n" "$1"
}

pause() {
    echo
    printf "Нажмите Enter..."
    read -r _
}

installed() {
    apk info -e "$PKG" >/dev/null 2>&1
}

running() {
    [ -x "/etc/init.d/$SERVICE" ] || return 1
    service "$SERVICE" running >/dev/null 2>&1
}

version() {
    apk info "$PKG" 2>/dev/null |
        sed -n 's/^Installed-Version: //p' |
        head -n1
}

wan() {
    ip route 2>/dev/null |
        awk '/^default/ {
            for(i=1;i<=NF;i++)
                if($i=="dev") {
                    print $(i+1)
                    exit
                }
        }'
}

header() {
    clear 2>/dev/null || true

    echo
    printf "${C}╔══════════════════════════════════════════════════╗${N}\n"
    printf "${C}║${B}              NFQWS2 OPENWRT MENU              ${C}║${N}\n"
    printf "${C}║${Y}                  v%-8s                     ${C}║${N}\n" "$VERSION"
    printf "${C}╚══════════════════════════════════════════════════╝${N}\n"
    echo
}

status() {
    printf "${B}NFQWS2:${N} "

    if installed; then
        printf "${G}УСТАНОВЛЕН${N}"

        v="$(version)"
        [ -n "$v" ] && printf " (%s)" "$v"

        if running; then
            printf " ${G}● RUNNING${N}"
        else
            printf " ${R}● STOPPED${N}"
        fi
    else
        printf "${R}НЕ УСТАНОВЛЕН${N}"
    fi

    echo

    printf "${B}WAN:${N} %s\n" "$(wan)"
    echo
}

repo() {
    mkdir -p /etc/apk/keys /etc/apk/repositories.d

    if [ ! -f /etc/apk/keys/nfqws2-keenetic.pem ]; then
        wget -qO \
            /etc/apk/keys/nfqws2-keenetic.pem \
            "$OFFICIAL_KEY" || {
                echo "${R}Не удалось загрузить ключ.${N}"
                return 1
            }
    fi

    printf '%s\n' "$OFFICIAL_REPO" \
        > /etc/apk/repositories.d/nfqws2-keenetic.list
}

install_nfqws2() {
    header

    echo "=============================================="
    echo " Установка NFQWS2"
    echo "=============================================="
    echo

    if installed; then
        echo "${Y}NFQWS2 уже установлен.${N}"
        pause
        return
    fi

    echo "Настройка официального репозитория..."
    repo || {
        pause
        return
    }

    echo
    echo "Обновление списка пакетов..."
    apk update || {
        echo "${R}apk update ошибка.${N}"
        pause
        return
    }

    echo
    echo "Установка NFQWS2..."
    apk add "$PKG" || {
        echo "${R}Не удалось установить NFQWS2.${N}"
        pause
        return
    }

    mkdir -p "$DIR"

    if [ -x "/etc/init.d/$SERVICE" ]; then
        service "$SERVICE" enable >/dev/null 2>&1 || true
    fi

    echo
    echo "${G}NFQWS2 установлен.${N}"
    echo "Версия: $(version)"

    pause
}

remove_nfqws2() {
    header

    echo "=============================================="
    echo " Удаление NFQWS2"
    echo "=============================================="
    echo

    if ! installed; then
        echo "${Y}NFQWS2 не установлен.${N}"
        pause
        return
    fi

    printf "Удалить NFQWS2? [y/N]: "
    read -r a

    case "$a" in
        y|Y|д|Д)
            ;;
        *)
            return
            ;;
    esac

    if [ -x "/etc/init.d/$SERVICE" ]; then
        service "$SERVICE" stop >/dev/null 2>&1 || true
        service "$SERVICE" disable >/dev/null 2>&1 || true
    fi

    apk del "$PKG" || true

    rm -rf "$DIR"

    rm -f /etc/apk/repositories.d/nfqws2-keenetic.list
    rm -f /etc/apk/keys/nfqws2-keenetic.pem

    echo
    echo "${G}NFQWS2 полностью удалён.${N}"

    pause
}

update_nfqws2() {
    header

    if ! installed; then
        echo "${Y}NFQWS2 не установлен.${N}"
        pause
        return
    fi

    repo || {
        pause
        return
    }

    apk update
    apk upgrade "$PKG"

    echo
    echo "${G}Обновление завершено.${N}"

    pause
}

start_nfqws2() {
    if ! installed; then
        echo "${Y}NFQWS2 не установлен.${N}"
        pause
        return
    fi

    service "$SERVICE" start
    pause
}

stop_nfqws2() {
    if ! installed; then
        echo "${Y}NFQWS2 не установлен.${N}"
        pause
        return
    fi

    service "$SERVICE" stop
    pause
}

restart_nfqws2() {
    if ! installed; then
        echo "${Y}NFQWS2 не установлен.${N}"
        pause
        return
    fi

    service "$SERVICE" restart
    pause
}

status_nfqws2() {
    header

    echo "=============================================="
    echo " Статус NFQWS2"
    echo "=============================================="
    echo

    status

    if [ -x "/etc/init.d/$SERVICE" ]; then
        echo
        service "$SERVICE" status || true
    fi

    echo
    echo "Конфигурация:"
    [ -f "$CONF" ] && echo "$CONF" || echo "не создана"

    pause
}

strategy_list() {
    wget -qO- \
        "https://api.github.com/repos/Hactpoenue/nfqws2-openwrt-menu/contents/strategies/nfqws2" |
        sed -n 's/.*"name": *"\([^"]*\.conf\)".*/\1/p'
}

download_strategy() {
    name="$1"
    tmp="/tmp/nfqws2.conf.$$"

    echo
    echo "Загрузка стратегии:"
    echo "$name"
    echo

    wget -qO "$tmp" "$STRATEGIES/$name" || {
        rm -f "$tmp"
        echo "${R}Ошибка загрузки стратегии.${N}"
        return 1
    }

    mkdir -p "$DIR"

    if [ -f "$CONF" ]; then
        cp "$CONF" "$CONF.bak"
    fi

    sed \
        -e 's#/opt/etc/nfqws2#/etc/nfqws2#g' \
        -e 's#/opt/etc#/etc#g' \
        -e 's#/opt/var#/var#g' \
        "$tmp" > "$CONF"

    rm -f "$tmp"

    echo
    echo "${G}Стратегия установлена.${N}"

    if [ -x "/etc/init.d/$SERVICE" ]; then
        service "$SERVICE" restart >/dev/null 2>&1 || true
    fi
}

strategy_menu() {
    while true; do
        header

        echo "=============================================="
        echo " Стратегии NFQWS2"
        echo "=============================================="
        echo

        echo " 1) default"

        n=2

        for f in $(strategy_list); do
            printf " %s) %s\n" "$n" "$f"
            n=$((n + 1))
        done

        echo
        echo " u) Обновить список"
        echo " 0) Назад"
        echo

        printf "Выбор: "
        read -r c

        case "$c" in
            0|"")
                return
                ;;

            u|U)
                strategy_list >/dev/null
                echo "Список обновлён."
                sleep 1
                ;;

            1)
                if [ -f "$DIR/default.conf" ]; then
                    cp "$DIR/default.conf" "$CONF"
                else
                    echo "${Y}default.conf отсутствует.${N}"
                fi
                pause
                ;;

            *)
                if [ "$c" -ge 2 ] 2>/dev/null &&
                   [ "$c" -lt "$n" ] 2>/dev/null
                then
                    i=2

                    for f in $(strategy_list); do
                        if [ "$i" = "$c" ]; then
                            download_strategy "$f"
                            break
                        fi
                        i=$((i + 1))
                    done

                    pause
                else
                    echo "${Y}Неверный выбор.${N}"
                    sleep 1
                fi
                ;;
        esac
    done
}

update_blobs() {
    header

    echo "=============================================="
    echo " Blobs"
    echo "=============================================="
    echo

    mkdir -p "$DIR/blobs"

    echo "Содержимое:"
    wget -qO- \
        "https://api.github.com/repos/Hactpoenue/nfqws2-openwrt-menu/contents/strategies/blobs" |
        sed -n 's/.*"name": *"\([^"]*\)".*/\1/p'

    echo
    echo "Blobs не копируются автоматически."
    echo "Они загружаются только при необходимости."

    pause
}

update_lists() {
    header

    echo "=============================================="
    echo " Lists"
    echo "=============================================="
    echo

    mkdir -p "$DIR/lists"

    wget -qO- \
        "https://api.github.com/repos/Hactpoenue/nfqws2-openwrt-menu/contents/strategies/lists" |
        sed -n 's/.*"name": *"\([^"]*\)".*/\1/p'

    echo
    echo "Lists хранятся в GitHub."
    echo "Локально они не синхронизируются целиком."

    pause
}

dns_menu() {
    if [ -x "$DNS_MENU" ]; then
        "$DNS_MENU"
    else
        echo "${R}menu-dns.sh не найден.${N}"
        pause
    fi
}

diagnostics() {
    header

    echo "=============================================="
    echo " Диагностика"
    echo "=============================================="
    echo

    echo "OpenWrt:"
    grep DISTRIB_DESCRIPTION /etc/openwrt_release 2>/dev/null

    echo
    echo "Target:"
    grep DISTRIB_TARGET /etc/openwrt_release 2>/dev/null

    echo
    echo "Architecture:"
    grep DISTRIB_ARCH /etc/openwrt_release 2>/dev/null

    echo
    echo "WAN:"
    wan

    echo
    echo "Flash:"
    df -h /

    echo
    echo "NFQWS2:"
    if installed; then
        echo "installed"
        echo "version: $(version)"
    else
        echo "not installed"
    fi

    echo
    echo "Config:"
    [ -f "$CONF" ] && ls -lh "$CONF" || echo "not found"

    pause
}

logs() {
    header

    echo "Последние сообщения NFQWS2:"
    echo

    logread 2>/dev/null |
        grep -i nfqws2 |
        tail -100

    pause
}

main() {
    [ "$(id -u)" = "0" ] || {
        echo "Запустите от root."
        exit 1
    }

    while true; do
        header
        status

        echo "${B}[ NFQWS2 ]${N}"
        echo
        echo " 1) Установить NFQWS2"
        echo " 2) Удалить NFQWS2"
        echo " 3) Обновить NFQWS2"
        echo " 4) Запустить"
        echo " 5) Остановить"
        echo " 6) Перезапустить"
        echo " 7) Статус"
        echo

        echo "${B}[ СТРАТЕГИИ ]${N}"
        echo
        echo "10) Выбрать стратегию"
        echo "11) Обновить стратегии"
        echo "12) Обновить blobs"
        echo "13) Обновить lists"
        echo "14) Обновить IPSet"
        echo

        echo "${B}[ DNS ]${N}"
        echo
        echo "20) DoH / DoT"
        echo

        echo "${B}[ СИСТЕМА ]${N}"
        echo
        echo "30) Диагностика"
        echo "31) Логи"
        echo

        echo " 0) Выход"
        echo

        printf "Выбор: "
        read -r c

        case "$c" in
            1) install_nfqws2 ;;
            2) remove_nfqws2 ;;
            3) update_nfqws2 ;;
            4) start_nfqws2 ;;
            5) stop_nfqws2 ;;
            6) restart_nfqws2 ;;
            7) status_nfqws2 ;;
            10) strategy_menu ;;
            11) strategy_menu ;;
            12) update_blobs ;;
            13) update_lists ;;
            14) update_lists ;;
            20) dns_menu ;;
            30) diagnostics ;;
            31) logs ;;
            0) exit 0 ;;
            *) echo "${Y}Неверный выбор.${N}"; sleep 1 ;;
        esac
    done
}

main
