#!/bin/bash
# Wait for one change to a text file (at most 1 MiB), then print a unified diff.

set -uo pipefail

MAX_BYTES=1048576
watcher_pid=""
timer_pid=""
timeout_seconds=""
expected_token=""
baseline_token=""
target_token=""
snapshot=""
target_snapshot=""
file_path=""

usage() {
  cat <<'EOF'
Usage: watchdiff.sh [-t SECONDS] [--token VERSION] FILE

Capture FILE in memory, wait for its next change, print a unified diff, and exit.
  -t SECONDS      Stop waiting after SECONDS and exit with status 124.
  --token VERSION  Return status 3 if VERSION differs from FILE's current baseline.
When it stops waiting, reports its final observed version on stderr.
VERSION is a five-character hexadecimal content fingerprint for the supplied FILE.
Both the original and changed file must be at most 1 MiB.
Requires: entr, diff, shasum
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

file_size() {
  stat -f '%z' "$1"
}

validate_file() {
  local size

  [[ -f "$1" ]] || fail "not a regular file: $1"
  [[ -r "$1" ]] || fail "file is not readable: $1"
  size="$(file_size "$1")" || fail "could not read file size: $1"
  [[ "$size" =~ ^[0-9]+$ ]] || fail "invalid file size: $1"
  (( size <= MAX_BYTES )) || fail "file exceeds 1 MB: $1"
}

snapshot_token() {
  printf '%s' "$1" | shasum -a 256 | awk '{print substr($1, 1, 5)}'
}

stop_watcher() {
  if [[ -n "$watcher_pid" ]]; then
    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true
    watcher_pid=""
  fi
}

stop_timer() {
  if [[ -n "$timer_pid" ]]; then
    kill "$timer_pid" 2>/dev/null || true
    wait "$timer_pid" 2>/dev/null || true
    timer_pid=""
  fi
}

capture_target_snapshot() {
  validate_file "$file_path"
  IFS= read -r -d '' target_snapshot < "$file_path" || true
  target_token="$(snapshot_token "$target_snapshot")" || fail "could not calculate target token"
}

print_target_diff() {
  local diff_status=0

  diff -u -L "$file_path (before)" -L "$file_path (after)" \
    <(printf '%s' "$snapshot") <(printf '%s' "$target_snapshot") || diff_status=$?

  # diff returns 1 for differences; this utility treats that expected result as success.
  (( diff_status <= 1 )) || return "$diff_status"
}

report_last_observed_version() {
  printf 'Last observed version: %s\n' "$target_token" >&2
}

print_diff_and_exit() {
  stop_timer
  stop_watcher
  capture_target_snapshot
  print_target_diff || exit "$?"
  printf 'Change detected. Current version: %s\n' "$target_token" >&2
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -t|--timeout)
      [[ $# -ge 2 ]] || fail "$1 requires a number of seconds"
      timeout_seconds="$2"
      shift 2
      ;;
    --token)
      [[ $# -ge 2 ]] || fail "$1 requires a token"
      expected_token="$2"
      shift 2
      ;;
    -*)
      fail "unknown option: $1"
      ;;
    *)
      [[ -z "$file_path" ]] || fail "only one file may be watched"
      file_path="$1"
      shift
      ;;
  esac
done

[[ -n "$file_path" ]] || { usage >&2; exit 1; }
[[ -z "$timeout_seconds" || "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] \
  || fail "timeout must be a positive whole number of seconds"

if [[ -n "$expected_token" ]]; then
  expected_token="$(printf '%s' "$expected_token" | tr '[:upper:]' '[:lower:]')"
  [[ "$expected_token" =~ ^[[:xdigit:]]{5}$ ]] \
    || fail "token must be five hexadecimal characters"
fi

command -v shasum >/dev/null 2>&1 || fail "shasum is required but was not found in PATH"
validate_file "$file_path"

# A text-file snapshot: Bash variables cannot represent NUL bytes, which is why
# binary files are out of scope. read -d '' preserves a final newline at EOF.
IFS= read -r -d '' snapshot < "$file_path" || true
baseline_token="$(snapshot_token "$snapshot")" || fail "could not calculate baseline token"

if [[ -n "$expected_token" && "$expected_token" != "$baseline_token" ]]; then
  echo "File changed since version $expected_token. Current version: $baseline_token." >&2
  exit 3
fi

command -v entr >/dev/null 2>&1 || fail "entr is required but was not found in PATH"
command -v diff >/dev/null 2>&1 || fail "diff is required but was not found in PATH"

timeout_and_exit() {
  local unit="seconds"

  [[ "$timeout_seconds" -eq 1 ]] && unit="second"
  stop_timer
  stop_watcher
  capture_target_snapshot

  if [[ "$target_snapshot" != "$snapshot" ]]; then
    print_target_diff || exit "$?"
    printf 'Change detected. Current version: %s\n' "$target_token" >&2
    exit 0
  fi

  echo "Timed out after $timeout_seconds $unit waiting for: $file_path" >&2
  report_last_observed_version
  exit 124
}

interrupted_and_exit() {
  stop_timer
  stop_watcher
  capture_target_snapshot
  printf '\nStopped watching. Last observed version: %s\n' "$target_token" >&2
  exit 130
}

trap print_diff_and_exit USR1
trap timeout_and_exit ALRM
trap interrupted_and_exit INT TERM HUP

printf '%s\n' "$file_path" | entr -n -p sh -c 'kill -USR1 "$1"' _ "$$" &
watcher_pid=$!

if [[ -n "$timeout_seconds" ]]; then
  ( sleep "$timeout_seconds"; kill -ALRM "$$" ) &
  timer_pid=$!
fi

printf 'Watching %s for one change...\n' "$file_path" >&2
wait "$watcher_pid"
