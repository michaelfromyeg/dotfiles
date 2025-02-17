#!/usr/bin/env bash

# Installs GUI applications using Homebrew.

echo "[brew] Installing GUI applications..."

if ! command -v brew &> /dev/null; then
  echo "[brew] Homebrew is not installed. Please install Homebrew before running this script."
  exit 1
else
  echo "Updating Homebrew..."
  HOMEBREW_NO_AUTO_UPDATE=1 brew update && yes | brew upgrade
fi

# Taps
brew tap homebrew/cask
brew tap homebrew/cask-versions
brew tap homebrew/core

# Core Command Line Tools
echo "[brew] Installing core command line tools..."
CORE_TOOLS=(
    git
    gh
    node
    vim
    sqlite
    qpdf
    wget
)

# Install core tools
for tool in "${CORE_TOOLS[@]}"; do
    echo "[brew] Installing $tool..."
    brew install "$tool"
done

# Cask Applications
echo "Installing applications..."
APPS=(
    # Core Utilities
    ghostty
    rectangle
    alt-tab

    # Development
    visual-studio-code
    docker

    # Browsers and Communication
    firefox
    google-chrome
    slack
    zoom
    thunderbird

    # Media and File Management
    vlc
    gimp
    handbrake
    obs
    spotify
    skim

    # Office and Productivity
    libreoffice
    notion
    figma
    beeper
    cold-turkey-blocker
    logitech-options
    keepassxc

    # Cloud Storage
    dropbox
    google-drive

    # Utilities
    calibre
    the-unarchiver
    cursor
    dupeguru
    private-internet-access
    qbittorrent

    # Additional Mac-specific tools
    alfred
    bartender
    monitorcontrol
    app-cleaner

    # NOTE: missing mp3 tag!
)

# Install applications
for app in "${APPS[@]}"; do
    echo "[brew] Installing $app..."
    brew install --cask "$app"
done

# Cleanup
echo "[brew] Cleaning up..."
brew cleanup


echo "[brew] Installation complete!"
echo "[brew] NOTE: Some applications may require additional setup or login."
echo "[brew] NOTE: Some applications might require system restart to complete installation."
echo "[brew] NOTE: Some applications might not be available in the Homebrew repository."

brew doctor
