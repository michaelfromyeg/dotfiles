#!/usr/bin/env bash

# Installs programming language stuff.
# NOTE: you should probably run `env.sh` before running this script.

# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustup default stable
rustup component add rust-src
rustup component add rust-analyzer
cargo install cargo-edit
cargo install cargo-watch

rustc --version
cargo --version

# Golang
GO_VERSION="1.22.0"
wget "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
rm "go${GO_VERSION}.linux-amd64.tar.gz"

export PATH="/usr/local/go/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"

go version
go install golang.org/x/tools/gopls@latest


# nvm (Node.js)
rm -rf "$HOME/.nvm"
mkdir -p "$HOME/.nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

nvm install lts/jod
nvm use lts/jod

npm -v
node -v

# uv (Python)
curl -LsSf https://astral.sh/uv/install.sh | sh

export PATH="$HOME/.local/bin:$PATH"

python3 --version
uv --version

# rvm (Ruby)
curl -sSL https://get.rvm.io | bash -s stable

# Language dependencies
npm install -g neovim

uv pip install --system --break-system-packages pynvim
pipx install ghstack

gem install neovim

npm install -g @mermaid-js/mermaid-cli
