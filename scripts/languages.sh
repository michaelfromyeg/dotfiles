#!/usr/bin/env bash

# Installs programming language environments and tools

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
export PATH="/usr/local/go/bin:$PATH"

log "Starting installation of programming languages and tools"

# Rust
log "Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustup default stable
rustup component add rust-src rust-analyzer
cargo install cargo-edit cargo-watch

check_cmd rustc
check_cmd cargo

# Golang
log "Installing Golang..."
GO_VERSION="1.22.0"
wget "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
rm "go${GO_VERSION}.linux-amd64.tar.gz"
go install golang.org/x/tools/gopls@latest

check_cmd go
check_cmd gopls

# nvm (Node.js)
log "Installing Node.js via nvm..."
rm -rf "$HOME/.nvm"
mkdir -p "$HOME/.nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

nvm install lts/jod
nvm use lts/jod

check_cmd npm
check_cmd node

# uv (Python)
log "Installing uv for Python..."
curl -LsSf https://astral.sh/uv/install.sh | sh

check_cmd python3
check_cmd uv

# rvm (Ruby)
log "Installing Ruby via rvm..."
gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB || log "GPG key import failed, but continuing"
curl -sSL https://get.rvm.io | bash -s stable
source "$HOME/.rvm/scripts/rvm"
# rvm install ruby --latest
# rvm use ruby --latest --default

check_cmd ruby
check_cmd gem

# Language dependencies
log "Installing language-specific packages..."
npm install -g neovim @mermaid-js/mermaid-cli

uv pip install --system --break-system-packages pynvim
pipx install ghstack

gem install neovim

# Add this to generic shellrc
log "Adding environment variables to generic shellrc..."
SHELL_CONFIG="$HOME/.shellrc"

cat >> "$SHELL_CONFIG" << 'EOF'

# Added by programming languages setup script
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="/usr/local/go/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
EOF

log "Installation complete! Please restart your shell to apply changes."