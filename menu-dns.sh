#!/bin/sh

# =============================================================================
# NFQWS2 OpenWrt Menu
# OpenWrt 25.12.x
# Только NFQWS2
# =============================================================================

VERSION="1.0.1"

GITHUB_REPO="https://raw.githubusercontent.com/Hactpoenue/nfqws2-openwrt-menu/main"

# Репозиторий стратегий GitHub
STRATEGIES_URL="$GITHUB_REPO/strategies"

# -----------------------------------------------------------------------------
# NFQWS2
# -----------------------------------------------------------------------------

NFQWS2_PACKAGE="nfqws2-keenetic"
NFQWS2_SERVICE="nfqws2-keenetic"

NFQWS2_DIR="/etc/nfqws2"
NFQWS2_CONFIG="$NFQWS2_DIR/nfqws2.conf"
NFQWS2_BACKUP="$NFQWS2_DIR/backup"

# -----------------------------------------------------------------------------
# Локальные файлы меню
#
# ВАЖНО:
# GitHub:
#
# strategies/
# ├── blobs/
# ├── lists/
# └── nfqws2/
#
# На роутере:
#
# /usr/share/nfqws2-openwrt-menu/
# └── strategies/
#     ├── blobs/
#     ├── lists/
#     └── nfqws2/
# -----------------------------------------------------------------------------

LOCAL_BASE="/usr/share/nfqws2-openwrt-menu"
LOCAL_STRATEGIES="$LOCAL_BASE/strategies/nfqws2"
LOCAL_BLOBS="$LOCAL_BASE/strategies/blobs"
LOCAL_LISTS="$LOCAL_BASE/strategies/lists"

# -----------------------------------------------------------------------------
# Официальный репозиторий NFQWS2
# -----------------------------------------------------------------------------

OFFICIAL_REPO="https://nfqws.github.io/nfqws2-keenetic/openwrt/packages.adb"
OFFICIAL_KEY="https://nfqws.github.io/nfqws2-keenetic/openwrt/nfqws2-keenetic.pem"

# -----------------------------------------------------------------------------
# Цвета
# -----------------------------------------------------------------------------

ESC=$(printf '\033')

RED="${ESC}[31m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
BLUE="${ESC}[34m"
CYAN="${ESC}[36m"
BOLD="${ESC}[1m"
DIM="${ESC}[2m"
RESET="${ESC}[0m"

# -----------------------------------------------------------------------------
# Общие функции
# -----------------------------------------------------------------------------

pause()
{
    echo
    printf "Нажмите Enter для продолжения..."
    read -r _
}

