#!/usr/bin/env bash

# Installs programming language environments and tools
# This script is idempotent - safe to run multiple times

set -e

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

# The installers below run unconditionally, so honor dry-run up front.
if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
  log "would install/update language toolchains (rust, go, node, etc.)"
  exit 0
fi

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
  # The stable powershell cask was removed from Homebrew; fall back to preview.
  brew install --cask powershell || brew install --cask powershell@preview || true
  # powershell@preview installs its binary as pwsh-preview
  check_cmd pwsh || check_cmd pwsh-preview || true
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

check_cmd rustc || true
check_cmd cargo || true

# Golang (cross-platform)
log "Installing Golang..."
GO_VERSION="1.23.4"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64 | arm64) ARCH="arm64" ;;
esac

if [[ "$OS" == "darwin" ]]; then
  brew install go || brew upgrade go || true
else
  if ! command -v go &>/dev/null || [[ "$(go version 2>/dev/null)" != *"$GO_VERSION"* ]]; then
    wget -q "https://go.dev/dl/go${GO_VERSION}.${OS}-${ARCH}.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "go${GO_VERSION}.${OS}-${ARCH}.tar.gz"
    rm "go${GO_VERSION}.${OS}-${ARCH}.tar.gz"
  else
    log "Go $GO_VERSION already installed"
  fi
fi
go install golang.org/x/tools/gopls@latest

check_cmd go || true
check_cmd gopls || true

# mise: Node, Erlang, Elixir and Ruby. Versions live in config/mise/config.toml
# (synced to ~/.config/mise by `dotfiles env`); point mise at the repo copy so
# this works even before env has run.
log "Installing Node, Erlang, Elixir and Ruby via mise..."
if ! command -v mise &>/dev/null; then
  if command -v brew &>/dev/null; then
    brew install mise
  else
    # Installs to ~/.local/bin, which is on PATH above
    curl -fsSL https://mise.run | sh
  fi
else
  log "mise already installed"
fi

# Erlang compiles from source where no prebuilt exists (Linux); install its build deps.
if [[ "$(uname -s)" == "Linux" ]] && ! dpkg -s libncurses-dev &>/dev/null; then
  log "Installing Erlang build dependencies..."
  sudo apt-get update -qq
  sudo apt-get install -y build-essential autoconf m4 libncurses-dev libssl-dev \
    libwxgtk3.2-dev libwxgtk-webview3.2-dev libgl1-mesa-dev libglu1-mesa-dev \
    libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libyaml-dev \
    2>/dev/null || log "Some optional Erlang build dependencies may not be available"
fi

repo_root="${script_dir:-$(cd "$(dirname "$0")/.." && pwd)}"
MISE_GLOBAL_CONFIG_FILE="$repo_root/config/mise/config.toml" mise install
export PATH="$HOME/.local/share/mise/shims:$PATH"

check_cmd node || true
check_cmd npm || true
check_cmd erl || true
check_cmd elixir || true
check_cmd mix || true
check_cmd ruby || true
check_cmd gem || true

# uv (Python)
log "Installing uv for Python..."
if ! command -v uv &>/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
else
  log "uv already installed, upgrading..."
  uv self update || true
fi

check_cmd python3 || true
check_cmd uv || true

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

  check_cmd java || true
  check_cmd gradle || true
  check_cmd kotlin || true
else
  log "SDKMAN installation failed - skipping Java/Gradle/Kotlin"
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

check_cmd lua || true
check_cmd luarocks || true

# Language dependencies for neovim
log "Installing language-specific packages..."
npm install -g neovim @mermaid-js/mermaid-cli typescript typescript-language-server || true

uv pip install --system --break-system-packages pynvim || true

gem install neovim || true

luarocks install --local luacheck || true

# Install Elixir LSP
mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new --force || true

log "Installation complete! Please restart your shell to apply changes."
