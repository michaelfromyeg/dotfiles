#!/usr/bin/env bash

# Boxy init script — runs as root on first connection to a private boxy.
# Installs CLI tools that make the shell environment match the local setup.

set -euo pipefail

echo "[boxy-init] Setting up boxy environment..."

# --- apt packages ---
apt-get update -qq
apt-get install -y -qq \
  zsh \
  bat \
  fzf \
  ripgrep \
  fd-find \
  jq \
  direnv \
  curl \
  unzip \
  git

# Debian names the binaries differently
ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true
ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true

# --- tools not in bullseye repos ---

# eza (ls replacement)
if ! command -v eza &>/dev/null; then
  echo "[boxy-init] Installing eza..."
  curl -Lo /tmp/eza.tar.gz \
    "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz"
  tar xzf /tmp/eza.tar.gz -C /usr/local/bin/
  chmod +x /usr/local/bin/eza
  rm -f /tmp/eza.tar.gz
fi

# delta (git pager)
if ! command -v delta &>/dev/null; then
  echo "[boxy-init] Installing delta..."
  DELTA_VERSION=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest | jq -r .tag_name)
  curl -Lo /tmp/delta.deb \
    "https://github.com/dandavison/delta/releases/latest/download/git-delta_${DELTA_VERSION}_amd64.deb"
  dpkg -i /tmp/delta.deb || apt-get install -f -y -qq
  rm -f /tmp/delta.deb
fi

# zoxide (smarter cd)
if ! command -v zoxide &>/dev/null; then
  echo "[boxy-init] Installing zoxide..."
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | BIN_DIR=/usr/local/bin sh
fi

# oh-my-posh (prompt theme)
if ! command -v oh-my-posh &>/dev/null; then
  echo "[boxy-init] Installing oh-my-posh..."
  curl -s https://ohmyposh.dev/install.sh | bash -s
fi

# antidote (zsh plugin manager)
if [ ! -d /usr/local/share/antidote ]; then
  echo "[boxy-init] Installing antidote..."
  git clone --depth=1 https://github.com/mattmc3/antidote.git /usr/local/share/antidote
fi

# ghostty terminfo (so TERM=xterm-ghostty works over SSH)
if ! infocmp xterm-ghostty &>/dev/null; then
  echo "[boxy-init] Installing ghostty terminfo..."
  curl -sSfL https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/terminfo/ghostty.terminfo -o /tmp/ghostty.terminfo
  tic -x /tmp/ghostty.terminfo
  rm -f /tmp/ghostty.terminfo
fi

# --- shell default ---
if command -v zsh &>/dev/null; then
  chsh -s "$(command -v zsh)" 2>/dev/null || true
fi

echo "[boxy-init] Done!"