info()
{
    printf "%s[INFO]%s %s\n" "$CYAN" "$RESET" "$1"
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

need_root()
{
    if [ "$(id -u)" != "0" ]; then
        error "Запустите меню от root."
        exit 1
    fi
}

have_cmd()
{
    command -v "$1" >/dev/null 2>&1
}

is_installed()
{
    apk info -e "$NFQWS2_PACKAGE" >/dev/null 2>&1
}

service_exists()
{
    [ -x "/etc/init.d/$NFQWS2_SERVICE" ]
}

service_running()
{
    service_exists || return 1
    service "$NFQWS2_SERVICE" running >/dev/null 2>&1
}

get_installed_version()
{
    apk info "$NFQWS2_PACKAGE" 2>/dev/null |
        sed -n 's/^Installed-Version: //p' |
        head -n1
}

detect_wan_interface()
{
    ip route 2>/dev/null |
        awk '
        /^default/ {
            for (i=1;i<=NF;i++) {
                if ($i=="dev") {
                    print $(i+1)
                    exit
                }
            }
        }'
}

ensure_dirs()
{
    mkdir -p "$NFQWS2_DIR"
    mkdir -p "$NFQWS2_BACKUP"

    mkdir -p "$LOCAL_STRATEGIES"
    mkdir -p "$LOCAL_BLOBS"
    mkdir -p "$LOCAL_LISTS"

    mkdir -p "$BLOBS_DIR"
    mkdir -p "$LISTS_DIR"
}

download()
{
    local url="$1"
    local dest="$2"

    mkdir -p "$(dirname "$dest")"

    if have_cmd curl; then
        curl -fsSL \
            -H 'Cache-Control: no-cache' \
            -H 'Pragma: no-cache' \
            "$url" \
            -o "$dest"

        return $?
    fi

    if have_cmd wget; then
        wget -qO "$dest" "$url"
        return $?
    fi

    error "Не найден curl или wget."
    return 1
}

# -----------------------------------------------------------------------------
# Заголовок
# -----------------------------------------------------------------------------

header()
{
    clear 2>/dev/null || true

    echo
    printf "%s==============================================%s\n" \
        "$CYAN" "$RESET"

    printf "%s          NFQWS2 OPENWRT MENU v%s%s\n" \
        "$BOLD" "$VERSION" "$RESET"

    printf "%s==============================================%s\n" \
        "$CYAN" "$RESET"

    echo
}

# -----------------------------------------------------------------------------
# Статус
# -----------------------------------------------------------------------------

show_status()
{
    printf "%sNFQWS2:%s " "$BOLD" "$RESET"

    if is_installed; then
        printf "%sУСТАНОВЛЕН%s" "$GREEN" "$RESET"

        local version
        version="$(get_installed_version)"

        [ -n "$version" ] &&
            printf " (%s)" "$version"

        if service_running; then
            printf "  %s● RUNNING%s" "$GREEN" "$RESET"
        else
            printf "  %s● STOPPED%s" "$RED" "$RESET"
        fi
    else
        printf "%sНЕ УСТАНОВЛЕН%s" "$RED" "$RESET"
    fi

    echo

    local iface
    iface="$(detect_wan_interface)"

    printf "%sWAN:%s %s\n" \
        "$BOLD" "$RESET" "${iface:-не определён}"

    if [ -f "$NFQWS2_CONFIG" ]; then
        local strategy
        strategy="$(get_current_strategy)"

        printf "%sСтратегия:%s %s\n" \
            "$BOLD" "$RESET" "${strategy:-default}"
    fi

    echo
}

# -----------------------------------------------------------------------------
# Официальный репозиторий
# -----------------------------------------------------------------------------

install_repository()
{
    info "Настройка официального репозитория NFQWS2..."

    mkdir -p /etc/apk/keys
    mkdir -p /etc/apk/repositories.d

    if [ ! -f /etc/apk/keys/nfqws2-keenetic.pem ]; then

        info "Загрузка ключа..."

        if ! download \
            "$OFFICIAL_KEY" \
            "/etc/apk/keys/nfqws2-keenetic.pem"
        then
            error "Не удалось загрузить ключ NFQWS2."
            return 1
        fi
    fi

    printf '%s\n' "$OFFICIAL_REPO" \
        > /etc/apk/repositories.d/nfqws2-keenetic.list

    ok "Официальный репозиторий настроен."

    return 0
}

# -----------------------------------------------------------------------------
# Зависимости
# -----------------------------------------------------------------------------

install_dependencies()
{
    info "Проверка необходимых компонентов..."

    apk --update-cache add \
        ca-certificates \
        wget-ssl

    return $?
}

# -----------------------------------------------------------------------------
# Установка
# -----------------------------------------------------------------------------

install_nfqws2()
{
    header

    echo "=============================================="
    echo " Установка NFQWS2"
    echo "=============================================="
    echo

    if is_installed; then
        warn "NFQWS2 уже установлен."
        echo
        echo "Версия: $(get_installed_version)"
        pause
        return
    fi

    install_dependencies || {
        error "Не удалось установить зависимости."
        pause
        return
    }

    install_repository || {
        error "Не удалось настроить репозиторий."
        pause
        return
    }

    echo
    info "Обновление списка пакетов..."

    apk update || {
        error "apk update завершился ошибкой."
        pause
        return
    }

    echo
    info "Установка $NFQWS2_PACKAGE..."

    if ! apk add "$NFQWS2_PACKAGE"; then
        error "Не удалось установить NFQWS2."
        pause
        return
    fi

    ensure_dirs

    if service_exists; then
        service "$NFQWS2_SERVICE" enable >/dev/null 2>&1 || true
    fi

    echo
    ok "NFQWS2 установлен."

    echo
    echo "Версия:"
    get_installed_version

    echo
    echo "Конфигурация:"
    echo "$NFQWS2_CONFIG"

    pause
}

# -----------------------------------------------------------------------------
# Удаление
# -----------------------------------------------------------------------------

remove_nfqws2()
{
    header

    echo "=============================================="
    echo " Удаление NFQWS2"
    echo "=============================================="
    echo

    if ! is_installed; then
        warn "NFQWS2 не установлен."
        pause
        return
    fi

    echo "Будет удалён пакет:"
    echo "  $NFQWS2_PACKAGE"
    echo

    printf "Удалить NFQWS2? [y/N]: "
    read -r answer

    case "$answer" in
        y|Y|д|Д)
            ;;
        *)
            echo "Отмена."
            pause
            return
            ;;
    esac

    if service_exists; then
        service "$NFQWS2_SERVICE" stop >/dev/null 2>&1 || true
        service "$NFQWS2_SERVICE" disable >/dev/null 2>&1 || true
    fi

    echo
    info "Удаление пакета..."

    apk del "$NFQWS2_PACKAGE" || {
        error "Ошибка удаления."
        pause
        return
    }

    ok "NFQWS2 удалён."

    echo
    echo "Конфигурация /etc/nfqws2 оставлена."
    echo "Стратегии меню также оставлены."

    pause
}

