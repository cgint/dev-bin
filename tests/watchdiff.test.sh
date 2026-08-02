#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_PATH="$PROJECT_ROOT/watchdiff.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || fail "expected output to not contain: $needle"
}

setup_fixture_dir() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  mkdir -p "$tmp_dir/bin" "$tmp_dir/state"
  echo "$tmp_dir"
}

make_entr_stub() {
  local tmp_dir="$1"

  cat >"$tmp_dir/bin/entr" <<'EOF'
#!/bin/bash
set -euo pipefail

: "${TEST_STATE_DIR:?}"
cat >/dev/null
printf 'ready\n' >"$TEST_STATE_DIR/ready"
while [[ ! -f "$TEST_STATE_DIR/changed" ]]; do
  sleep 0.01
done
kill -USR1 "${!#}"
EOF
  chmod +x "$tmp_dir/bin/entr"
}

cleanup_fixture_dir() {
  local tmp_dir="$1"

  rm -f "$tmp_dir/document.txt" "$tmp_dir/output" "$tmp_dir/stderr"
  rm -f "$tmp_dir/state/ready" "$tmp_dir/state/changed" "$tmp_dir/bin/entr"
  rmdir "$tmp_dir/state" "$tmp_dir/bin" "$tmp_dir"
}

file_token() {
  shasum -a 256 "$1" | awk '{print substr($1, 1, 5)}'
}

wait_for_file() {
  local path="$1"
  local attempts=100

  while [[ ! -f "$path" && "$attempts" -gt 0 ]]; do
    sleep 0.01
    attempts=$((attempts - 1))
  done
  [[ -f "$path" ]] || fail "timed out waiting for: $path"
}

test_matching_token_watches_and_prints_unified_diff() {
  local tmp_dir watcher_pid exit_status output stderr_output expected_token target_token
  tmp_dir="$(setup_fixture_dir)"
  watcher_pid=""
  trap 'kill "${watcher_pid:-}" 2>/dev/null || true; cleanup_fixture_dir "$tmp_dir"' RETURN
  make_entr_stub "$tmp_dir"
  printf 'before\n' >"$tmp_dir/document.txt"
  expected_token="$(file_token "$tmp_dir/document.txt")"

  PATH="$tmp_dir/bin:/usr/bin:/bin" TEST_STATE_DIR="$tmp_dir/state" \
    "$SCRIPT_PATH" --token "$expected_token" "$tmp_dir/document.txt" >"$tmp_dir/output" 2>"$tmp_dir/stderr" &
  watcher_pid=$!

  wait_for_file "$tmp_dir/state/ready"
  printf 'after\n' >"$tmp_dir/document.txt"
  target_token="$(file_token "$tmp_dir/document.txt")"
  : >"$tmp_dir/state/changed"

  set +e
  wait "$watcher_pid"
  exit_status=$?
  set -e
  output="$(cat "$tmp_dir/output")"
  stderr_output="$(cat "$tmp_dir/stderr")"

  [[ "$exit_status" -eq 0 ]] || fail "expected zero exit status, got $exit_status"
  assert_contains "$output" "-before"
  assert_contains "$output" "+after"
  assert_contains "$stderr_output" "Change detected. Current version: $target_token"
}

test_stale_token_returns_immediately_without_starting_a_watcher() {
  local tmp_dir output exit_status current_token
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN
  make_entr_stub "$tmp_dir"
  printf 'current\n' >"$tmp_dir/document.txt"
  current_token="$(file_token "$tmp_dir/document.txt")"

  set +e
  output="$(PATH="$tmp_dir/bin:/usr/bin:/bin" TEST_STATE_DIR="$tmp_dir/state" \
    "$SCRIPT_PATH" --token 00000 "$tmp_dir/document.txt" 2>&1)"
  exit_status=$?
  set -e

  [[ "$exit_status" -eq 3 ]] || fail "expected stale-token exit status 3, got $exit_status"
  assert_contains "$output" "File changed since version 00000. Current version: $current_token."
  [[ ! -f "$tmp_dir/state/ready" ]] || fail "stale token must not start entr"
}

