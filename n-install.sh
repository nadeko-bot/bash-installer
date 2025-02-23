#!/bin/sh
echo ""
echo "Welcome to NadekoBot."
echo "Downloading the latest installer..."
root=$(pwd)

rm "$root/n-bin.sh" 1>/dev/null 2>&1
curl -L -o "$root/n-bin.sh" https://raw.githubusercontent.com/nadeko-bot/bash-installer/refs/heads/v6/n-bin.sh

bash n-bin.sh
cd "$root"
rm "$root/n-bin.sh"
exit 0