# -----------------------------------------------------------------------------
# Обновление NFQWS2
# -----------------------------------------------------------------------------

update_nfqws2()
{
    header

    echo "=============================================="
    echo " Обновление NFQWS2"
    echo "=============================================="
    echo

    if ! is_installed; then
        warn "NFQWS2 не установлен."
        pause
        return
    fi

    install_repository || {
        pause
        return
    }

    apk update || {
        error "Не удалось обновить список пакетов."
        pause
        return
    }

    echo
    info "Проверка обновлений..."

    apk upgrade "$NFQWS2_PACKAGE"

    echo
    ok "Обновление завершено."

    pause
}

# -----------------------------------------------------------------------------
# Сервис
# -----------------------------------------------------------------------------

start_nfqws2()
{
    if ! is_installed; then
        warn "NFQWS2 не установлен."
        pause
        return
    fi

    service "$NFQWS2_SERVICE" start

    echo
    ok "NFQWS2 запущен."

    pause
}

stop_nfqws2()
{
    if ! is_installed; then
        warn "NFQWS2 не установлен."
        pause
        return
    fi

    service "$NFQWS2_SERVICE" stop

    echo
    ok "NFQWS2 остановлен."

    pause
}

restart_nfqws2()
{
    if ! is_installed; then
        warn "NFQWS2 не установлен."
        pause
        return
    fi

    service "$NFQWS2_SERVICE" restart

    echo
    ok "NFQWS2 перезапущен."

    pause
}

status_nfqws2()
{
    header

    echo "=============================================="
    echo " Статус NFQWS2"
    echo "=============================================="
    echo

    if is_installed; then
        echo "Пакет:       установлен"
        echo "Версия:      $(get_installed_version)"
    else
        echo "Пакет:       НЕ установлен"
    fi

    echo
    echo "Сервис:"

    if service_exists; then
        service "$NFQWS2_SERVICE" status || true
    else
        echo "init script не найден"
    fi

    echo
    echo "Конфигурация:"

    if [ -f "$NFQWS2_CONFIG" ]; then
        echo "$NFQWS2_CONFIG"
    else
        echo "не найдена"
    fi

    echo
    echo "WAN:"
    detect_wan_interface

    echo
    echo "Стратегия:"
    get_current_strategy

    pause
}

# -----------------------------------------------------------------------------
# Текущая стратегия
# -----------------------------------------------------------------------------

get_current_strategy()
{
    [ -f "$NFQWS2_CONFIG" ] || {
        echo "default"
        return
    }

    local current

    current="$(
        grep -E '^# NFQWS2_MENU_STRATEGY=' \
            "$NFQWS2_CONFIG" 2>/dev/null |
        head -n1 |
        cut -d= -f2-
    )"

    if [ -n "$current" ]; then
        echo "$current"
        return
    fi

    echo "default"
}

# -----------------------------------------------------------------------------
# Подготовка стратегии
# -----------------------------------------------------------------------------

prepare_strategy()
{
    local src="$1"
    local tmp="$2"

    sed \
        -e 's#/opt/etc/nfqws2#/etc/nfqws2#g' \
        -e 's#/opt/var#/var#g' \
        -e 's#/opt/etc#/etc#g' \
        "$src" > "$tmp"
}

