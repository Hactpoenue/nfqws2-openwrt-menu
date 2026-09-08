#!/bin/sh

set -e

REPO="https://raw.githubusercontent.com/Hactpoenue/nfqws2-openwrt-menu/main"

MENU="/usr/bin/nfqws-menu"
DNS_MENU="/usr/lib/nfqws2-openwrt-menu/menu-dns.sh"

echo
echo "=============================================="
echo "     NFQWS2 OPENWRT MENU INSTALLER"
echo "=============================================="
echo

[ "$(id -u)" = "0" ] || {
    echo "ERROR: запускать нужно от root"
    exit 1
}

echo "OpenWrt:"
grep DISTRIB_DESCRIPTION /etc/openwrt_release 2>/dev/null || true
echo

echo "[1/3] Создание каталогов..."

mkdir -p /usr/lib/nfqws2-openwrt-menu

echo "[2/3] Загрузка меню..."

wget -qO "$MENU" "$REPO/nfqws-menu.sh"
chmod 755 "$MENU"

echo "[3/3] Загрузка DNS меню..."

wget -qO "$DNS_MENU" "$REPO/menu-dns.sh"
chmod 755 "$DNS_MENU"

echo
echo "=============================================="
echo " Установка завершена"
echo "=============================================="
echo
echo "Запуск:"
echo
echo "  nfqws-menu"
echo