test_changed_file_larger_than_one_megabyte_fails_without_diff() {
  local tmp_dir output exit_status watcher_pid
  tmp_dir="$(setup_fixture_dir)"
  watcher_pid=""
  trap 'kill "${watcher_pid:-}" 2>/dev/null || true; cleanup_fixture_dir "$tmp_dir"' RETURN
  make_entr_stub "$tmp_dir"
  printf 'before\n' >"$tmp_dir/document.txt"

  PATH="$tmp_dir/bin:/usr/bin:/bin" TEST_STATE_DIR="$tmp_dir/state" \
    "$SCRIPT_PATH" "$tmp_dir/document.txt" >"$tmp_dir/output" 2>"$tmp_dir/stderr" &
  watcher_pid=$!
  wait_for_file "$tmp_dir/state/ready"
  dd if=/dev/zero of="$tmp_dir/document.txt" bs=1048577 count=1 status=none
  : >"$tmp_dir/state/changed"

  set +e
  wait "$watcher_pid"
  exit_status=$?
  set -e
  output="$(cat "$tmp_dir/stderr")"

  [[ "$exit_status" -ne 0 ]] || fail "expected nonzero exit status for oversized changed file"
  assert_contains "$output" "1 MB"
}

test_timeout_emits_current_token_without_printing_a_diff() {
  local tmp_dir watcher_pid exit_status stderr_output expected_token
  tmp_dir="$(setup_fixture_dir)"
  watcher_pid=""
  trap 'kill "${watcher_pid:-}" 2>/dev/null || true; cleanup_fixture_dir "$tmp_dir"' RETURN
  make_entr_stub "$tmp_dir"
  printf 'unchanged\n' >"$tmp_dir/document.txt"
  expected_token="$(file_token "$tmp_dir/document.txt")"

  PATH="$tmp_dir/bin:/usr/bin:/bin" TEST_STATE_DIR="$tmp_dir/state" \
    "$SCRIPT_PATH" -t 1 "$tmp_dir/document.txt" >"$tmp_dir/output" 2>"$tmp_dir/stderr" &
  watcher_pid=$!
  wait_for_file "$tmp_dir/state/ready"

  set +e
  wait "$watcher_pid"
  exit_status=$?
  set -e
  stderr_output="$(cat "$tmp_dir/stderr")"

  [[ "$exit_status" -eq 124 ]] || fail "expected timeout exit status 124, got $exit_status"
  [[ ! -s "$tmp_dir/output" ]] || fail "expected no diff output on timeout"
  assert_contains "$stderr_output" "Timed out after 1 second"
  assert_contains "$stderr_output" "Last observed version: $expected_token"
}

test_timeout_detects_unreported_change_and_emits_diff() {
  local tmp_dir watcher_pid exit_status output stderr_output target_token
  tmp_dir="$(setup_fixture_dir)"
  watcher_pid=""
  trap 'kill "${watcher_pid:-}" 2>/dev/null || true; cleanup_fixture_dir "$tmp_dir"' RETURN
  make_entr_stub "$tmp_dir"
  printf 'before\n' >"$tmp_dir/document.txt"

  PATH="$tmp_dir/bin:/usr/bin:/bin" TEST_STATE_DIR="$tmp_dir/state" \
    "$SCRIPT_PATH" -t 1 "$tmp_dir/document.txt" >"$tmp_dir/output" 2>"$tmp_dir/stderr" &
  watcher_pid=$!
  wait_for_file "$tmp_dir/state/ready"
  printf 'after\n' >"$tmp_dir/document.txt"
  target_token="$(file_token "$tmp_dir/document.txt")"

  set +e
  wait "$watcher_pid"
  exit_status=$?
  set -e
  output="$(cat "$tmp_dir/output")"
  stderr_output="$(cat "$tmp_dir/stderr")"

  [[ "$exit_status" -eq 0 ]] || fail "expected detected change to exit zero, got $exit_status"
  assert_contains "$output" "-before"
  assert_contains "$output" "+after"
  assert_contains "$stderr_output" "Change detected. Current version: $target_token"
}

test_matching_token_watches_and_prints_unified_diff
test_stale_token_returns_immediately_without_starting_a_watcher
test_changed_file_larger_than_one_megabyte_fails_without_diff
test_timeout_emits_current_token_without_printing_a_diff
test_timeout_detects_unreported_change_and_emits_diff

echo "PASS: watchdiff"
