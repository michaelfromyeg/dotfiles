#!/usr/bin/env bash

# Installs programming language environments and tools
# This script is idempotent - safe to run multiple times

set -e

log() {
  if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
    echo "[languages] [DRY_RUN] $*"
  else
    echo "[languages] $*"
  fi
}

check_cmd() {
  if ! command -v "$1" &> /dev/null; then
    log "$1 not found"
    return 1
  else
    log "$1 $(command -v "$1")"
    return 0
  fi
}

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
# Only add /usr/local/go/bin on Linux (manual install location)
# On macOS, Homebrew manages Go in /opt/homebrew/bin or /usr/local/bin
if [[ "$(uname -s)" != "Darwin" ]]; then
  export PATH="/usr/local/go/bin:$PATH"
fi

log "Starting installation of programming languages and tools"

# PowerShell (macOS only)
if [[ $(uname) == "Darwin" ]]; then
  brew install --cask powershell || true
  check_cmd pwsh
fi

# Rust
log "Installing Rust..."
if [ -f "$HOME/.cargo/env" ]; then
  source "$HOME/.cargo/env"
  log "Rust already installed, updating..."
  rustup update stable
else
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
fi
rustup default stable
rustup component add rust-src rust-analyzer
cargo install cargo-edit cargo-watch || true

check_cmd rustc
check_cmd cargo

# Golang (cross-platform)
log "Installing Golang..."
GO_VERSION="1.23.4"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
esac

if [[ "$OS" == "darwin" ]]; then
  brew install go || brew upgrade go || true
else
  if ! command -v go &> /dev/null || [[ "$(go version 2>/dev/null)" != *"$GO_VERSION"* ]]; then
    wget -q "https://go.dev/dl/go${GO_VERSION}.${OS}-${ARCH}.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "go${GO_VERSION}.${OS}-${ARCH}.tar.gz"
    rm "go${GO_VERSION}.${OS}-${ARCH}.tar.gz"
  else
    log "Go $GO_VERSION already installed"
  fi
fi
go install golang.org/x/tools/gopls@latest

check_cmd go
check_cmd gopls

# nvm (Node.js)
log "Installing Node.js via nvm..."
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  mkdir -p "$NVM_DIR"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
else
  log "nvm already installed"
fi

