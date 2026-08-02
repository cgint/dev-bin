#!/bin/bash
# Wait for one change to a text file (at most 1 MiB), then print a unified diff.

set -uo pipefail

MAX_BYTES=1048576
watcher_pid=""
snapshot=""
file_path=""

usage() {
  cat <<'EOF'
Usage: watchdiff.sh FILE

Capture FILE in memory, wait for its next change, print a unified diff, and exit.
Both the original and changed file must be at most 1 MiB.
Requires: entr, diff
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

stop_watcher() {
  if [[ -n "$watcher_pid" ]]; then
    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true
    watcher_pid=""
  fi
}

print_diff_and_exit() {
  local diff_status=0

  stop_watcher
  validate_file "$file_path"
  diff -u -L "$file_path (before)" -L "$file_path (after)" \
    <(printf '%s' "$snapshot") "$file_path" || diff_status=$?

  # diff returns 1 for differences; this utility treats that expected result as success.
  (( diff_status <= 1 )) || exit "$diff_status"
  exit 0
}

if [[ $# -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  [[ $# -eq 1 ]] && exit 0
  exit 1
fi

command -v entr >/dev/null 2>&1 || fail "entr is required but was not found in PATH"
command -v diff >/dev/null 2>&1 || fail "diff is required but was not found in PATH"

file_path="$1"
validate_file "$file_path"

# A text-file snapshot: Bash variables cannot represent NUL bytes, which is why
# binary files are out of scope. read -d '' preserves a final newline at EOF.
IFS= read -r -d '' snapshot < "$file_path" || true

trap print_diff_and_exit USR1
trap 'stop_watcher; exit 130' INT TERM HUP

printf '%s\n' "$file_path" | entr -n -p sh -c 'kill -USR1 "$1"' _ "$$" &
watcher_pid=$!

printf 'Watching %s for one change...\n' "$file_path" >&2
wait "$watcher_pid"
