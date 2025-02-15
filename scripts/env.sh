#!/usr/bin/env bash

# Sets up my development environment. Should only be called via the run.sh script.

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

# covers neovim, ...
copy_dirs "$script_dir"/config "$XDG_CONFIG_HOME"

# the 'real' dotfiles
copy_file "$script_dir"/dotfiles/.bashrc "$HOME"
copy_file "$script_dir/dotfiles/.vimrc" "$HOME"
copy_file "$script_dir/dotfiles/.gitconfig" "$HOME"

# make `run.sh` runnable from anywhere\
mkdir -p ~/bin
execute ln -sf "$script_dir/run.sh" "$HOME/bin/dotfiles"

if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
    fi
fi
