#!/usr/bin/env bash

# Sets up Zed from source.

echo "[zed] Installing..."

if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
  exit
fi

mkdir -p ~/apps

if [[ "$OSTYPE" == "darwin"* ]]; then
  brew install cmake postgresql livekit foreman
elif [[ "$OSTYPE" == "linux"* ]]; then
  # this is kind-of crazy, but yolo
  curl -sL https://raw.githubusercontent.com/zed-industries/zed/main/script/linux | bash
else
  echo "Unsupported operating system"
  exit 1
fi

git clone https://github.com/zed-industries/zed ~/apps/zed
cd ~/apps/zed || exit 1

if [[ "$OSTYPE" == "darwin"* ]]; then
  cargo run --release
elif [[ "$OSTYPE" == "linux"* ]]; then
  cargo run -p cli
fi
