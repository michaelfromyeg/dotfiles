#!/usr/bin/env bash

# Boxy init script — runs as root on first connection to a private boxy.
# Installs CLI tools that make the shell environment match the local setup.

set -euo pipefail

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
RESET='\033[0m'

LOGFILE="/tmp/boxy-init.log"
: > "$LOGFILE"

step() {
  local label="$1"
  shift
  printf "  ${DIM}...${RESET} %s" "$label"
  if "$@" >> "$LOGFILE" 2>&1; then
    printf "\r  ${GREEN}ok${RESET}  %s\n" "$label"
  else
    printf "\r  ${RED}ERR${RESET} %s ${DIM}(see $LOGFILE)${RESET}\n" "$label"
    return 1
  fi
}

skip() {
  printf "  ${YELLOW}--${RESET}  %s ${DIM}(already installed)${RESET}\n" "$1"
}

echo ""
printf "${BOLD}boxy-init${RESET}\n"
echo ""

# --- apt packages ---
step "apt packages" bash -c '
  apt-get update -qq &&
  apt-get install -y -qq \
    zsh bat fzf ripgrep fd-find jq direnv curl unzip git
'

# Debian names the binaries differently
ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true
ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true

# --- tools not in bullseye repos ---

# yq (YAML processor — needed by notion CLI for .devex.config.yaml)
if ! command -v yq &>/dev/null; then
  step "yq" bash -c '
    curl -sSLo /usr/local/bin/yq \
      "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" &&
    chmod +x /usr/local/bin/yq
  '
else
  skip "yq"
fi

# eza (ls replacement)
if ! command -v eza &>/dev/null; then
  step "eza" bash -c '
    curl -sSLo /tmp/eza.tar.gz \
      "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz" &&
    tar xzf /tmp/eza.tar.gz -C /usr/local/bin/ &&
    chmod +x /usr/local/bin/eza &&
    rm -f /tmp/eza.tar.gz
  '
else
  skip "eza"
fi

# delta (git pager) — use musl build to avoid glibc version issues on Bullseye
if ! command -v delta &>/dev/null; then
  step "delta" bash -c '
    curl -sSLo /tmp/delta.tar.gz \
      "https://github.com/dandavison/delta/releases/latest/download/delta-$(curl -sS https://api.github.com/repos/dandavison/delta/releases/latest | jq -r .tag_name)-x86_64-unknown-linux-musl.tar.gz" &&
    tar xzf /tmp/delta.tar.gz -C /tmp/ &&
    mv /tmp/delta-*-x86_64-unknown-linux-musl/delta /usr/local/bin/delta &&
    chmod +x /usr/local/bin/delta &&
    rm -rf /tmp/delta.tar.gz /tmp/delta-*-x86_64-unknown-linux-musl
  '
else
  skip "delta"
fi

# zoxide (smarter cd)
if ! command -v zoxide &>/dev/null; then
  step "zoxide" bash -c '
    export BIN_DIR=/usr/local/bin &&
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
  '
else
  skip "zoxide"
fi

# oh-my-posh (prompt theme)
if ! command -v oh-my-posh &>/dev/null; then
  step "oh-my-posh" bash -c '
    curl -sS https://ohmyposh.dev/install.sh | bash -s -- -d /usr/local/bin
  '
else
  skip "oh-my-posh"
fi

# antidote (zsh plugin manager)
if [ ! -d /usr/local/share/antidote ]; then
  step "antidote" git clone -q --depth=1 https://github.com/mattmc3/antidote.git /usr/local/share/antidote
else
  skip "antidote"
fi

# --- dotfiles ---
DOTFILES_DIR="/home/notion/code/dotfiles"
if [ ! -d "$DOTFILES_DIR" ]; then
  step "clone dotfiles" bash -c "sudo -u notion git clone -q https://github.com/michaelfromyeg/dotfiles.git '$DOTFILES_DIR'" || true
fi
if [ -f "$DOTFILES_DIR/run.sh" ]; then
  mkdir -p /home/notion/bin
  ln -sf "$DOTFILES_DIR/run.sh" /home/notion/bin/dotfiles
  chown -R notion:notion /home/notion/bin
  step "dotfiles env" sudo -u notion bash "$DOTFILES_DIR/run.sh" env
fi

# ghostty terminfo (so TERM=xterm-ghostty works over SSH)
if ! infocmp xterm-ghostty &>/dev/null 2>&1; then
  step "ghostty terminfo" tic -x "$DOTFILES_DIR/config/ghostty/xterm-ghostty.terminfo" || true
else
  skip "ghostty terminfo"
fi

# --- notion-next ---
# GH_TOKEN was written to ~notion/.ssh/environment before this script runs,
# but sudo doesn't inherit it. Source it explicitly so git can authenticate.
if [ -d /work/notion-next ]; then
  NOTION_SSH_ENV="/home/notion/.ssh/environment"
  GH_ENV=""
  if [ -f "$NOTION_SSH_ENV" ]; then
    GH_ENV=$(grep '^GH_TOKEN=' "$NOTION_SSH_ENV" | tail -1) || true
  fi
  step "notion-next" bash -c "
    sudo -u notion env $GH_ENV git -C /work/notion-next fetch origin --prune -q &&
    sudo -u notion env $GH_ENV git -C /work/notion-next pull --ff-only -q
  " || true
fi

# --- shell default ---
if command -v zsh &>/dev/null; then
  chsh -s "$(command -v zsh)" 2>/dev/null || true
fi

echo ""
printf "${GREEN}${BOLD}ready${RESET}\n"
echo ""
