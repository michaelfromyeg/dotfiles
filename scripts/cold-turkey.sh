#!/usr/bin/env bash

# Kill Cold Turkey Blocker. It kills headless Chrome, which breaks local
# testing, so this quits it on demand.
#
# Matches on the full command line rather than just the app name: the browser
# extensions spawn their own native-messaging bridges (NMHChrome, NMHFirefox,
# NMHEdge) out of /Library/Application Support/Cold Turkey, and those outlive
# the app. Browsers respawn them on demand, so this is a per-session fix.

pattern="Cold Turkey"

echo "[cold-turkey] Quitting Cold Turkey Blocker..."

if [[ $dry == "2" ]]; then
  echo "[cold-turkey] [DRY_RUN] would run: pkill -f '$pattern'"
  exit 0
fi

pgrep -fl "$pattern"

if pkill -f "$pattern"; then
  echo "[cold-turkey] Killed."
else
  echo "[cold-turkey] Not running."
fi
