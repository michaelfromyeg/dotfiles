#!/usr/bin/env bash

# Sets up my development environment.

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

log "Setting up your environment..."

if [[ -z "$script_dir" ]]; then
  log "Error: Required variable 'script_dir' is not set"
  exit 1
fi

# Back up anything we're about to overwrite, preserving its path relative to
# $HOME, so a bad sync (or a machine with hand-written configs) is recoverable.
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

backup() {
  target=$1
  [ -e "$target" ] || return 0
  if [[ $dry != "1" ]] && [[ $dry != "2" ]]; then
    dest="$BACKUP_DIR/${target#"$HOME"/}"
    mkdir -p "$(dirname "$dest")"
    cp -a "$target" "$dest"
  fi
}

copy_dirs() {
  from=$1
  to=$2

  log "Copying directories in $from to $to"

  pushd "$from" >/dev/null || exit

  # the 'sed' removes the './' from the beginning of the path
  dirs=$(find . -mindepth 1 -maxdepth 1 -type d | sed 's|^\./||')
  for dir in $dirs; do
    log "Copying the directory $from/$dir to $to"

    backup "$to/$dir"
    run_cmd rm -rf "$to/$dir"
    run_cmd cp -r "$from/$dir" "$to"
  done

  popd >/dev/null || exit
}

SYNCED_FILES=()

copy_file() {
  from=$1
  to=$2
  name=$(basename "$from")

  # Track relative path from script_dir for sync check
  SYNCED_FILES+=("${from#"$script_dir"/}")

  log "Copying the file $from to $to"

  backup "$to/$name"
  run_cmd rm -f "$to/$name"
  run_cmd cp "$from" "$to"

}

# Copy config directories (nvim, bat, lazygit, ohmyposh, etc.)
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
run_cmd mkdir -p "$config_home"
copy_dirs "$script_dir"/config "$config_home"

# Remove ghostty config on non-macOS (it's macOS-only)
if [[ "$(uname -s)" != "Darwin" ]]; then
  run_cmd rm -rf "$config_home/ghostty"
fi

# the 'real' dotfiles
copy_file "$script_dir"/dotfiles/.shellrc "$HOME"
copy_file "$script_dir"/dotfiles/.zshrc "$HOME"
copy_file "$script_dir"/dotfiles/.zsh_plugins.txt "$HOME"
copy_file "$script_dir"/dotfiles/.bashrc "$HOME"
copy_file "$script_dir"/dotfiles/.bash_profile "$HOME"
copy_file "$script_dir/dotfiles/.vimrc" "$HOME"
copy_file "$script_dir/dotfiles/.gitconfig" "$HOME"
copy_file "$script_dir/dotfiles/.gitconfig-notion" "$HOME"
copy_file "$script_dir/dotfiles/.tmux.conf" "$HOME"
copy_file "$script_dir/dotfiles/.ripgreprc" "$HOME"
copy_file "$script_dir/dotfiles/.gitignore_global" "$HOME"

# SSH config (managed portion — included by ~/.ssh/config)
run_cmd mkdir -p "$HOME/.ssh"
run_cmd chmod 700 "$HOME/.ssh"
run_cmd mkdir -p "$HOME/.ssh/sockets" # ControlPath dir (see config.local)
copy_file "$script_dir/dotfiles/.ssh/config.local" "$HOME/.ssh"
run_cmd chmod 600 "$HOME/.ssh/config.local"
if [ -f "$HOME/.ssh/config" ]; then
  if ! grep -q "Include config.local" "$HOME/.ssh/config"; then
    log "Adding Include config.local to ~/.ssh/config"
    if [[ $dry != "1" ]] && [[ $dry != "2" ]]; then
      sed -i.bak '1s/^/Include config.local\n\n/' "$HOME/.ssh/config"
      rm -f "$HOME/.ssh/config.bak"
    fi
  fi
else
  log "Creating ~/.ssh/config with Include"
  if [[ $dry != "1" ]] && [[ $dry != "2" ]]; then
    echo "Include config.local" >"$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
  fi
fi

# setup vim and neovim
run_cmd mkdir -p "$HOME/.vim"
run_cmd mkdir -p "$HOME/.vim/undodir"
run_cmd mkdir -p "$HOME/.config/nvim"
run_cmd mkdir -p "$HOME/.local/share/nvim/site/autoload"

run_cmd mkdir -p "$HOME/.vim/backup"
run_cmd mkdir -p "$HOME/.vim/swap"
run_cmd mkdir -p "$HOME/.local/share/nvim/backup"
run_cmd mkdir -p "$HOME/.local/share/nvim/swap"

run_cmd chmod 700 "$HOME/.vim" "$HOME/.config/nvim"
run_cmd chmod 700 "$HOME/.vim/backup" "$HOME/.vim/swap" "$HOME/.vim/undodir"
run_cmd chmod 700 "$HOME/.local/share/nvim/backup" "$HOME/.local/share/nvim/swap"

if [[ ! -f "$HOME/.vim/autoload/plug.vim" ]]; then
  log "Installing vim-plug for Vim"
  run_cmd curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

log "Installing Vim plugins"
run_cmd vim +PlugInstall +qall

