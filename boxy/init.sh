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

# delta (git pager) — use musl build to avoid glibc version issues on Bullseye
if ! command -v delta &>/dev/null; then
  echo "[boxy-init] Installing delta..."
  curl -Lo /tmp/delta.tar.gz \
    "https://github.com/dandavison/delta/releases/latest/download/delta-$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest | jq -r .tag_name)-x86_64-unknown-linux-musl.tar.gz"
  tar xzf /tmp/delta.tar.gz -C /tmp/
  mv /tmp/delta-*-x86_64-unknown-linux-musl/delta /usr/local/bin/delta
  chmod +x /usr/local/bin/delta
  rm -rf /tmp/delta.tar.gz /tmp/delta-*-x86_64-unknown-linux-musl
fi

# zoxide (smarter cd)
if ! command -v zoxide &>/dev/null; then
  echo "[boxy-init] Installing zoxide..."
  export BIN_DIR=/usr/local/bin
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
fi

# oh-my-posh (prompt theme)
if ! command -v oh-my-posh &>/dev/null; then
  echo "[boxy-init] Installing oh-my-posh..."
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d /usr/local/bin
fi

# antidote (zsh plugin manager)
if [ ! -d /usr/local/share/antidote ]; then
  echo "[boxy-init] Installing antidote..."
  git clone --depth=1 https://github.com/mattmc3/antidote.git /usr/local/share/antidote
fi

# ghostty terminfo (so TERM=xterm-ghostty works over SSH)
# Ghostty handles this automatically via shell-integration-features = ssh-terminfo
# but we install it here as a fallback
if ! infocmp xterm-ghostty &>/dev/null; then
  echo "[boxy-init] Installing ghostty terminfo..."
  curl -sSfL https://github.com/ghostty-org/ghostty/raw/main/src/terminfo/ghostty.terminfo -o /tmp/ghostty.terminfo \
    && tic -x /tmp/ghostty.terminfo \
    && rm -f /tmp/ghostty.terminfo \
    || echo "[boxy-init] ghostty terminfo install failed (non-fatal), enable ssh-terminfo in Ghostty config instead"
fi

# --- dotfiles ---
DOTFILES_DIR="/home/notion/code/dotfiles"
if [ ! -d "$DOTFILES_DIR" ]; then
  echo "[boxy-init] Cloning dotfiles..."
  sudo -u notion git clone https://github.com/michaelfromyeg/dotfiles.git "$DOTFILES_DIR" 2>/dev/null || true
fi
if [ -f "$DOTFILES_DIR/run.sh" ]; then
  mkdir -p /home/notion/bin
  ln -sf "$DOTFILES_DIR/run.sh" /home/notion/bin/dotfiles
  chown -R notion:notion /home/notion/bin
fi

# --- shell default ---
if command -v zsh &>/dev/null; then
  chsh -s "$(command -v zsh)" 2>/dev/null || true
fi

echo "[boxy-init] Done!"
