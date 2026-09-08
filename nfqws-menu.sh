#!/bin/sh

# =============================================================================
# NFQWS2 OpenWrt Menu
#
# OpenWrt 25.12.x
# Порт nfqws-menu от rndnaame
#
# Только NFQWS2.
# =============================================================================

VERSION="1.0.0"

GITHUB_REPO="https://raw.githubusercontent.com/Hactpoenue/nfqws2-openwrt-menu/main"
STRATEGIES_URL="$GITHUB_REPO/strategies"

NFQWS2_PACKAGE="nfqws2-keenetic"
NFQWS2_SERVICE="nfqws2-keenetic"

NFQWS2_DIR="/etc/nfqws2"
NFQWS2_CONFIG="$NFQWS2_DIR/nfqws2.conf"
NFQWS2_BACKUP="$NFQWS2_DIR/backup"

BLOBS_DIR="$NFQWS2_DIR/blobs"
LISTS_DIR="$NFQWS2_DIR/lists"

LOCAL_STRATEGIES="/usr/share/nfqws2-openwrt-menu/strategies"

OFFICIAL_REPO="https://nfqws.github.io/nfqws2-keenetic/openwrt/packages.adb"
OFFICIAL_KEY="https://nfqws.github.io/nfqws2-keenetic/openwrt/nfqws2-keenetic.pem"

# -----------------------------------------------------------------------------
# Цвета
# -----------------------------------------------------------------------------

ESC="$(printf '\033')"

RED="${ESC}[31m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
BLUE="${ESC}[34m"
MAGENTA="${ESC}[35m"
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

msg()
{
    printf "%s\n" "$1"
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

detect_wan_device()
{
    local iface
    iface="$(detect_wan_interface)"

    [ -z "$iface" ] && return 0

    echo "$iface"
}

ensure_dirs()
{
    mkdir -p "$NFQWS2_DIR"
    mkdir -p "$NFQWS2_BACKUP"
    mkdir -p "$BLOBS_DIR"
    mkdir -p "$LISTS_DIR"
    mkdir -p "$LOCAL_STRATEGIES"
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
    printf "%s╔══════════════════════════════════════════════════╗%s\n" \
        "$CYAN" "$RESET"

    printf "%s║%s              NFQWS2 OPENWRT MENU              %s║%s\n" \
        "$CYAN" "$BOLD" "$CYAN" "$RESET"

    printf "%s║%s                  v%-8s                     %s║%s\n" \
        "$CYAN" "$YELLOW" "$VERSION" "$CYAN" "$RESET"

    printf "%s╚══════════════════════════════════════════════════╝%s\n" \
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

    printf "%sWAN interface:%s %s\n" \
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
# Официальный репозиторий NFQWS2
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
            "/etc/apk/keys/nfqws2-keenetic.pem"; then

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
    info "Установка необходимых зависимостей..."

    apk --update-cache add \
        ca-certificates \
        wget-ssl

    return $?
}

# -----------------------------------------------------------------------------
# Установка NFQWS2
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
# Удаление NFQWS2
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
    echo "Это позволяет сохранить настройки и списки."

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

    apk update

    echo
    info "Проверка обновлений..."

    apk upgrade "$NFQWS2_PACKAGE"

    echo
    ok "Проверка/обновление завершены."

    pause
}

# -----------------------------------------------------------------------------
# Управление сервисом
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
    echo "WAN interface:"
    detect_wan_interface

    echo
    echo "Текущая стратегия:"
    get_current_strategy

    pause
}

# -----------------------------------------------------------------------------
# Работа со стратегиями
# -----------------------------------------------------------------------------

