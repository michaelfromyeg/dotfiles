#!/usr/bin/env bash

echo "[update] Running system updates..."

sudo apt update && sudo apt -y upgrade
sudo apt -y dist-upgrade
sudo apt -y autoremove

if command -v brew &> /dev/null; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew update && yes | brew upgrade
fi
