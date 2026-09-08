#!/bin/sh

set -eu

REPO="https://raw.githubusercontent.com/Hactpoenue/nfqws2-openwrt-menu/main"
INSTALL_DIR="/usr/lib/nfqws2-openwrt-menu"
BIN="/usr/bin/nfqws-menu"

echo "=============================================="
echo " NFQWS2 OpenWrt Menu"
echo " OpenWrt 25.12.x"
echo "=============================================="
echo

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: root privileges required."
    exit 1
fi

if [ ! -f /etc/openwrt_release ]; then
    echo "ERROR: OpenWrt not detected."
    exit 1
fi

. /etc/openwrt_release

echo "System: ${DISTRIB_DESCRIPTION:-unknown}"
echo "Release: ${DISTRIB_RELEASE:-unknown}"
echo

# OpenWrt 25.12 uses apk.
if ! command -v apk >/dev/null 2>&1; then
    echo "ERROR: apk was not found."
    echo "This version requires OpenWrt 25.12.x or newer."
    exit 1
fi

echo "[1/4] Installing dependencies..."

apk --update-cache add \
    ca-certificates \
    wget-ssl \
    curl \
    jq \
    coreutils-sort \
    coreutils-stat

echo
echo "[2/4] Creating directories..."

mkdir -p "$INSTALL_DIR"
mkdir -p /etc/nfqws2
mkdir -p /etc/nfqws2/backup
mkdir -p /etc/nfqws2/lists
mkdir -p /etc/nfqws2/blobs

echo
echo "[3/4] Downloading menu..."

TMP="/tmp/nfqws2-openwrt-menu.$$"
mkdir -p "$TMP"

cleanup()
{
    rm -rf "$TMP"
}

trap cleanup EXIT INT TERM

wget -qO "$TMP/nfqws-menu.sh" \
    "$REPO/nfqws-menu.sh"

wget -qO "$TMP/menu-dns.sh" \
    "$REPO/menu-dns.sh"

chmod 0755 "$TMP/nfqws-menu.sh"
chmod 0755 "$TMP/menu-dns.sh"

cp "$TMP/nfqws-menu.sh" "$INSTALL_DIR/nfqws-menu.sh"
cp "$TMP/menu-dns.sh" "$INSTALL_DIR/menu-dns.sh"

ln -sf "$INSTALL_DIR/nfqws-menu.sh" "$BIN"

echo
echo "[4/4] Installation complete."
echo
echo "Start menu:"
echo
echo "    nfqws-menu"
echo

exec "$BIN"
