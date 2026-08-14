#!/usr/bin/env bash

# Sets up Neovim from source.

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

log "Installing..."

if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
  exit
fi

mkdir -p ~/apps

if [[ "$OSTYPE" == "darwin"* ]]; then
  brew install cmake gettext
elif [[ "$OSTYPE" == "linux"* ]]; then
  sudo apt install cmake gettext lua5.3 liblua5.3-dev
else
  log "Unsupported operating system"
  exit 1
fi

# Clone neovim repository
git clone -b nightly https://github.com/neovim/neovim.git ~/apps/neovim

cd ~/apps/neovim || exit 1

make CMAKE_BUILD_TYPE=RelWithDebInfo
sudo make install