[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

nvm install --lts
nvm use --lts

check_cmd npm
check_cmd node

# uv (Python)
log "Installing uv for Python..."
if ! command -v uv &> /dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
else
  log "uv already installed, upgrading..."
  uv self update || true
fi

check_cmd python3
check_cmd uv

# SDKMAN (Java, Kotlin, Gradle)
# Note: requires release-assets.githubusercontent.com to be accessible
# If blocked by DNS, add to /etc/hosts: 185.199.108.133 release-assets.githubusercontent.com
log "Installing Java, Kotlin, and Gradle via SDKMAN..."

export SDKMAN_DIR="$HOME/.sdkman"

if [ ! -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
  log "Installing SDKMAN..."
  curl -s "https://get.sdkman.io?rcupdate=false" | bash
fi

if [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
  source "$SDKMAN_DIR/bin/sdkman-init.sh"

  # sdk install is idempotent - skips if already installed
  sdk install java || true
  sdk install gradle || true
  sdk install kotlin || true

  check_cmd java
  check_cmd gradle
  check_cmd kotlin
else
  log "SDKMAN installation failed - skipping Java/Gradle/Kotlin"
fi

# asdf + Erlang/Elixir
log "Installing Erlang and Elixir via asdf..."

# Install build dependencies for Erlang (required for compiling from source)
# Only install if not already present (check for key dependency: libncurses-dev)
if [[ "$(uname -s)" == "Linux" ]]; then
  if ! dpkg -s libncurses-dev &>/dev/null; then
    log "Installing Erlang build dependencies..."
    # Core build tools and libraries required by asdf-erlang
    # See: https://github.com/asdf-vm/asdf-erlang#ubuntu-2404-lts
    sudo apt-get update -qq
    sudo apt-get install -y \
      build-essential \
      autoconf \
      m4 \
      libncurses-dev \
      libssl-dev \
      libwxgtk3.2-dev libwxgtk-webview3.2-dev \
      libgl1-mesa-dev libglu1-mesa-dev \
      libpng-dev \
      libssh-dev \
      unixodbc-dev \
      xsltproc fop libxml2-utils \
      2>/dev/null || {
        # Fallback for older Ubuntu versions with wxWidgets 3.0
        log "Trying fallback dependencies for older Ubuntu..."
        sudo apt-get install -y \
          build-essential autoconf m4 \
          libncurses5-dev libncurses-dev \
          libssl-dev \
          libwxgtk3.0-gtk3-dev libwxgtk-webview3.0-gtk3-dev \
          libgl1-mesa-dev libglu1-mesa-dev \
          libpng-dev libssh-dev unixodbc-dev \
          xsltproc fop libxml2-utils \
          2>/dev/null || log "Some optional dependencies may not be available"
      }
  else
    log "Erlang build dependencies already installed"
  fi
fi

if [ ! -d "$HOME/.asdf" ]; then
  git clone https://github.com/asdf-vm/asdf.git "$HOME/.asdf" --branch v0.14.1
fi
source "$HOME/.asdf/asdf.sh"

asdf plugin add erlang || true
asdf plugin add elixir || true

# Install Erlang (skip if already installed - compilation takes 15+ minutes)
ERLANG_VERSION=$(asdf latest erlang)
INSTALLED_ERLANG=$(asdf current erlang 2>/dev/null | awk '{print $2}')
if [ "$INSTALLED_ERLANG" != "$ERLANG_VERSION" ]; then
  log "Installing Erlang $ERLANG_VERSION (this takes 15+ minutes)..."
  asdf install erlang "$ERLANG_VERSION" || true
  asdf global erlang "$ERLANG_VERSION" || true
else
  log "Erlang $ERLANG_VERSION already installed"
fi

# Get installed Erlang OTP version for Elixir compatibility
OTP_VERSION=$(asdf current erlang 2>/dev/null | awk '{print $2}' | cut -d. -f1)
if [ -n "$OTP_VERSION" ]; then
  # Find latest Elixir compatible with installed OTP version
  ELIXIR_VERSION=$(asdf list all elixir | grep -E "^[0-9]+\.[0-9]+\.[0-9]+-otp-${OTP_VERSION}$" | tail -1)
  INSTALLED_ELIXIR=$(asdf current elixir 2>/dev/null | awk '{print $2}')
  if [ "$INSTALLED_ELIXIR" = "$ELIXIR_VERSION" ]; then
    log "Elixir $ELIXIR_VERSION already installed"
  elif [ -n "$ELIXIR_VERSION" ]; then
    log "Installing Elixir $ELIXIR_VERSION (compatible with OTP $OTP_VERSION)..."
    asdf install elixir "$ELIXIR_VERSION" || true
    asdf global elixir "$ELIXIR_VERSION" || true
  else
    log "No Elixir version found for OTP $OTP_VERSION, trying latest..."
    asdf install elixir latest || true
    asdf global elixir latest || true
  fi
else
  log "Erlang not installed, skipping Elixir..."
fi

check_cmd erl
check_cmd elixir
check_cmd mix

# rvm (Ruby)
log "Installing Ruby via rvm..."
if [ ! -d "$HOME/.rvm" ]; then
  gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB || log "GPG key import failed, but continuing"
  curl -sSL https://get.rvm.io | bash -s stable
fi

if [ -s "$HOME/.rvm/scripts/rvm" ]; then
  source "$HOME/.rvm/scripts/rvm"

  # Check if ruby is installed, install if not
  if ! rvm list | grep -q ruby; then
    rvm install ruby --latest
  fi
  rvm use ruby --latest --default || true

  check_cmd ruby
  check_cmd gem
else
  log "rvm installation failed - skipping Ruby"
fi

# Lua (for neovim plugins)
log "Installing Lua and LuaRocks..."
if [[ "$(uname -s)" == "Darwin" ]]; then
  brew install lua luarocks || true
else
  # Check if already installed
  if ! command -v lua &>/dev/null; then
    sudo apt-get install -y lua5.4 luarocks 2>/dev/null || brew install lua luarocks || true
  else
    log "Lua already installed"
  fi
fi

check_cmd lua
check_cmd luarocks

# Language dependencies for neovim
log "Installing language-specific packages..."
npm install -g neovim @mermaid-js/mermaid-cli typescript typescript-language-server || true

uv pip install --system --break-system-packages pynvim || true

# Graphite CLI for stacked PRs
npm install -g @withgraphite/graphite-cli || true

gem install neovim || true

luarocks install --local luacheck || true

# Install Elixir LSP
mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new --force || true

log "Installation complete! Please restart your shell to apply changes."
