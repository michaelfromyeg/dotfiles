#!/usr/bin/env bash

# Installs programming language stuff.
# NOTE: you should probably run `env.sh` before running this script.

# rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

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
gem install neovim

npm install -g @mermaid-js/mermaid-cli
npm install -g @anthropic-ai/claude-code