# -----------------------------------------------------------------------------
# Копирование зависимостей стратегии
# -----------------------------------------------------------------------------

copy_strategy_dependencies()
{
    local conf="$1"

    [ -f "$conf" ] || return 0

    echo
    info "Проверка blobs..."

    local paths
    local path
    local name
    local source
    local destination

    paths=$(
        grep -vE '^[[:space:]]*#' "$conf" 2>/dev/null |
        tr ' \t' '\n' |
        sed -n \
            -e 's/.*@\(\/[^[:space:]"]*\.bin\).*/\1/p' \
            -e 's/.*=\(\/[^[:space:]"]*\.bin\).*/\1/p' |
        sort -u
    )

    for path in $paths; do

        [ -n "$path" ] || continue

        if [ -f "$path" ]; then
            ok "blob: $(basename "$path")"
            continue
        fi

        name="$(basename "$path")"
        source="$LOCAL_BLOBS/$name"
        destination="$path"

        if [ -f "$source" ]; then
            mkdir -p "$(dirname "$destination")"
            cp -f "$source" "$destination"
            ok "blob скопирован: $name"
        else
            warn "blob отсутствует: $name"
        fi
    done

    echo
    info "Проверка lists..."

    paths=$(
        grep -vE '^[[:space:]]*#' "$conf" 2>/dev/null |
        tr ' \t' '\n' |
        sed -n \
            -e 's/.*[=:]\(\/[^[:space:]"]*\.list\).*/\1/p' \
            -e 's/^\(\/[^[:space:]"]*\.list\)$/\1/p' |
        sort -u
    )

    for path in $paths; do

        [ -n "$path" ] || continue

        if [ -f "$path" ]; then
            ok "list: $(basename "$path")"
            continue
        fi

        name="$(basename "$path")"
        source="$LOCAL_LISTS/$name"
        destination="$path"

        if [ -f "$source" ]; then
            mkdir -p "$(dirname "$destination")"
            cp -f "$source" "$destination"
            ok "list скопирован: $name"

        elif [ "$name" = "auto.list" ]; then
            mkdir -p "$(dirname "$destination")"
            touch "$destination"
            ok "создан auto.list"

        else
            warn "list отсутствует: $name"
        fi
    done
}

# -----------------------------------------------------------------------------
# Синхронизация GitHub
# -----------------------------------------------------------------------------

github_file_urls()
{
    local path="$1"
    local api

    api="https://api.github.com/repos/Hactpoenue/nfqws2-openwrt-menu/contents/$path"

    if have_cmd curl; then
        curl -fsSL "$api" 2>/dev/null |
            sed -n 's/.*"download_url": *"\([^"]*\)".*/\1/p'
        return
    fi

    if have_cmd wget; then
        wget -qO- "$api" 2>/dev/null |
            sed -n 's/.*"download_url": *"\([^"]*\)".*/\1/p'
        return
    fi

    return 1
}

download_local_strategies()
{
    ensure_dirs

    local url
    local name

    echo
    info "Синхронизация strategies/nfqws2..."

    for url in $(github_file_urls "strategies/nfqws2"); do

        [ -n "$url" ] || continue

        name="$(basename "$url")"

        case "$name" in
            *.conf)
                ;;
            *)
                continue
                ;;
        esac

        info "  $name"

        download "$url" "$LOCAL_STRATEGIES/$name" ||
            warn "Не удалось скачать $name"
    done

    echo
    info "Синхронизация strategies/blobs..."

    for url in $(github_file_urls "strategies/blobs"); do

        [ -n "$url" ] || continue

        name="$(basename "$url")"

        info "  $name"

        download "$url" "$LOCAL_BLOBS/$name" ||
            warn "Не удалось скачать $name"
    done

    echo
    info "Синхронизация strategies/lists..."

    for url in $(github_file_urls "strategies/lists"); do

        [ -n "$url" ] || continue

        name="$(basename "$url")"

        info "  $name"

        download "$url" "$LOCAL_LISTS/$name" ||
            warn "Не удалось скачать $name"
    done

    echo
    ok "Синхронизация завершена."
}

# -----------------------------------------------------------------------------
# Список стратегий
# -----------------------------------------------------------------------------

list_strategy_files()
{
    find "$LOCAL_STRATEGIES" \
        -maxdepth 1 \
        -type f \
        -name '*.conf' \
        -exec basename {} \; 2>/dev/null |
        sort -V
}

