#!/usr/bin/env bash

# Installs CLI tools and GUI applications from the Brewfile via `brew bundle`.
# The package list lives in Brewfile at the repo root; casks are macOS-only.

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

repo_root="${script_dir:-$(cd "$(dirname "$0")/.." && pwd)}"

if ! command -v brew &>/dev/null; then
  log "Homebrew is not installed. Install it first: https://brew.sh"
  exit 1
fi

if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
  log "would run: brew bundle --file=$repo_root/Brewfile"
  exit 0
fi

log "Updating Homebrew..."
HOMEBREW_NO_AUTO_UPDATE=1 brew update

log "Installing from Brewfile..."
brew bundle --file="$repo_root/Brewfile"

log "Cleaning up..."
brew cleanup

log "Done. Some apps may need a login or restart."
log "Audit drift with: brew bundle cleanup --file=$repo_root/Brewfile"
