#!/usr/bin/env bash

# Thin wrapper around `notion test --branch`.
#
# `notion test --branch` already:
#   - discovers tests for files changed on this branch (graphite-aware merge-base)
#   - includes uncommitted working-tree changes
#   - batches into a single jest invocation with streaming per-file results
#   - handles unit/integration/docker setup
#
# This wrapper just adds:
#   - tee'd output to a file with a header (useful for PR descriptions)
#   - optional inclusion of untracked test files (notion test --branch skips them)
#
# Anything not consumed below is forwarded to `notion test`.

set -o pipefail

OUTPUT_FILE=""
ADD_TIMESTAMP=false
INCLUDE_UNTRACKED=false
PASSTHROUGH=()

show_help() {
  cat <<EOF
Usage: $0 [options] [-- notion-test-args...]

Options:
  -o, --output FILE    Tee combined output to FILE
  -t, --timestamp      Append _YYYYMMDD_HHMMSS to the output filename
  -u, --untracked      Also include untracked *.test.{ts,tsx,js,jsx} files
  -h, --help           Show this help

All other args (e.g. --coverage, --watch, --bail, --maxWorkers=N) are
forwarded to \`notion test\`. \`--branch\` is always added.

Examples:
  $0                              # notion test --branch
  $0 -o results.txt -t            # tee to timestamped file
  $0 -- --coverage --bail         # forward jest flags through
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -o|--output)    OUTPUT_FILE="$2"; shift 2 ;;
    -t|--timestamp) ADD_TIMESTAMP=true; shift ;;
    -u|--untracked) INCLUDE_UNTRACKED=true; shift ;;
    -h|--help)      show_help; exit 0 ;;
    --)             shift; PASSTHROUGH+=("$@"); break ;;
    *)              PASSTHROUGH+=("$1"); shift ;;
  esac
done

if [[ -n "$OUTPUT_FILE" && "$ADD_TIMESTAMP" == true ]]; then
  ext="${OUTPUT_FILE##*.}"
  base="${OUTPUT_FILE%.*}"
  if [[ "$ext" == "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="${OUTPUT_FILE}_$(date +%Y%m%d_%H%M%S)"
  else
    OUTPUT_FILE="${base}_$(date +%Y%m%d_%H%M%S).${ext}"
  fi
fi

UNTRACKED_TESTS=()
if [[ "$INCLUDE_UNTRACKED" == true ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && UNTRACKED_TESTS+=("$f")
  done < <(git ls-files --others --exclude-standard 2>/dev/null \
           | grep -E '\.(test|spec)\.(ts|tsx|js|jsx)$' || true)
fi

CMD=(notion test --branch "${PASSTHROUGH[@]}")
if [[ ${#UNTRACKED_TESTS[@]} -gt 0 ]]; then
  CMD+=("${UNTRACKED_TESTS[@]}")
fi

run() {
  if [[ -n "$OUTPUT_FILE" ]]; then
    {
      echo "=============================================="
      echo "  Test Results"
      echo "  Generated: $(date)"
      echo "  Branch:    $(git branch --show-current 2>/dev/null || echo unknown)"
      echo "  Command:   ${CMD[*]}"
      echo "=============================================="
      echo ""
    } > "$OUTPUT_FILE"
    "${CMD[@]}" 2>&1 | tee -a "$OUTPUT_FILE"
    return "${PIPESTATUS[0]}"
  else
    "${CMD[@]}"
  fi
}

echo "[test-changed] Running: ${CMD[*]}"
[[ -n "$OUTPUT_FILE" ]] && echo "[test-changed] Output:  $OUTPUT_FILE"
run
