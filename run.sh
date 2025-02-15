#!/usr/bin/env bash

# This is the generic harness for running each of my setup scripts.
# Usage: ./run.sh [filter] [--dry]

# This ensures that if this is run via symlink, we still get the correct path
if [[ -L "$0" ]]; then
    script_path=$(readlink -f "$0")
else
    script_path="$0"
fi

# The directory of this script
script_dir=$(cd "$(dirname "$script_path")" && pwd)

filter=""
dry="0"
args=()

while [[ $# -gt 0 ]]; do
  # Make this script dry
  if [[ $1 == "--dry" ]]; then
    dry="1"
  # Make the scripts this script runs dry
  elif [[ $1 == "--drier" ]]; then
    dry="2"
  elif [[ $1 == "--" ]]; then
    # Everything after this we pass through as arguments to the scripts
    shift
    while [[ $# -gt 0 ]]; do
      args+=("$1")
      shift
    done
    break
  else
    filter="$1"
  fi
  shift
done

export script_dir="$script_dir"
export dry="$dry"

echo "[dotfiles] Hello!"
echo "[dotfiles] (Make sure you chmod +x the scripts you want to run!)"

log() {
  if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
    echo "[dotfiles] [DRY_RUN] $*"
  else
    echo "[dotfiles] $*"
  fi
}

execute() {
  log "Executing... $*"

  if [[ $dry == "1" ]]; then
    return
  fi

  if [[ ${#args[@]} -gt 0 ]]; then
    "$@" "${args[@]}"
  else
    "$@"
  fi
}

log "$script_dir" -- "$filter"

cd "$script_dir"/scripts || exit

scripts=$(find . -maxdepth 1 -mindepth 1 -executable -type f)
for script in $scripts; do
  if echo "$script" | grep -qv "$filter"; then
    log "Skipped $script"
    continue
  fi

  # choose a unique color based on the script name
  color=$((31 + ($(echo "$script" | cksum | cut -d ' ' -f 1) % 6)))

  echo -e "\e[${color}m"
  execute "$script"
  echo -e "\e[0m"
done
