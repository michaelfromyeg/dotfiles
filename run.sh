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

# Colors
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

header() {
  echo ""
  if [[ -n "$filter" ]]; then
    echo -e "${BOLD}${CYAN}dotfiles${NC} ${DIM}>${NC} ${BOLD}$filter${NC}"
  else
    echo -e "${BOLD}${CYAN}dotfiles${NC} ${DIM}> all${NC}"
  fi
  if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
    echo -e "  ${YELLOW}(dry run)${NC}"
  fi
  echo ""
}

log() {
  if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
    echo -e "${DIM}[dotfiles]${NC} ${YELLOW}[DRY_RUN]${NC} $*"
  else
    echo -e "${DIM}[dotfiles]${NC} $*"
  fi
}

execute() {
  echo -e "${DIM}[dotfiles]${NC} ${GREEN}Running${NC} $*"

  if [[ $dry == "1" ]]; then
    return
  fi

  if [[ ${#args[@]} -gt 0 ]]; then
    "$@" "${args[@]}"
  else
    "$@"
  fi
}

header

cd "$script_dir"/scripts || exit

# Detect if running on Windows
is_windows() {
  case "$(uname -s)" in
    CYGWIN*|MINGW*|MSYS*|Windows*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Determine which find command to use
if command -v gfind >/dev/null 2>&1; then
  FIND="gfind"
else
  FIND="find"
fi

# Find appropriate scripts based on platform
if is_windows; then
  scripts=$($FIND . -maxdepth 1 -mindepth 1 -name "*.ps1" -type f)
else
  scripts=$($FIND . -maxdepth 1 -mindepth 1 -executable -name "*.sh" -type f)
fi

for script in $scripts; do
  if echo "$script" | grep -qv "$filter"; then
    # Only show skipped scripts when running all (no filter)
    [[ -z "$filter" ]] && log "${DIM}Skipped $script${NC}"
    continue
  fi

  # Execute PowerShell scripts differently on Windows
  if is_windows && [[ "$script" == *.ps1 ]]; then
    execute powershell.exe -ExecutionPolicy Bypass -File "$script"
  else
    execute "$script"
  fi
done
