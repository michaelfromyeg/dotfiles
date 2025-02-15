#!/usr/bin/env bash

# Installs GUI applications using Homebrew.

echo "[brew-ui] Installing GUI applications..."

if command -v brew &> /dev/null; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew update && yes | brew upgrade

  brew install --cask visual-studio-code
  brew install --cask slack
  brew install --cask discord
  brew install --cask spotify
  brew install --cask docker

  brew cleanup
fi
