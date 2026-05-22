#!/usr/bin/env bash

# Thin wrapper around `notion test`.
#
# Default: `notion test --branch` (lets notion test handle discovery itself —
# graphite-aware base, jest reporters, batched into one invocation).
#
# With --base BRANCH (or when called from a stacked-PR pre-push hook):
# discover changed test files between BRANCH..HEAD + working tree ourselves,
# then pass them as positional args. This keeps the test set scoped to the
# *current* stack branch instead of the whole diff back to origin/main.
#
# Anything not consumed below is forwarded to `notion test`.

set -o pipefail

BASE=""
OUTPUT_FILE=""
ADD_TIMESTAMP=false
INCLUDE_UNTRACKED=false
INTEGRATION_MODE="exclude"  # exclude | include | only
CAP=40
PASSTHROUGH=()

show_help() {
  cat <<EOF
Usage: $0 [options] [-- notion-test-args...]

Options:
  -b, --base BRANCH    Compare against BRANCH (e.g. \`gt parent\`).
                       When set, we discover tests ourselves over BRANCH..HEAD
                       and pass them as positional args (scoped per stack branch).
                       When unset, falls back to \`notion test --branch\`.
  -o, --output FILE    Tee combined output to FILE
  -t, --timestamp      Append _YYYYMMDD_HHMMSS to the output filename
  -u, --untracked      Also include untracked *.test.{ts,tsx,js,jsx} files
  -a, --all            Include integration tests (default: exclude them)
  -i, --integration    Run ONLY integration tests
  -c, --cap N          Cap the discovered test set at N files; if more are
                       found, randomly sample N (default: 40, --cap 0 disables).
                       Only applies in --base mode; ignored by --branch mode.
  -h, --help           Show this help

All other args (e.g. --coverage, --watch, --bail, --maxWorkers=N) are
forwarded to \`notion test\`.

Examples:
  $0                                # notion test --branch
  $0 -b "\$(gt parent)"              # only tests changed on this stack branch
  $0 -o results.txt -t              # tee to timestamped file
  $0 -- --coverage --bail           # forward jest flags through
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--base)      BASE="$2"; shift 2 ;;
    -o|--output)    OUTPUT_FILE="$2"; shift 2 ;;
    -t|--timestamp) ADD_TIMESTAMP=true; shift ;;
    -u|--untracked) INCLUDE_UNTRACKED=true; shift ;;
    -a|--all)         INTEGRATION_MODE="include"; shift ;;
    -i|--integration) INTEGRATION_MODE="only"; shift ;;
    -c|--cap)       CAP="$2"; shift 2 ;;
    -h|--help)      show_help; exit 0 ;;
    --)             shift; PASSTHROUGH+=("$@"); break ;;
    *)              PASSTHROUGH+=("$1"); shift ;;
  esac
done

if [[ -n "$OUTPUT_FILE" && "$ADD_TIMESTAMP" == true ]]; then
  ext="${OUTPUT_FILE##*.}"
  base_name="${OUTPUT_FILE%.*}"
  if [[ "$ext" == "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="${OUTPUT_FILE}_$(date +%Y%m%d_%H%M%S)"
  else
    OUTPUT_FILE="${base_name}_$(date +%Y%m%d_%H%M%S).${ext}"
  fi
fi

TEST_RE='\.(test|spec)\.(ts|tsx|js|jsx)$'
SRC_RE='\.(ts|tsx|js|jsx)$'

# Discover changed test files over $BASE..HEAD plus uncommitted changes.
# For changed source files (non-test), include the sibling .test/.spec file
# if one exists. Optionally include untracked test files.
discover_tests() {
  local base="$1"
  local merge_base
  merge_base=$(git merge-base "$base" HEAD 2>/dev/null) || return 1

  {
    git diff --name-only "${merge_base}..HEAD" 2>/dev/null
    git diff --name-only HEAD 2>/dev/null
    git diff --name-only --cached 2>/dev/null
    if [[ "$INCLUDE_UNTRACKED" == true ]]; then
      git ls-files --others --exclude-standard 2>/dev/null
    fi
  } | sort -u | while IFS= read -r f; do
    [[ -z "$f" || ! -f "$f" ]] && continue
    if [[ "$f" =~ $TEST_RE ]]; then
      echo "$f"
    elif [[ "$f" =~ $SRC_RE ]]; then
      local stem="${f%.*}" ext="${f##*.}"
      for variant in test spec; do
        local candidate="${stem}.${variant}.${ext}"
        [[ -f "$candidate" ]] && echo "$candidate"
      done
    fi
  done | sort -u | filter_integration
}

filter_integration() {
  case "$INTEGRATION_MODE" in
    exclude) grep -vE '\.integration\.(test|spec)\.' || true ;;
    only)    grep -E  '\.integration\.(test|spec)\.' || true ;;
    include) cat ;;
  esac
}

CMD=(notion test)
if [[ -n "$BASE" ]]; then
  mapfile -t TESTS < <(discover_tests "$BASE")
  if [[ ${#TESTS[@]} -eq 0 ]]; then
    echo "[test-changed] No changed tests vs $BASE."
    exit 0
  fi
  orig_count=${#TESTS[@]}
  if [[ "$CAP" -gt 0 && "$orig_count" -gt "$CAP" ]]; then
    mapfile -t TESTS < <(printf '%s\n' "${TESTS[@]}" | sort -R | head -n "$CAP")
    echo "[test-changed] Capped at $CAP of $orig_count discovered test file(s) (random sample)." >&2
  fi
  echo "[test-changed] Base: $BASE (running ${#TESTS[@]} test file(s))" >&2
  printf '  %s\n' "${TESTS[@]}" >&2
  CMD+=("${PASSTHROUGH[@]}" "${TESTS[@]}")
else
  CMD+=(--branch "${PASSTHROUGH[@]}")
fi

run() {
  if [[ -n "$OUTPUT_FILE" ]]; then
    {
      echo "=============================================="
      echo "  Test Results"
      echo "  Generated: $(date)"
      echo "  Branch:    $(git branch --show-current 2>/dev/null || echo unknown)"
      [[ -n "$BASE" ]] && echo "  Base:      $BASE"
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
