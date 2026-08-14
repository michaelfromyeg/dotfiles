#!/usr/bin/env bash

# Bootstrap a fresh machine:
#   curl -fsSL https://raw.githubusercontent.com/michaelfromyeg/dotfiles/main/bootstrap.sh | bash
#
# Gets git, clones the repo to ~/code/dotfiles (the path the configs assume),
# syncs configs, and points you at the next steps.

set -euo pipefail

REPO="https://github.com/michaelfromyeg/dotfiles.git"
DEST="$HOME/code/dotfiles"

echo "[bootstrap] Starting..."

if ! command -v git >/dev/null 2>&1; then
  case "$(uname -s)" in
    Darwin*)
      echo "[bootstrap] git not found. Installing Xcode Command Line Tools (accept the dialog)..."
      xcode-select --install || true
      echo "[bootstrap] Re-run this script once the install finishes."
      exit 1
      ;;
    Linux*)
      echo "[bootstrap] Installing git via apt..."
      sudo apt-get update -qq && sudo apt-get install -y git
      ;;
    *)
      echo "[bootstrap] Unsupported platform: $(uname -s). Install git manually."
      exit 1
      ;;
  esac
fi

mkdir -p "$HOME/code"
if [ -d "$DEST/.git" ]; then
  echo "[bootstrap] Repo already cloned; pulling latest..."
  git -C "$DEST" pull --ff-only
else
  git clone "$REPO" "$DEST"
fi

chmod +x "$DEST/run.sh" "$DEST"/scripts/*.sh

echo "[bootstrap] Syncing configs (dotfiles env)..."
bash "$DEST/run.sh" env

echo "[bootstrap] Done. Next steps:"
echo "  dotfiles ui         # Homebrew + apps (installs Homebrew's deps from Brewfile)"
echo "  dotfiles languages  # language toolchains"
echo "  exec \$SHELL         # reload your shell"
