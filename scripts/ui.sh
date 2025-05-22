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


# Check for OS
OS_TYPE=$(uname -s)

# If running on MacOS, tap homebrew/cask and homebrew/cask-versions
if [ "$OS_TYPE" == "Darwin" ]; then
  brew tap homebrew/cask
  brew tap homebrew/cask-versions
fi

# Core Command Line Tools
echo "[brew] Installing core command line tools..."
CORE_TOOLS=(
  gcc
  git
  gh
  vim
  make
  # NOTE: this is built from source!
  # neovim
  sqlite
  qpdf
  wget
  # GNU-find, since the normal macOS find sucks
  findutils
  fzf
  lazygit
  ripgrep
  fd
  git-delta
  tree
  # Rendering stuff
  imagemagick
  ghostscript
  tectonic
  jandedobbeleer/oh-my-posh/oh-my-posh
)

# Install core tools
for tool in "${CORE_TOOLS[@]}"; do
  echo "[brew] Installing $tool..."
  brew install "$tool"
done

# Install Cask Applications only if on macOS
# NOTE(michaelfromyeg): this seems mostly fine to run on my work computer;
# ...most installations just fail due to pre-existing installations
if [ "$OS_TYPE" == "Darwin" ]; then
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
    antidote

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
  )

  # Install applications
  for app in "${APPS[@]}"; do
      echo "[brew] Installing $app..."
      brew install --cask "$app"
  done
fi

# Cleanup
echo "[brew] Cleaning up..."
brew cleanup

echo "[brew] Installation complete!"
echo "[brew] NOTE: Some applications may require additional setup or login."
echo "[brew] NOTE: Some applications might require system restart to complete installation."
echo "[brew] NOTE: Some applications might not be available in the Homebrew repository."

brew doctor
