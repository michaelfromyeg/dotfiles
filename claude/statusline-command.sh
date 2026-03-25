#!/bin/bash

# Claude Code statusline — gruvbox theme (foreground colors)
# Mirrors gruvbox2.omp.json color palette

input=$(cat)

current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
model_name=$(echo "$input" | jq -r '.model.display_name')
output_style=$(echo "$input" | jq -r '.output_style.name')

RESET=$'\033[0m'
DIM=$'\033[2m'

# Gruvbox truecolor foreground palette
FG_WHITE=$'\033[38;2;255;255;255m'
FG_GRAY=$'\033[38;2;146;131;116m'    # #928374 gruvbox gray
FG_BLUE=$'\033[38;2;69;133;136m'     # #458588
FG_GREEN=$'\033[38;2;152;151;26m'    # #98971A
FG_MAGENTA=$'\033[38;2;211;134;155m' # #d3869b
FG_ORANGE=$'\033[38;2;255;146;72m'   # #FF9248
FG_PURPLE=$'\033[38;2;179;136;255m'  # #B388FF
FG_RED=$'\033[38;2;204;36;29m'       # #cc241d
FG_YELLOW=$'\033[38;2;250;189;47m'   # #fabd2f

# Git icons (actual UTF-8 characters)
BRANCH=$'\ue0a0'
DIRTY=$'\uf044'
STAGED=$'\uf046'

SEP="${DIM} | ${RESET}"

parts=()

# --- Claude mode ---
mode_text="CLAUDE"
if [[ "$output_style" != "null" && -n "$output_style" ]]; then
  mode_text="CLAUDE:${output_style}"
fi
parts+=("${FG_MAGENTA}${mode_text}${RESET}")

# --- Model ---
if [[ "$model_name" != "null" && -n "$model_name" ]]; then
  parts+=("${FG_GRAY}${model_name}${RESET}")
fi

# --- Path ---
if [[ -n "$current_dir" && "$current_dir" != "null" ]]; then
  dir_display="${current_dir/#$HOME/~}"
  parts+=("${FG_BLUE}${dir_display}${RESET}")
fi

# --- Git ---
if git -C "$current_dir" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  branch=$(git -C "$current_dir" symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$current_dir" describe --tags --exact-match 2>/dev/null \
    || git -C "$current_dir" rev-parse --short HEAD 2>/dev/null)

  if [[ -n "$branch" ]]; then
    # Truncate to 25 chars
    if [[ ${#branch} -gt 25 ]]; then
      branch="${branch:0:25}..."
    fi

    # Ahead/behind
    ahead=0
    behind=0
    if git -C "$current_dir" rev-parse --abbrev-ref '@{upstream}' > /dev/null 2>&1; then
      ahead=$(git -C "$current_dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
      behind=$(git -C "$current_dir" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
    fi

    # Working/staging changes
    has_working=0
    has_staging=0
    [[ -n "$(git -C "$current_dir" diff --stat 2>/dev/null | tail -1)" ]] && has_working=1
    [[ -n "$(git -C "$current_dir" diff --cached --stat 2>/dev/null | tail -1)" ]] && has_staging=1

    # Pick color based on state
    git_color="$FG_GREEN"
    if [[ $has_working -eq 1 || $has_staging -eq 1 ]]; then
      git_color="$FG_ORANGE"
    fi
    if [[ $ahead -gt 0 || $behind -gt 0 ]]; then
      git_color="$FG_PURPLE"
    fi
    if [[ $ahead -gt 0 && $behind -gt 0 ]]; then
      git_color="$FG_RED"
    fi

    git_text="${BRANCH} ${branch}"

    if [[ $ahead -gt 0 ]]; then
      git_text="${git_text} ↑${ahead}"
    fi
    if [[ $behind -gt 0 ]]; then
      git_text="${git_text} ↓${behind}"
    fi
    if [[ $has_working -eq 1 ]]; then
      git_text="${git_text} ${DIRTY}"
    fi
    if [[ $has_staging -eq 1 ]]; then
      git_text="${git_text} ${STAGED}"
    fi

    parts+=("${git_color}${git_text}${RESET}")
  fi
fi

# Join with separators
output=""
for i in "${!parts[@]}"; do
  if [[ $i -gt 0 ]]; then
    output+="$SEP"
  fi
  output+="${parts[$i]}"
done

printf "%s\n" "$output"
