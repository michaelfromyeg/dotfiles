#!/usr/bin/env bash
# Sets up a dev tmux session: claude + scratchpad + notion run

echo "[tmux-dev] Starting..."

SESSION="dev"

# Find notion-next directory
if [ -d "/work/notion-next" ]; then
  WORK_DIR="/work/notion-next"
elif [ -d "$HOME/code/notion-next" ]; then
  WORK_DIR="$HOME/code/notion-next"
else
  WORK_DIR="$HOME"
fi

# If session exists, attach/switch to it
if tmux has-session -t "=$SESSION" 2>/dev/null; then
  echo "[tmux-dev] Session '$SESSION' exists, reattaching..."

  if [[ "$dry" == "1" ]] || [[ "$dry" == "2" ]]; then
    exit 0
  fi

  if [ -n "$TMUX" ]; then
    tmux switch-client -t "=$SESSION"
  else
    tmux attach-session -t "=$SESSION"
  fi
  exit 0
fi

echo "[tmux-dev] Creating session '$SESSION' in $WORK_DIR"

if [[ "$dry" == "1" ]] || [[ "$dry" == "2" ]]; then
  exit 0
fi

# Create session with claude in the main pane (top 70%)
tmux new-session -d -s "$SESSION" -c "$WORK_DIR"
tmux rename-window -t "$SESSION:1" "main"

# Bottom 30%: scratchpad + notion run (if available)
tmux split-window -v -t "$SESSION:1.1" -l 30% -c "$WORK_DIR"

if [ "$WORK_DIR" != "$HOME" ] && command -v notion &>/dev/null; then
  # Split bottom: scratchpad (left) + notion run (right)
  tmux split-window -h -t "$SESSION:1.2" -l 50% -c "$WORK_DIR"
  tmux send-keys -t "$SESSION:1.3" "notion run" C-m
fi

# Start claude in the top pane (use `command` to bypass any shell function wrappers)
tmux send-keys -t "$SESSION:1.1" "command claude" C-m

# Focus claude pane
tmux select-pane -t "$SESSION:1.1"

# Attach or switch
if [ -n "$TMUX" ]; then
  tmux switch-client -t "=$SESSION"
else
  tmux attach-session -t "=$SESSION"
fi
