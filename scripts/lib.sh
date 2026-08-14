# shellcheck shell=bash
# Shared helpers for the setup scripts in this directory. Source at the top:
#
#   # shellcheck source=lib.sh
#   source "$(dirname "$0")/lib.sh"
#
# Deliberately not executable: run.sh runs every executable *.sh in here.
#
# run.sh exports $dry ("0" normal, "1" harness dry run, "2" script-level dry
# run); default to a normal run so scripts also work when invoked directly.

dry="${dry:-0}"

# Log prefix, e.g. [languages] for languages.sh.
tag="$(basename "$0" .sh)"

log() {
  if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
    echo "[$tag] [DRY_RUN] $*"
  else
    echo "[$tag] $*"
  fi
}

# Log a command, then run it unless this is a dry run.
run_cmd() {
  log "$*"
  if [[ $dry == "1" ]] || [[ $dry == "2" ]]; then
    return 0
  fi
  "$@"
}

# Report whether a command is installed, logging what was found.
check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    log "$1 not found"
    return 1
  else
    log "$1 $(command -v "$1")"
    return 0
  fi
}
