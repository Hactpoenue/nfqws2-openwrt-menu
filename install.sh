#!/bin/sh

set -e

REPO="https://raw.githubusercontent.com/Hactpoenue/nfqws2-openwrt-menu/main"

INSTALL_DIR="/usr/lib/nfqws2-openwrt-menu"
BIN="/usr/bin/nfqws-menu"

MENU_URL="$REPO/nfqws-menu.sh"
DNS_URL="$REPO/menu-dns.sh"

echo
echo "=============================================="
echo "     NFQWS2 OPENWRT MENU INSTALLER"
echo "=============================================="
echo

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: запускать нужно от root."
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
echo "[3/4] Загрузка файлов..."

TMP="/tmp/nfqws2-install"

rm -rf "$TMP"
mkdir -p "$TMP"

echo "  → nfqws-menu.sh"
download "$MENU_URL" "$TMP/nfqws-menu.sh"

echo "  → menu-dns.sh"
download "$DNS_URL" "$TMP/menu-dns.sh"

if [ ! -s "$TMP/nfqws-menu.sh" ]; then
    echo
    echo "ERROR: nfqws-menu.sh не найден:"
    echo "$MENU_URL"
    rm -rf "$TMP"
    exit 1
fi

if [ ! -s "$TMP/menu-dns.sh" ]; then
    echo
    echo "ERROR: menu-dns.sh не найден:"
    echo "$DNS_URL"
    rm -rf "$TMP"
    exit 1
fi

echo
echo "[4/4] Установка файлов..."

chmod 0755 "$TMP/nfqws-menu.sh"
chmod 0755 "$TMP/menu-dns.sh"

cp -f "$TMP/nfqws-menu.sh" "$BIN"
cp -f "$TMP/menu-dns.sh" "$INSTALL_DIR/menu-dns.sh"

chmod 0755 "$BIN"
chmod 0755 "$INSTALL_DIR/menu-dns.sh"

rm -rf "$TMP"

echo
echo "=============================================="
echo "          УСТАНОВКА ЗАВЕРШЕНА"
echo "=============================================="
echo
echo "Установлено:"
echo
echo "  $BIN"
echo "  $INSTALL_DIR/menu-dns.sh"
echo
echo "Запуск:"
echo
echo "  nfqws-menu"
echo
echo "=============================================="
