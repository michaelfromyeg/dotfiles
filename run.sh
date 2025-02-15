#!/usr/bin/env bash

# This is the generic harness for running each of my setup scripts.
# Usage: ./run.sh [filter] [--dry]

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
filter=""
dry="0"

while [[ $# -gt 0 ]]; do
  if [[ $1 == "--dry" ]]; then
    dry="1"
  else
    filter="$1"
  fi
  shift
done

echo "[dotfiles] Hello!"
echo "[dotfiles] (Make sure you chmod +x the scripts you want to run!)"

log() {
  if [[ $dry == "1" ]]; then
    echo "[dotfiles] [DRY_RUN] $*"
  else
    echo "[dotfiles] $*"
  fi
}

execute() {
  log "$@"
  if [[ $dry == "1" ]]; then
    return
  fi
  "$@"
}

log "$script_dir" -- "$filter"

cd "$script_dir"/scripts || exit

scripts=$(find . -maxdepth 1 -mindepth 1 -executable -type f)
for script in $scripts; do
  if echo "$script" | grep -qv "$filter"; then
    log "Skipped $script"
    continue
  fi

  execute "$script"
done
