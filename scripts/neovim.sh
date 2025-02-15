#!/usr/bin/env bash

echo "[neovim] Installing..."

if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
  exit
fi

mkdir -p ~/apps

if [[ "$OSTYPE" == "darwin"* ]]; then
  brew install cmake gettext
elif [[ "$OSTYPE" == "linux"* ]]; then
  sudo apt install cmake gettext lua5.3 liblua5.3-dev
else
  echo "Unsupported operating system"
  exit 1
fi

# Clone neovim repository
git clone -b nightly https://github.com/neovim/neovim.git ~/apps/neovim

cd ~/apps/neovim || exit

make CMAKE_BUILD_TYPE=RelWithDebInfo
sudo make install
