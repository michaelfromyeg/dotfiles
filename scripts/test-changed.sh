#!/usr/bin/env bash

# Unified test runner for changed files
# Runs tests for files that have changed compared to a base branch
#
# Usage: dotfiles test-changed [options]
#        ./test-changed.sh [options]

set -o pipefail

# === Configuration & Defaults ===
SCRIPT_NAME="test-changed"
BASE_BRANCH="main"
TEST_CMD="notion test"
OUTPUT_FILE="test-results.txt"
INCLUDE_INTEGRATION=false
INTEGRATION_ONLY=false
INCLUDE_UNTRACKED=false
SKIP_HOOKS=false
ADD_TIMESTAMP=false
DELAY=0
VERBOSE=false
DRY_RUN=false
FAILURE_LINES=50

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# === Helper Functions ===

log() {
  echo -e "[$SCRIPT_NAME] $*"
}

log_dry() {
  echo -e "[$SCRIPT_NAME] ${YELLOW}[DRY_RUN]${NC} $*"
}

log_info() {
  echo -e "[$SCRIPT_NAME] ${BLUE}$*${NC}"
}

log_success() {
  echo -e "[$SCRIPT_NAME] ${GREEN}$*${NC}"
}

log_error() {
  echo -e "[$SCRIPT_NAME] ${RED}$*${NC}"
}

show_help() {
  cat << EOF
Usage: $0 [options]

Run tests for files changed in the current branch compared to a base branch.

Options:
  -a, --all              Include integration tests (default: unit tests only)
  -i, --integration      Run ONLY integration tests
  -u, --untracked        Include untracked test files
  -d, --delay N          Delay N seconds between tests (default: 0)
  -o, --output FILE      Output file (default: test-results.txt)
  -t, --timestamp        Add timestamp to output filename
  -b, --base BRANCH      Base branch to compare (default: main)
  -c, --cmd COMMAND      Test command (default: notion test)
  -s, --skip-hooks       Set SKIP_PREINSTALL=1 SKIP_POSTINSTALL=1
  -n, --dry-run          Show what would run without executing
  -v, --verbose          Show full test output (not just failures)
  -h, --help             Show this help message

Examples:
  $0                         # Run unit tests for changed files
  $0 --all                   # Include integration tests
  $0 --integration           # Run only integration tests
  $0 --cmd "npm test"        # Use npm test as the runner
  $0 --base develop          # Compare against develop branch
  $0 -t -o results.txt       # Timestamped output to results.txt

Exit Codes:
  0  All tests passed (or no tests to run)
  1  One or more tests failed
  2  Invalid arguments or configuration error
EOF
}

# === Argument Parsing ===

while [[ $# -gt 0 ]]; do
  case $1 in
    -a|--all)
      INCLUDE_INTEGRATION=true
      shift
      ;;
    -i|--integration)
      INTEGRATION_ONLY=true
      shift
      ;;
    -u|--untracked)
      INCLUDE_UNTRACKED=true
      shift
      ;;
    -d|--delay)
      DELAY="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    -t|--timestamp)
      ADD_TIMESTAMP=true
      shift
      ;;
    -b|--base)
      BASE_BRANCH="$2"
      shift 2
      ;;
    -c|--cmd)
      TEST_CMD="$2"
      shift 2
      ;;
    -s|--skip-hooks)
      SKIP_HOOKS=true
      shift
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      show_help
      exit 2
      ;;
  esac
done

# Handle timestamp in output filename
if [[ "$ADD_TIMESTAMP" == true ]]; then
  # Insert timestamp before extension
  ext="${OUTPUT_FILE##*.}"
  base="${OUTPUT_FILE%.*}"
  if [[ "$ext" == "$OUTPUT_FILE" ]]; then
    # No extension
    OUTPUT_FILE="${OUTPUT_FILE}_$(date +%Y%m%d_%H%M%S)"
  else
    OUTPUT_FILE="${base}_$(date +%Y%m%d_%H%M%S).${ext}"
  fi
fi

# === Test File Discovery ===

find_changed_tests() {
  local pattern="$1"
  local exclude_pattern="$2"

  # Get files changed in this branch (committed changes compared to base)
  local committed_files
  committed_files=$(git diff --name-only "${BASE_BRANCH}...HEAD" 2>/dev/null | grep -E "$pattern" || true)

  # Get dirty/uncommitted files (staged and unstaged)
  local dirty_files
  dirty_files=$(git diff --name-only HEAD 2>/dev/null | grep -E "$pattern" || true)

  local staged_files
  staged_files=$(git diff --name-only --cached 2>/dev/null | grep -E "$pattern" || true)

  # Get untracked files (optional)
  local untracked_files=""
  if [[ "$INCLUDE_UNTRACKED" == true ]]; then
    untracked_files=$(git ls-files --others --exclude-standard 2>/dev/null | grep -E "$pattern" || true)
  fi

  # Combine and deduplicate
  local all_files
  all_files=$(echo -e "${committed_files}\n${dirty_files}\n${staged_files}\n${untracked_files}" | sort -u | grep -v '^$' || true)

  # Apply exclusion pattern if provided
  if [[ -n "$exclude_pattern" && -n "$all_files" ]]; then
    all_files=$(echo "$all_files" | grep -vE "$exclude_pattern" || true)
  fi

  echo "$all_files"
}

# === Docker Handling ===

start_docker_if_needed() {
  if [[ "$DRY_RUN" == true ]]; then
    log_dry "Would start Docker services"
    return
  fi

  log_info "Ensuring Docker services are running..."
  docker compose up -d 2>/dev/null || true
  sleep 2
}

# === Test Execution ===

