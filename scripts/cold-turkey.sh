#!/usr/bin/env bash

# Kill Cold Turkey Blocker. It kills headless Chrome, which breaks local
# testing, so this quits it on demand.
#
# Matches on the full command line rather than just the app name: the browser
# extensions spawn their own native-messaging bridges (NMHChrome, NMHFirefox,
# NMHEdge) out of /Library/Application Support/Cold Turkey, and those outlive
# the app. Browsers respawn them on demand, so this is a per-session fix.

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

pattern="Cold Turkey"

log "Quitting Cold Turkey Blocker..."

if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
  log "would run: pkill -f '$pattern'"
  exit 0
fi

pgrep -fl "$pattern"

if pkill -f "$pattern"; then
  log "Killed."
else
  log "Not running."
fi