get_current_strategy()
{
    [ -f "$NFQWS2_CONFIG" ] || return 0

    local current=""
    local f
    local base

    current="$(grep -E '^# NFQWS2_MENU_STRATEGY=' \
        "$NFQWS2_CONFIG" 2>/dev/null |
        head -n1 |
        cut -d= -f2-)"

    if [ -n "$current" ]; then
        echo "$current"
        return
    fi

    # Старые/вручную установленные конфиги.
    # Сравниваем содержимое после нормализации путей.
    for f in "$LOCAL_STRATEGIES"/*.conf; do
        [ -f "$f" ] || continue

        base="$(basename "$f")"

        if cmp -s "$f" "$NFQWS2_CONFIG"; then
            echo "$base"
            return
        fi
    done

    echo "default"
}

prepare_strategy()
{
    local src="$1"
    local tmp="$2"

    # Адаптация путей Entware/Keenetic -> OpenWrt.
    #
    # Стратегии оригинала используют:
    # /opt/etc/nfqws2/...
    #
    # На OpenWrt:
    # /etc/nfqws2/...
    #
    # Также /opt/var -> /var.

    sed \
        -e 's#/opt/etc/nfqws2#/etc/nfqws2#g' \
        -e 's#/opt/var#/var#g' \
        -e 's#/opt/etc#/etc#g' \
        "$src" > "$tmp"
}

copy_strategy_dependencies()
{
    local conf="$1"

    local paths
    local path
    local name
    local source
    local destination

    echo
    info "Проверка blobs..."

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

download_local_strategies()
{
    ensure_dirs

    local base
    local url
    local dest

    for base in \
        "$STRATEGIES_URL/nfqws2" \
        "$STRATEGIES_URL/blobs" \
        "$STRATEGIES_URL/lists"
    do
        case "$base" in
            */nfqws2)
                dest="$LOCAL_STRATEGIES"
                ;;
            */blobs)
                dest="$LOCAL_BLOBS"
                ;;
            */lists)
                dest="$LOCAL_LISTS"
                ;;
        esac

        mkdir -p "$dest"

        info "Синхронизация: $base"

        # Получаем список файлов через GitHub API.
        url="${base#"$GITHUB_REPO"}"

        # Для этой операции используем GitHub API.
        case "$base" in
            */nfqws2)
                api="https://api.github.com/repos/Hactpoenue/nfqws2-openwrt-menu/contents/strategies/nfqws2"
                ;;
            */blobs)
                api="https://api.github.com/repos/Hactpoenue/nfqws2-openwrt-menu/contents/strategies/blobs"
                ;;
            */lists)
                api="https://api.github.com/repos/Hactpoenue/nfqws2-openwrt-menu/contents/strategies/lists"
                ;;
        esac

        if ! have_cmd curl && ! have_cmd wget; then
            warn "Нет curl/wget."
            continue
        fi

        if have_cmd curl; then
            filelist="$(
                curl -fsSL "$api" 2>/dev/null |
                sed -n 's/.*"download_url": *"\([^"]*\)".*/\1/p'
            )"
        else
            filelist="$(
                wget -qO- "$api" 2>/dev/null |
                sed -n 's/.*"download_url": *"\([^"]*\)".*/\1/p'
            )"
        fi

        for url in $filelist; do
            [ -n "$url" ] || continue

            base="$(basename "$url")"

            case "$dest" in
                "$LOCAL_STRATEGIES")
                    case "$base" in
                        *.conf)
                            ;;
                        *)
                            continue
                            ;;
                    esac
                    ;;
            esac

            download "$url" "$dest/$base" >/dev/null 2>&1 || true
        done
    done

    ok "Синхронизация завершена."
}

list_strategy_files()
{
    find "$LOCAL_STRATEGIES" \
        -maxdepth 1 \
        -type f \
        -name '*.conf' \
        -printf '%f\n' 2>/dev/null |
        sort -V
}