run_test() {
  local test_file="$1"
  local temp_output="$2"

  local cmd_prefix=""
  if [[ "$SKIP_HOOKS" == true ]]; then
    cmd_prefix="SKIP_PREINSTALL=1 SKIP_POSTINSTALL=1 "
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_dry "Would run: ${cmd_prefix}${TEST_CMD} $test_file"
    return 0
  fi

  if [[ "$SKIP_HOOKS" == true ]]; then
    SKIP_PREINSTALL=1 SKIP_POSTINSTALL=1 $TEST_CMD "$test_file" > "$temp_output" 2>&1
  else
    $TEST_CMD "$test_file" > "$temp_output" 2>&1
  fi
}

# === Main Logic ===

log "Starting test runner..."
log "Base branch: $BASE_BRANCH"
log "Test command: $TEST_CMD"
log "Output file: $OUTPUT_FILE"

# Determine test file pattern based on mode
TEST_PATTERN='\.test\.'
EXCLUDE_PATTERN=""

if [[ "$INTEGRATION_ONLY" == true ]]; then
  TEST_PATTERN='\.integration\.test\.'
  log "Mode: Integration tests only"
elif [[ "$INCLUDE_INTEGRATION" == true ]]; then
  log "Mode: All tests (including integration)"
else
  EXCLUDE_PATTERN='\.integration\.test\.'
  log "Mode: Unit tests only (excluding integration)"
fi

# Find test files
log_info "Finding changed test files..."
ALL_TESTS=$(find_changed_tests "$TEST_PATTERN" "$EXCLUDE_PATTERN")

if [[ -z "$ALL_TESTS" ]]; then
  log_success "No changed test files found."
  exit 0
fi

TEST_COUNT=$(echo "$ALL_TESTS" | wc -l | tr -d ' ')
log "Found $TEST_COUNT test file(s):"
echo "$ALL_TESTS" | sed 's/^/  - /'
echo ""

# Start Docker if running integration tests
if [[ "$INTEGRATION_ONLY" == true ]] || [[ "$INCLUDE_INTEGRATION" == true ]]; then
  # Check if any integration tests are in the list
  if echo "$ALL_TESTS" | grep -q '\.integration\.test\.'; then
    start_docker_if_needed
    # Default delay for integration tests if not specified
    if [[ "$DELAY" == "0" ]]; then
      DELAY=1
    fi
  fi
fi

# Initialize output file
{
  echo "=============================================="
  echo "  Test Results"
  echo "  Generated: $(date)"
  echo "  Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
  echo "  Base: $BASE_BRANCH"
  echo "  Command: $TEST_CMD"
  echo "=============================================="
  echo ""
  echo "Test files: $TEST_COUNT"
  echo ""
  echo "Files:"
  echo "$ALL_TESTS" | sed 's/^/  - /'
  echo ""
  echo "=============================================="
  echo ""
} > "$OUTPUT_FILE"

# Run tests
TEMP_OUTPUT=$(mktemp)
trap 'rm -f "$TEMP_OUTPUT"' EXIT

PASSED=0
FAILED=0
FAILED_TESTS=()
CURRENT=0

while IFS= read -r test_file; do
  [[ -z "$test_file" ]] && continue

  CURRENT=$((CURRENT + 1))

  echo "=========================================="
  log "[$CURRENT/$TEST_COUNT] Running: $test_file"
  echo "=========================================="

  {
    echo "----------------------------------------------"
    echo "TEST: $test_file"
    echo "----------------------------------------------"
  } >> "$OUTPUT_FILE"

  if run_test "$test_file" "$TEMP_OUTPUT"; then
    log_success "PASSED: $test_file"
    PASSED=$((PASSED + 1))
    echo "Status: PASSED" >> "$OUTPUT_FILE"

    if [[ "$VERBOSE" == true && "$DRY_RUN" == false ]]; then
      cat "$TEMP_OUTPUT"
    fi
  else
    log_error "FAILED: $test_file"
    FAILED=$((FAILED + 1))
    FAILED_TESTS+=("$test_file")
    echo "Status: FAILED" >> "$OUTPUT_FILE"

    if [[ "$DRY_RUN" == false ]]; then
      echo "--- Last $FAILURE_LINES lines of output ---"
      tail -"$FAILURE_LINES" "$TEMP_OUTPUT"
      echo "--- End of output ---"
    fi
  fi

  # Append test output to results file
  if [[ "$DRY_RUN" == false ]]; then
    echo "" >> "$OUTPUT_FILE"
    cat "$TEMP_OUTPUT" >> "$OUTPUT_FILE"
  fi
  echo "" >> "$OUTPUT_FILE"

  # Delay between tests if specified
  if [[ "$DELAY" -gt 0 && "$DRY_RUN" == false ]]; then
    sleep "$DELAY"
  fi

done <<< "$ALL_TESTS"

# === Results Summary ===

echo ""
echo "=========================================="
log "SUMMARY"
echo "=========================================="
echo "Total:  $TEST_COUNT"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

{
  echo "=============================================="
  echo "  SUMMARY"
  echo "=============================================="
  echo ""
  echo "Total:  $TEST_COUNT"
  echo "Passed: $PASSED"
  echo "Failed: $FAILED"
} >> "$OUTPUT_FILE"

if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
  echo ""
  log_error "Failed tests:"
  for t in "${FAILED_TESTS[@]}"; do
    echo "  - $t"
  done

  {
    echo ""
    echo "Failed tests:"
    for t in "${FAILED_TESTS[@]}"; do
      echo "  - $t"
    done
  } >> "$OUTPUT_FILE"
fi

echo ""
echo "=============================================="
log "Results written to: $OUTPUT_FILE"

# Exit with appropriate code
if [[ $FAILED -gt 0 ]]; then
  exit 1
else
  exit 0
fi
