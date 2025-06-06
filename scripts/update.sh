#!/usr/bin/env bash

# Updates everything you can update on your system.

echo "[update] Running system updates..."

if command -v apt &> /dev/null; then
  sudo apt update && sudo apt -y upgrade
  sudo apt -y dist-upgrade
  sudo apt -y autoremove
fi

if command -v brew &> /dev/null; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew update && yes | brew upgrade
fi