sync_strategies()
{
    header

    echo "=============================================="
    echo " Обновление стратегий"
    echo "=============================================="
    echo

    if ! is_installed; then
        warn "NFQWS2 ещё не установлен."
        echo "Но стратегии можно загрузить заранее."
        echo
    fi

    download_local_strategies

    pause
}

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
        error "NFQWS2 не установлен или конфигурация отсутствует:"
        echo "$NFQWS2_CONFIG"
        return 1
    fi

    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup="$NFQWS2_BACKUP/nfqws2.conf.$timestamp"

    cp -a "$NFQWS2_CONFIG" "$backup"

    ok "Backup создан:"
    echo "$backup"

    if [ "$selected" = "default" ]; then
        echo
        info "Восстановление стандартной конфигурации NFQWS2."

        if ! apk add --upgrade "$NFQWS2_PACKAGE"; then
            error "Не удалось обновить/восстановить пакет."
            return 1
        fi

    else
        tmp="/tmp/nfqws2-strategy.$$.conf"

        prepare_strategy "$source" "$tmp"

        # Добавляем служебную метку.
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
        echo "WAN interface: $detected"

        if grep -qE '^ISP_INTERFACE=' "$NFQWS2_CONFIG"; then
            sed -i \
                "s|^ISP_INTERFACE=.*|ISP_INTERFACE=\"$detected\"|" \
                "$NFQWS2_CONFIG"
        else
            printf 'ISP_INTERFACE="%s"\n' "$detected" |
                cat - "$NFQWS2_CONFIG" > \
                "${NFQWS2_CONFIG}.new"

            mv "${NFQWS2_CONFIG}.new" "$NFQWS2_CONFIG"
        fi

        ok "ISP_INTERFACE настроен."
    else
        warn "Не удалось определить WAN interface."
    fi

    echo
    copy_strategy_dependencies "$NFQWS2_CONFIG"

    echo
    printf "Перезапустить NFQWS2 сейчас? [Y/n]: "
    read -r answer

    case "$answer" in
        n|N|н|Н)
            ;;
        *)
            service "$NFQWS2_SERVICE" restart || true
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
        local count
        local i
        local f
        local selected
        local current

        list="$(list_strategy_files)"
        current="$(get_current_strategy)"

        printf " %s1)%s default" "$BOLD" "$RESET"

        if [ "$current" = "default" ]; then
            printf " %s<-- текущая%s" "$GREEN" "$RESET"
        fi

        echo

        i=2

        for f in $list; do
            printf " %s%d)%s %s" "$BOLD" "$i" "$RESET" "$f"

            if [ "$current" = "$f" ]; then
                printf " %s<-- текущая%s" "$GREEN" "$RESET"
            fi

            echo

            i=$((i + 1))
        done

        echo
        echo " u) Обновить стратегии"
        echo " 0) Назад"
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
                    local n=2

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

    info "Синхронизация blobs из нашего репозитория..."

    local api
    local urls
    local url
    local name

    api="https://api.github.com/repos/Hactpoenue/nfqws2-openwrt-menu/contents/strategies/blobs"

    if have_cmd curl; then
        urls="$(curl -fsSL "$api" 2>/dev/null |
            sed -n 's/.*"download_url": *"\([^"]*\)".*/\1/p')"
    else
        urls="$(wget -qO- "$api" 2>/dev/null |
            sed -n 's/.*"download_url": *"\([^"]*\)".*/\1/p')"
    fi

    for url in $urls; do
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

    local api
    local urls
    local url
    local name

    api="https://api.github.com/repos/Hactpoenue/nfqws2-openwrt-menu/contents/strategies/lists"

    if have_cmd curl; then
        urls="$(curl -fsSL "$api" 2>/dev/null |
            sed -n 's/.*"download_url": *"\([^"]*\)".*/\1/p')"
    else
        urls="$(wget -qO- "$api" 2>/dev/null |
            sed -n 's/.*"download_url": *"\([^"]*\)".*/\1/p')"
    fi

    for url in $urls; do
        name="$(basename "$url")"

        # auto.list заполняется самим nfqws2.
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
    echo "$url"
    echo

    if download "$url" "$dest"; then
        ok "ipset.list обновлён."

        if [ -f "$dest" ]; then
            cp -f "$dest" "$LISTS_DIR/ipset.list"
            ok "ipset.list установлен в NFQWS2."
        fi
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
    echo "WAN interface:"
    detect_wan_interface

    echo
    echo "NFQWS2 package:"

    if is_installed; then
        echo "  installed"
        echo "  version: $(get_installed_version)"
    else
        echo "  NOT INSTALLED"
    fi

    echo
    echo "NFQWS2 service:"

    if service_exists; then
        service "$NFQWS2_SERVICE" status || true
    else
        echo "  init script not found"
    fi

    echo
    echo "NFQWS2 config:"

    if [ -f "$NFQWS2_CONFIG" ]; then
        echo "  $NFQWS2_CONFIG"
    else
        echo "  not found"
    fi

    echo
    echo "Current strategy:"
    echo "  $(get_current_strategy)"

    echo
    echo "Disk:"
    df -h "$NFQWS2_DIR" 2>/dev/null || df -h

    echo
    echo "Memory:"
    free 2>/dev/null || true

    echo
    echo "NFQWS2 processes:"
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

    if logread 2>/dev/null |
        grep -i 'nfqws2' |
        tail -100
    then
        :
    else
        echo "Записей NFQWS2 в системном логе нет."
    fi

    echo
    echo "Нажмите Ctrl+C для выхода."
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

    info "Проверка новой версии..."

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
            echo
            echo "Перезапустите меню."
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
# Установка локальных стратегий после установки меню
# -----------------------------------------------------------------------------

initial_sync()
{
    ensure_dirs

    # Не делаем сетевой запрос при каждом запуске.
    # Если стратегий ещё нет — загружаем их автоматически.

    if ! find "$LOCAL_STRATEGIES" \
        -maxdepth 1 \
        -type f \
        -name '*.conf' \
        2>/dev/null |
        grep -q .
    then
        info "Локальные стратегии отсутствуют."
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
        echo " 1) Установить NFQWS2"
        echo " 2) Удалить NFQWS2"
        echo " 3) Обновить NFQWS2"
        echo " 4) Запустить"
        echo " 5) Остановить"
        echo " 6) Перезапустить"
        echo " 7) Статус"
        echo

        printf "%s[ СТРАТЕГИИ ]%s\n" "$BOLD" "$RESET"
        echo
        echo "10) Выбрать стратегию"
        echo "11) Обновить стратегии"
        echo "12) Обновить blobs"
        echo "13) Обновить lists"
        echo "14) Обновить IPSet"
        echo

        printf "%s[ DNS ]%s\n" "$BOLD" "$RESET"
        echo
        echo "20) DoH / DoT"
        echo

        printf "%s[ СИСТЕМА ]%s\n" "$BOLD" "$RESET"
        echo
        echo "30) Диагностика"
        echo "31) Логи"
        echo "32) Обновить меню"
        echo

        echo " 0) Выход"
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
