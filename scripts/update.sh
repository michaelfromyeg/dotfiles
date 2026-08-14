#!/usr/bin/env bash

# Updates everything you can update on your system.

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

log "Running system updates..."

if command -v apt &>/dev/null; then
  run_cmd sudo apt update &&
    run_cmd sudo apt -y upgrade
  run_cmd sudo apt -y dist-upgrade
  run_cmd sudo apt -y autoremove
fi

if command -v brew &>/dev/null; then
  if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
    log "would run: brew update && brew upgrade"
  else
    HOMEBREW_NO_AUTO_UPDATE=1 brew update && yes | brew upgrade
  fi
fi
