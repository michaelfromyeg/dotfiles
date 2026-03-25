#!/bin/bash

# Claude Code statusline — gruvbox powerline theme
# Mirrors oh-my-posh gruvbox2.omp.json segments

input=$(cat)

current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
model_name=$(echo "$input" | jq -r '.model.display_name')
output_style=$(echo "$input" | jq -r '.output_style.name')

# Powerline separator
SEP=$'\ue0b0'

RESET='\033[0m'

# Gruvbox truecolor palette (matching gruvbox2.omp.json)
fg()  { printf '\033[38;2;%d;%d;%dm' "$1" "$2" "$3"; }
bg()  { printf '\033[48;2;%d;%d;%dm' "$1" "$2" "$3"; }

# Colors from the oh-my-posh theme
DARK="40;40;40"         # #282828
GRAY="58;58;58"         # #3A3A3A
BLUE="69;133;136"       # #458588
GREEN="152;151;26"      # #98971A
MAGENTA="211;134;155"   # #d3869b
ORANGE="255;146;72"     # #FF9248
PURPLE="179;136;255"    # #B388FF

prev_bg=""

segment() {
  local bg_rgb="$1"
  local fg_rgb="$2"
  local text="$3"

  if [[ -z "$text" ]]; then
    return
  fi

  IFS=';' read -r br bg bb <<< "$bg_rgb"
  IFS=';' read -r fr fg_g fb <<< "$fg_rgb"

  # Powerline transition from previous segment
  if [[ -n "$prev_bg" ]]; then
    IFS=';' read -r pr pg pb <<< "$prev_bg"
    printf "$(fg "$pr" "$pg" "$pb")$(bg "$br" "$bg" "$bb")${SEP}${RESET}"
  fi

  printf "$(bg "$br" "$bg" "$bb")$(fg "$fr" "$fg_g" "$fb") %s ${RESET}" "$text"
  prev_bg="$bg_rgb"
}

end_segments() {
  if [[ -n "$prev_bg" ]]; then
    IFS=';' read -r pr pg pb <<< "$prev_bg"
    printf "$(fg "$pr" "$pg" "$pb")${SEP}${RESET}"
  fi
}

# --- Segment 1: Claude mode (like OS segment) ---
mode_text="CLAUDE"
if [[ "$output_style" != "null" && -n "$output_style" ]]; then
  mode_text="CLAUDE:${output_style}"
fi
segment "$GRAY" "255;255;255" "$mode_text"

# --- Segment 2: Model (like boxy/session segment) ---
if [[ "$model_name" != "null" && -n "$model_name" ]]; then
  segment "$MAGENTA" "$DARK" "$model_name"
fi

# --- Segment 3: Path (matching oh-my-posh path segment) ---
if [[ -n "$current_dir" && "$current_dir" != "null" ]]; then
  # Show full path like oh-my-posh style:"full"
  dir_display="${current_dir/#$HOME/~}"
  segment "$BLUE" "$DARK" "$dir_display"
fi

# --- Segment 4: Git (matching oh-my-posh git segment) ---
if git -C "$current_dir" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  branch=$(git -C "$current_dir" symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$current_dir" describe --tags --exact-match 2>/dev/null \
    || git -C "$current_dir" rev-parse --short HEAD 2>/dev/null)

  if [[ -n "$branch" ]]; then
    # Truncate branch to 25 chars like oh-my-posh
    if [[ ${#branch} -gt 25 ]]; then
      branch="${branch:0:25}..."
    fi

    git_text="\uE0A0 ${branch}"

    # Working/staging changes
    working=$(git -C "$current_dir" diff --stat 2>/dev/null | tail -1)
    staging=$(git -C "$current_dir" diff --cached --stat 2>/dev/null | tail -1)
    has_working=$([[ -n "$working" ]] && echo 1 || echo 0)
    has_staging=$([[ -n "$staging" ]] && echo 1 || echo 0)

    # Ahead/behind
    ahead=0
    behind=0
    if git -C "$current_dir" rev-parse --abbrev-ref '@{upstream}' > /dev/null 2>&1; then
      ahead=$(git -C "$current_dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
      behind=$(git -C "$current_dir" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
    fi

    # Branch status (like oh-my-posh branch_identical_icon)
    if [[ $ahead -eq 0 && $behind -eq 0 ]]; then
      git_text="${git_text} \u25CF"
    fi
    if [[ $ahead -gt 0 ]]; then
      git_text="${git_text} \u2191${ahead}"
    fi
    if [[ $behind -gt 0 ]]; then
      git_text="${git_text} \u2193${behind}"
    fi

    # Working changes indicator
    if [[ $has_working -eq 1 ]]; then
      git_text="${git_text} \uf044"
    fi
    if [[ $has_staging -eq 1 ]]; then
      git_text="${git_text} \uf046"
    fi

    # Pick background color based on state (matching oh-my-posh background_templates)
    git_bg="$GREEN"
    if [[ $has_working -eq 1 || $has_staging -eq 1 ]]; then
      git_bg="$ORANGE"
    fi
    if [[ $ahead -gt 0 || $behind -gt 0 ]]; then
      git_bg="$PURPLE"
    fi
    if [[ $ahead -gt 0 && $behind -gt 0 ]]; then
      git_bg="255;69;0"  # #ff4500 — diverged
    fi

    segment "$git_bg" "$DARK" "$git_text"
  fi
fi

end_segments
printf "\n"