# Claude Code user-level config (~/.claude/ is not XDG, so handled separately)
run_cmd mkdir -p "$HOME/.claude"
run_cmd mkdir -p "$HOME/.claude/skills"
copy_file "$script_dir/claude/settings.json" "$HOME/.claude"
copy_file "$script_dir/claude/statusline-command.sh" "$HOME/.claude"
copy_file "$script_dir/claude/CLAUDE.md" "$HOME/.claude"
if [ -d "$script_dir/claude/skills" ] && [ "$(ls -A "$script_dir/claude/skills" 2>/dev/null)" ]; then
  copy_dirs "$script_dir/claude/skills" "$HOME/.claude/skills"
fi

# Install the Claude Code plugins declared in settings.json (no-op if the
# claude CLI isn't present yet, e.g. early in a fresh Boxy provision).
run_cmd bash "$script_dir/scripts/claude-plugins.sh"

# Windows Terminal settings (WSL only — push config to Windows filesystem)
if grep -qi microsoft /proc/version 2>/dev/null; then
  win_user=$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r')
  wt_settings="/mnt/c/Users/$win_user/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
  if [[ -d "$(dirname "$wt_settings")" ]]; then
    log "Syncing Windows Terminal settings..."
    copy_file "$script_dir/dotfiles/windows-terminal.json" "$(dirname "$wt_settings")"
    # Windows Terminal expects settings.json, not windows-terminal.json
    run_cmd mv "$(dirname "$wt_settings")/windows-terminal.json" "$wt_settings"
  else
    log "Windows Terminal settings directory not found, skipping"
  fi

fi

# make `run.sh` runnable from anywhere
run_cmd mkdir -p "$HOME/bin"
run_cmd ln -sf "$script_dir/run.sh" "$HOME/bin/dotfiles"

# Claude Desktop MCP servers (WSL and macOS)
SYNCED_FILES+=("claude/desktop-mcp-servers.json")
python3 "$script_dir/scripts/sync-claude-desktop.py"

# notion-next plan-mode override fragment: not deployed to $HOME — boxy/init.sh
# deep-merges it into /work/notion-next/.claude/settings.local.json on boxies.
SYNCED_FILES+=("claude/notion-next.settings.local.json")

# Windows Terminal settings only deploy on WSL; don't warn about them elsewhere.
SYNCED_FILES+=("dotfiles/windows-terminal.json")

# Cold Turkey block lists are imported manually via the app's UI, not deployed.
SYNCED_FILES+=("dotfiles/cold-turkey-block-lists.ctbbl")

# Boxy remote dev profile (macOS only — synced to boxy containers from laptop)
if [[ "$(uname -s)" == "Darwin" ]]; then
  log "Setting up boxy profile..."

  boxy_dotfiles="$HOME/.boxy/profile/dotfiles"
  boxy_config="$boxy_dotfiles/.config"

  run_cmd mkdir -p "$boxy_dotfiles"
  run_cmd mkdir -p "$boxy_config"

  # Shell configs
  copy_file "$script_dir/dotfiles/.shellrc" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.zshrc" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.zsh_plugins.txt" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.bashrc" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.bash_profile" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.vimrc" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.gitconfig" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.gitconfig-notion" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.ripgreprc" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.gitignore_global" "$boxy_dotfiles"

  # tmux.conf — append zsh as default shell for boxy sessions
  copy_file "$script_dir/dotfiles/.tmux.conf" "$boxy_dotfiles"
  if [[ $dry != "1" ]] && [[ $dry != "2" ]]; then
    printf '\n# Boxy: use zsh as default shell\nset-option -g default-shell /usr/bin/zsh\n' >>"$boxy_dotfiles/.tmux.conf"
  fi

  # App configs (skip ghostty — macOS-only terminal)
  for dir in bat git lazygit nvim ohmyposh; do
    if [ -d "$script_dir/config/$dir" ]; then
      run_cmd rm -rf "$boxy_config/$dir"
      run_cmd cp -r "$script_dir/config/$dir" "$boxy_config"
    fi
  done

  # Claude Code config
  boxy_claude="$boxy_dotfiles/.claude"
  run_cmd mkdir -p "$boxy_claude"
  copy_file "$script_dir/claude/CLAUDE.md" "$boxy_claude"
  copy_file "$script_dir/claude/settings.json" "$boxy_claude"

  # Boxy init script
  run_cmd cp "$script_dir/boxy/init.sh" "$HOME/.boxy/profile/init.sh"
  run_cmd chmod +x "$HOME/.boxy/profile/init.sh"
fi

# === Sync check: warn about files not handled by this script ===

WARN_YELLOW='\033[0;33m'
WARN_NC='\033[0m'
unsynced=0

for dir in dotfiles claude; do
  [[ ! -d "$script_dir/$dir" ]] && continue
  while IFS= read -r file; do
    rel="$dir/$file"
    skip=false
    for synced in "${SYNCED_FILES[@]}"; do
      [[ "$synced" == "$rel" ]] && skip=true && break
    done
    if ! $skip; then
      if [[ $unsynced -eq 0 ]]; then
        echo ""
        echo -e "${WARN_YELLOW}[env] Warning: the following files are not synced by env.sh:${WARN_NC}"
      fi
      echo -e "${WARN_YELLOW}  - $rel${WARN_NC}"
      unsynced=$((unsynced + 1))
    fi
  done < <(cd "$script_dir/$dir" && find . -type f | sed 's|^\./||' | sort)
done

if [[ $unsynced -gt 0 ]]; then
  echo -e "${WARN_YELLOW}[env] Add a copy_file call to env.sh for each, or remove them.${WARN_NC}"
fi

if [ -d "$BACKUP_DIR" ]; then
  log "Overwritten files backed up to $BACKUP_DIR"
fi
