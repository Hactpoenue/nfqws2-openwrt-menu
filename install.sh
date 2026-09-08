#!/bin/sh

# =============================================================================
# NFQWS2 OpenWrt Menu
# One-line installer
# =============================================================================

set -e

REPO="https://raw.githubusercontent.com/Hactpoenue/nfqws2-openwrt-menu/main"

INSTALL_DIR="/usr/lib/nfqws2-openwrt-menu"
BIN="/usr/bin/nfqws-menu"

echo
echo "=============================================="
echo "     NFQWS2 OPENWRT MENU INSTALLER"
echo "=============================================="
echo

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: installer must be run as root."
    exit 1
fi

if [ ! -f /etc/openwrt_release ]; then
    echo "ERROR: OpenWrt не обнаружен."
    exit 1
fi

. /etc/openwrt_release

echo "OpenWrt : ${DISTRIB_DESCRIPTION:-unknown}"
echo "Release : ${DISTRIB_RELEASE:-unknown}"
echo "Target  : ${DISTRIB_TARGET:-unknown}"
echo "Arch    : ${DISTRIB_ARCH:-unknown}"

echo
echo "[1/4] Проверка загрузчика..."

if command -v curl >/dev/null 2>&1; then
    DOWNLOAD="curl"
elif command -v wget >/dev/null 2>&1; then
    DOWNLOAD="wget"
else
    echo "Устанавливаем wget-ssl..."

    apk update
    apk add wget-ssl

    DOWNLOAD="wget"
fi

download()
{
    url="$1"
    file="$2"

    if [ "$DOWNLOAD" = "curl" ]; then
        curl -fsSL "$url" -o "$file"
    else
        wget -qO "$file" "$url"
    fi
}

echo
echo "[2/4] Создание каталогов..."

mkdir -p "$INSTALL_DIR"
mkdir -p /etc/nfqws2

echo
echo "[3/4] Загрузка меню..."

TMP="/tmp/nfqws2-menu-install"

rm -rf "$TMP"
mkdir -p "$TMP"

download \
    "$REPO/nfqws-menu.sh" \
    "$TMP/nfqws-menu.sh"

download \
    "$REPO/usr/lib/nfqws2-openwrt-menu/menu-dns.sh" \
    "$TMP/menu-dns.sh"

if [ ! -s "$TMP/nfqws-menu.sh" ]; then
    echo "ERROR: nfqws-menu.sh не загружен."
    rm -rf "$TMP"
    exit 1
fi

if [ ! -s "$TMP/menu-dns.sh" ]; then
    echo "ERROR: menu-dns.sh не загружен."
    rm -rf "$TMP"
    exit 1
fi

chmod 0755 "$TMP/nfqws-menu.sh"
chmod 0755 "$TMP/menu-dns.sh"

cp -f "$TMP/nfqws-menu.sh" "$BIN"
cp -f "$TMP/menu-dns.sh" "$INSTALL_DIR/menu-dns.sh"

chmod 0755 "$BIN"
chmod 0755 "$INSTALL_DIR/menu-dns.sh"

rm -rf "$TMP"

echo
echo "[4/4] Установка завершена."

echo
echo "=============================================="
echo "              ГОТОВО"
echo "=============================================="
echo

echo "Меню установлено:"
echo
echo "  $BIN"
echo

echo "Запуск:"
echo
echo "  nfqws-menu"
echo

echo "Репозиторий:"
echo
echo "  $REPO"
echo

echo "=============================================="
echo