# -----------------------------------------------------------------------------
# Выбор стратегии
# -----------------------------------------------------------------------------

apply_strategy()
{
    local selected="$1"
    local source
    local tmp
    local backup
    local detected
    local timestamp

    ensure_dirs

    if [ "$selected" = "default" ]; then
        source=""
    else
        source="$LOCAL_STRATEGIES/$selected"

        if [ ! -f "$source" ]; then
            error "Стратегия не найдена:"
            echo "$source"
            return 1
        fi
    fi

    if [ ! -f "$NFQWS2_CONFIG" ]; then
        error "Конфигурация NFQWS2 отсутствует:"
        echo "$NFQWS2_CONFIG"
        return 1
    fi

    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup="$NFQWS2_BACKUP/nfqws2.conf.$timestamp"

    cp -a "$NFQWS2_CONFIG" "$backup"

    ok "Backup создан: $backup"

    if [ "$selected" = "default" ]; then

        echo
        info "Для default используется текущая конфигурация пакета."

    else

        tmp="/tmp/nfqws2-strategy.$$.conf"

        prepare_strategy "$source" "$tmp"

        {
            echo "# NFQWS2_MENU_STRATEGY=$selected"
            cat "$tmp"
        } > "${tmp}.new"

        mv "${tmp}.new" "$tmp"
        mv "$tmp" "$NFQWS2_CONFIG"

        ok "Стратегия применена: $selected"
    fi

    echo
    info "Определение WAN interface..."

    detected="$(detect_wan_interface)"

    if [ -n "$detected" ]; then

        echo "WAN: $detected"

        if grep -qE '^ISP_INTERFACE=' "$NFQWS2_CONFIG"; then

            sed -i \
                "s|^ISP_INTERFACE=.*|ISP_INTERFACE=\"$detected\"|" \
                "$NFQWS2_CONFIG"

        else

            {
                printf 'ISP_INTERFACE="%s"\n' "$detected"
                cat "$NFQWS2_CONFIG"
            } > "${NFQWS2_CONFIG}.new"

            mv "${NFQWS2_CONFIG}.new" "$NFQWS2_CONFIG"
        fi

        ok "ISP_INTERFACE настроен."

    else

        warn "WAN interface не определён."

    fi

    copy_strategy_dependencies "$NFQWS2_CONFIG"

    echo
    printf "Перезапустить NFQWS2 сейчас? [Y/n]: "
    read -r answer

    case "$answer" in
        n|N|н|Н)
            ;;
        *)
            service "$NFQWS2_SERVICE" restart >/dev/null 2>&1 || true
            ;;
    esac

    echo
    ok "Готово."

    return 0
}

strategy_menu()
{
    while true; do

        header

        echo "=============================================="
        echo " Стратегии NFQWS2"
        echo "=============================================="
        echo

        ensure_dirs

        local list
        local f
        local selected
        local current
        local i
        local n

        list="$(list_strategy_files)"
        current="$(get_current_strategy)"

        printf " 1. default"

        if [ "$current" = "default" ]; then
            printf " %s<-- текущая%s" "$GREEN" "$RESET"
        fi

        echo

        i=2

        for f in $list; do

            printf " %d. %s" "$i" "$f"

            if [ "$current" = "$f" ]; then
                printf " %s<-- текущая%s" "$GREEN" "$RESET"
            fi

            echo

            i=$((i + 1))
        done

        echo
        echo " u. Обновить стратегии"
        echo " 0. Назад"
        echo

        printf "Номер стратегии: "
        read -r selected

        case "$selected" in

            0|"")
                return
                ;;

            u|U)
                download_local_strategies
                pause
                ;;

            1)
                apply_strategy "default"
                pause
                ;;

            *)
                if [ "$selected" -ge 2 ] 2>/dev/null &&
                   [ "$selected" -lt "$i" ] 2>/dev/null
                then

                    n=2

                    for f in $list; do

                        if [ "$n" -eq "$selected" ]; then
                            apply_strategy "$f"
                            pause
                            break
                        fi

                        n=$((n + 1))
                    done

                else

                    warn "Неверный номер."
                    sleep 1

                fi
                ;;

        esac

    done
}

# -----------------------------------------------------------------------------
# Blobs
# -----------------------------------------------------------------------------

