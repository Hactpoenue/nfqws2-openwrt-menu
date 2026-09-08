#!/bin/sh

set -u

echo "=============================================="
echo " NFQWS2 OpenWrt Menu - uninstall"
echo "=============================================="
echo

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: root privileges required."
    exit 1
fi

echo "This will remove the NFQWS2 OpenWrt menu."

printf "Continue? [y/N]: "
read -r answer

case "$answer" in
    y|Y|д|Д)
        ;;
    *)
        echo "Cancelled."
        exit 0
        ;;
esac

echo
echo "Removing menu..."

rm -f /usr/bin/nfqws-menu
rm -rf /usr/lib/nfqws2-openwrt-menu

echo
echo "Menu removed."

echo
echo "NFQWS2 itself is NOT removed."
echo "DNS configuration is NOT removed."
echo
echo "Use the menu before uninstalling if you want"
echo "to clean NFQWS2 and DNS configuration."
echo
