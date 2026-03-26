#!/usr/bin/env bash

# Sets up my development environment.

echo "[env] Setting up your environment..."

if [[ -z "$dry" ]] || [[ -z "$script_dir" ]]; then
  echo "[env] Error: Required variables 'dry' or 'script_dir' are not set"
  exit 1
fi

log() {
  if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
    echo "[env] [DRY_RUN] $*"
  else
    echo "[env] $*"
  fi
}

execute() {
  log "Executing... $*"

  if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
    return
  fi

  "$@"
}

copy_dirs() {
  from=$1
  to=$2

  log "Copying directories in $from to $to"

  pushd "$from" > /dev/null || exit

  # the 'sed' removes the './' from the beginning of the path
  dirs=$(find . -mindepth 1 -maxdepth 1 -type d | sed 's|^\./||')
  for dir in $dirs; do
    log "Copying the directory $from/$dir to $to"

    execute rm -rf "$to/$dir"
    execute cp -r "$from/$dir" "$to"
  done

  popd > /dev/null || exit
}

copy_file() {
  from=$1
  to=$2
  name=$(basename "$from")

  log "Copying the file $from to $to"

  execute rm "$to/$name"
  execute cp "$from" "$to"

}

# Copy config directories (nvim, bat, lazygit, ohmyposh, etc.)
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
execute mkdir -p "$config_home"
copy_dirs "$script_dir"/config "$config_home"

# Remove ghostty config on non-macOS (it's macOS-only)
if [[ "$(uname -s)" != "Darwin" ]]; then
  execute rm -rf "$config_home/ghostty"
fi

# the 'real' dotfiles
copy_file "$script_dir"/dotfiles/.shellrc "$HOME"
copy_file "$script_dir"/dotfiles/.zshrc "$HOME"
copy_file "$script_dir"/dotfiles/.zsh_plugins.txt "$HOME"
copy_file "$script_dir"/dotfiles/.bashrc "$HOME"
copy_file "$script_dir/dotfiles/.vimrc" "$HOME"
copy_file "$script_dir/dotfiles/.gitconfig" "$HOME"
copy_file "$script_dir/dotfiles/.tmux.conf" "$HOME"
copy_file "$script_dir/dotfiles/.ripgreprc" "$HOME"
copy_file "$script_dir/dotfiles/.gitignore_global" "$HOME"

# SSH config (managed portion — included by ~/.ssh/config)
execute mkdir -p "$HOME/.ssh"
execute chmod 700 "$HOME/.ssh"
copy_file "$script_dir/dotfiles/.ssh/config.local" "$HOME/.ssh"
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
    echo "Include config.local" > "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
  fi
fi

# setup vim and neovim
execute mkdir -p "$HOME/.vim"
execute mkdir -p "$HOME/.vim/undodir"
execute mkdir -p "$HOME/.config/nvim"
execute mkdir -p "$HOME/.local/share/nvim/site/autoload"

execute mkdir -p "$HOME/.vim/backup"
execute mkdir -p "$HOME/.vim/swap"
execute mkdir -p "$HOME/.local/share/nvim/backup"
execute mkdir -p "$HOME/.local/share/nvim/swap"

execute chmod 700 "$HOME/.vim" "$HOME/.config/nvim"
execute chmod 700 "$HOME/.vim/backup" "$HOME/.vim/swap" "$HOME/.vim/undodir"
execute chmod 700 "$HOME/.local/share/nvim/backup" "$HOME/.local/share/nvim/swap"

if [[ ! -f "$HOME/.vim/autoload/plug.vim" ]]; then
  log "Installing vim-plug for Vim"
  execute curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

log "Installing Vim plugins"
execute vim +PlugInstall +qall

# Claude Code user-level config (~/.claude/ is not XDG, so handled separately)
execute mkdir -p "$HOME/.claude"
execute mkdir -p "$HOME/.claude/skills"
copy_file "$script_dir/claude/settings.json" "$HOME/.claude"
copy_file "$script_dir/claude/statusline-command.sh" "$HOME/.claude"
copy_file "$script_dir/claude/CLAUDE.md" "$HOME/.claude"
if [ -d "$script_dir/claude/skills" ] && [ "$(ls -A "$script_dir/claude/skills" 2>/dev/null)" ]; then
  copy_dirs "$script_dir/claude/skills" "$HOME/.claude/skills"
fi

# make `run.sh` runnable from anywhere
execute mkdir -p "$HOME/bin"
execute ln -sf "$script_dir/run.sh" "$HOME/bin/dotfiles"

# Boxy remote dev profile (macOS only — synced to boxy containers from laptop)
if [[ "$(uname -s)" == "Darwin" ]]; then
  log "Setting up boxy profile..."

  boxy_dotfiles="$HOME/.boxy/profile/dotfiles"
  boxy_config="$boxy_dotfiles/.config"

  execute mkdir -p "$boxy_dotfiles"
  execute mkdir -p "$boxy_config"

  # Shell configs
  copy_file "$script_dir/dotfiles/.shellrc" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.zshrc" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.zsh_plugins.txt" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.bashrc" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.vimrc" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.gitconfig" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.ripgreprc" "$boxy_dotfiles"
  copy_file "$script_dir/dotfiles/.gitignore_global" "$boxy_dotfiles"

  # tmux.conf — append zsh as default shell for boxy sessions
  copy_file "$script_dir/dotfiles/.tmux.conf" "$boxy_dotfiles"
  if [[ $dry != "1" ]] && [[ $dry != "2" ]]; then
    printf '\n# Boxy: use zsh as default shell\nset-option -g default-shell /usr/bin/zsh\n' >> "$boxy_dotfiles/.tmux.conf"
  fi

  # App configs (skip ghostty — macOS-only terminal)
  for dir in bat git lazygit nvim ohmyposh; do
    if [ -d "$script_dir/config/$dir" ]; then
      execute rm -rf "$boxy_config/$dir"
      execute cp -r "$script_dir/config/$dir" "$boxy_config"
    fi
  done

  # Boxy init script
  execute cp "$script_dir/boxy/init.sh" "$HOME/.boxy/profile/init.sh"
  execute chmod +x "$HOME/.boxy/profile/init.sh"
fi
