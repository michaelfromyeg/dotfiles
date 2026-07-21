#!/usr/bin/env bash

# Kill Cold Turkey Blocker. It kills headless Chrome, which breaks local
# testing, so this quits it on demand.

echo "[cold-turkey] Quitting Cold Turkey Blocker..."

if [[ $dry == "2" ]]; then
  echo "[cold-turkey] [DRY_RUN] would run: killall 'Cold Turkey Blocker'"
  exit 0
fi

if killall "Cold Turkey Blocker" 2>/dev/null; then
  echo "[cold-turkey] Killed."
else
  echo "[cold-turkey] Not running."
fi