update_blobs()
{
    header

    echo "=============================================="
    echo " Обновление blobs"
    echo "=============================================="
    echo

    ensure_dirs

    local url
    local name

    for url in $(github_file_urls "strategies/blobs"); do

        [ -n "$url" ] || continue

        name="$(basename "$url")"

        info "Скачивание $name..."

        if download "$url" "$LOCAL_BLOBS/$name"; then
            ok "$name"
        else
            warn "Не удалось скачать $name"
        fi
    done

    if [ -f "$NFQWS2_CONFIG" ]; then
        copy_strategy_dependencies "$NFQWS2_CONFIG"
    fi

    pause
}

# -----------------------------------------------------------------------------
# Lists
# -----------------------------------------------------------------------------

update_lists()
{
    header

    echo "=============================================="
    echo " Обновление lists"
    echo "=============================================="
    echo

    ensure_dirs

    local url
    local name

    for url in $(github_file_urls "strategies/lists"); do

        [ -n "$url" ] || continue

        name="$(basename "$url")"

        [ "$name" = "auto.list" ] && continue

        info "Скачивание $name..."

        if download "$url" "$LOCAL_LISTS/$name"; then
            ok "$name"
        else
            warn "Не удалось скачать $name"
        fi
    done

    if [ -f "$NFQWS2_CONFIG" ]; then
        copy_strategy_dependencies "$NFQWS2_CONFIG"
    fi

    pause
}

# -----------------------------------------------------------------------------
# IPSet
# -----------------------------------------------------------------------------

update_ipset()
{
    header

    echo "=============================================="
    echo " Обновление IPSet"
    echo "=============================================="
    echo

    ensure_dirs

    local url
    local dest

    url="https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/refs/heads/main/.service/ipset-service.txt"
    dest="$LOCAL_LISTS/ipset.list"

    info "Скачивание IPSet..."

    if download "$url" "$dest"; then

        ok "ipset.list обновлён."

        mkdir -p "$LISTS_DIR"
        cp -f "$dest" "$LISTS_DIR/ipset.list"

        ok "ipset.list установлен в /etc/nfqws2/lists."

    else

        error "Не удалось скачать ipset.list."

    fi

    pause
}

# -----------------------------------------------------------------------------
# Диагностика
# -----------------------------------------------------------------------------

diagnostics()
{
    header

    echo "=============================================="
    echo " Диагностика"
    echo "=============================================="
    echo

    if [ -f /etc/openwrt_release ]; then

        . /etc/openwrt_release

        echo "OpenWrt:"
        echo "  ${DISTRIB_DESCRIPTION:-unknown}"

        echo
        echo "Release:"
        echo "  ${DISTRIB_RELEASE:-unknown}"

        echo
        echo "Target:"
        echo "  ${DISTRIB_TARGET:-unknown}"

        echo
        echo "Architecture:"
        echo "  ${DISTRIB_ARCH:-unknown}"

    fi

    echo
    echo "Kernel:"
    uname -a

    echo
    echo "WAN:"
    detect_wan_interface

    echo
    echo "NFQWS2:"

    if is_installed; then
        echo "  installed"
        echo "  version: $(get_installed_version)"
    else
        echo "  NOT INSTALLED"
    fi

    echo
    echo "Service:"

    if service_exists; then
        service "$NFQWS2_SERVICE" status || true
    else
        echo "  init script not found"
    fi

    echo
    echo "Config:"

    if [ -f "$NFQWS2_CONFIG" ]; then
        echo "  $NFQWS2_CONFIG"
    else
        echo "  not found"
    fi

    echo
    echo "Strategy:"
    echo "  $(get_current_strategy)"

    echo
    echo "Menu files:"
    echo "  $LOCAL_BASE"

    echo
    echo "Disk:"
    df -h "$NFQWS2_DIR" 2>/dev/null || df -h

    echo
    echo "Memory:"
    free 2>/dev/null || true

    echo
    echo "Processes:"
    ps 2>/dev/null |
        grep '[n]fqws2' ||
        echo "  process not found"

    pause
}

# -----------------------------------------------------------------------------
# Логи
# -----------------------------------------------------------------------------

