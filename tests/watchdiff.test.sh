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

wait_for_file() {
  local path="$1"
  local attempts=100

  while [[ ! -f "$path" && "$attempts" -gt 0 ]]; do
    sleep 0.01
    attempts=$((attempts - 1))
  done
  [[ -f "$path" ]] || fail "timed out waiting for: $path"
}

test_changed_file_prints_unified_diff_and_exits_zero() {
  local tmp_dir output_file watcher_pid exit_status output
  tmp_dir="$(setup_fixture_dir)"
  watcher_pid=""
  trap 'kill "${watcher_pid:-}" 2>/dev/null || true; cleanup_fixture_dir "$tmp_dir"' RETURN
  make_entr_stub "$tmp_dir"
  printf 'before\n' >"$tmp_dir/document.txt"

  PATH="$tmp_dir/bin:/usr/bin:/bin" TEST_STATE_DIR="$tmp_dir/state" \
    "$SCRIPT_PATH" "$tmp_dir/document.txt" >"$tmp_dir/output" 2>"$tmp_dir/stderr" &
  watcher_pid=$!

  wait_for_file "$tmp_dir/state/ready"
  printf 'after\n' >"$tmp_dir/document.txt"
  : >"$tmp_dir/state/changed"

  set +e
  wait "$watcher_pid"
  exit_status=$?
  set -e
  output="$(cat "$tmp_dir/output")"

  [[ "$exit_status" -eq 0 ]] || fail "expected zero exit status, got $exit_status"
  assert_contains "$output" "-before"
  assert_contains "$output" "+after"
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

test_changed_file_prints_unified_diff_and_exits_zero
test_changed_file_larger_than_one_megabyte_fails_without_diff

echo "PASS: watchdiff"