show_logs()
{
    header

    echo "=============================================="
    echo " Логи NFQWS2"
    echo "=============================================="
    echo

    logread 2>/dev/null |
        grep -i 'nfqws2' |
        tail -100

    echo
    echo "Для выхода нажмите Ctrl+C."
    echo

    tail -f /var/log/messages 2>/dev/null |
        grep --line-buffered -i 'nfqws2'
}

# -----------------------------------------------------------------------------
# Обновление меню
# -----------------------------------------------------------------------------

update_menu()
{
    header

    echo "=============================================="
    echo " Обновление меню"
    echo "=============================================="
    echo

    local self
    local tmp

    self="$0"
    tmp="/tmp/nfqws-menu.$$.sh"

    info "Загрузка новой версии..."

    if download "$GITHUB_REPO/nfqws-menu.sh" "$tmp"; then

        if [ -s "$tmp" ]; then

            chmod 0755 "$tmp"

            if [ -w "$self" ]; then
                cp "$tmp" "$self"
            else
                cp "$tmp" /usr/bin/nfqws-menu
            fi

            rm -f "$tmp"

            ok "Меню обновлено."

        else

            error "Получен пустой файл."
            rm -f "$tmp"

        fi

    else

        error "Не удалось скачать обновление."
        rm -f "$tmp"

    fi

    pause
}

# -----------------------------------------------------------------------------
# Первая синхронизация
# -----------------------------------------------------------------------------

initial_sync()
{
    ensure_dirs

    if ! find "$LOCAL_STRATEGIES" \
        -maxdepth 1 \
        -type f \
        -name '*.conf' 2>/dev/null |
        grep -q .
    then

        info "Стратегии отсутствуют."
        info "Первая синхронизация..."

        download_local_strategies >/dev/null 2>&1 || true
    fi
}

# -----------------------------------------------------------------------------
# Главное меню
# -----------------------------------------------------------------------------

main_menu()
{
    need_root

    ensure_dirs
    initial_sync

    while true; do

        header
        show_status

        printf "%s[ NFQWS2 ]%s\n" "$BOLD" "$RESET"
        echo
        echo " 1. Установить NFQWS2"
        echo " 2. Удалить NFQWS2"
        echo " 3. Обновить NFQWS2"
        echo " 4. Запустить"
        echo " 5. Остановить"
        echo " 6. Перезапустить"
        echo " 7. Статус"
        echo

        printf "%s[ СТРАТЕГИИ ]%s\n" "$BOLD" "$RESET"
        echo
        echo "10. Выбрать стратегию"
        echo "11. Обновить стратегии"
        echo "12. Обновить blobs"
        echo "13. Обновить lists"
        echo "14. Обновить IPSet"
        echo

        printf "%s[ DNS ]%s\n" "$BOLD" "$RESET"
        echo
        echo "20. DoH / DoT"
        echo

        printf "%s[ СИСТЕМА ]%s\n" "$BOLD" "$RESET"
        echo
        echo "30. Диагностика"
        echo "31. Логи"
        echo "32. Обновить меню"
        echo

        echo " 0. Выход"
        echo

        printf "Выбор: "
        read -r choice

        case "$choice" in

            1)
                install_nfqws2
                ;;

            2)
                remove_nfqws2
                ;;

            3)
                update_nfqws2
                ;;

            4)
                start_nfqws2
                ;;

            5)
                stop_nfqws2
                ;;

            6)
                restart_nfqws2
                ;;

            7)
                status_nfqws2
                ;;

            10)
                strategy_menu
                ;;

            11)
                sync_strategies
                ;;

            12)
                update_blobs
                ;;

            13)
                update_lists
                ;;

            14)
                update_ipset
                ;;

            20)

                if [ -x "/usr/lib/nfqws2-openwrt-menu/menu-dns.sh" ]; then
                    /usr/lib/nfqws2-openwrt-menu/menu-dns.sh

                elif [ -x "$(dirname "$0")/menu-dns.sh" ]; then
                    "$(dirname "$0")/menu-dns.sh"

                else
                    sh /usr/lib/nfqws2-openwrt-menu/menu-dns.sh
                fi

                ;;

            30)
                diagnostics
                ;;

            31)
                show_logs
                ;;

            32)
                update_menu
                ;;

            0)
                clear 2>/dev/null || true
                exit 0
                ;;

            *)
                warn "Неверный выбор."
                sleep 1
                ;;

        esac

    done
}

main_menu
