#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_PATH="$PROJECT_ROOT/agent-browser-cleanup.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "expected output to contain: $needle"$'\n'"actual output:"$'\n'"$haystack"
  fi
}

setup_fixture_dir() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  mkdir -p "$tmp_dir/home/.agent-browser" "$tmp_dir/stubs" "$tmp_dir/state"
  echo "$tmp_dir"
}

define_process() {
  local state_dir="$1"
  local pid="$2"
  local ppid="$3"
  local etime="$4"
  local command_line="$5"

  : >"$state_dir/alive.$pid"
  printf '%s\n' "$ppid" >"$state_dir/ppid.$pid"
  printf '%s\n' "$etime" >"$state_dir/etime.$pid"
  printf '%s\n' "$command_line" >"$state_dir/command.$pid"
}

make_stub_commands() {
  local stub_dir="$1"
  local state_dir="$2"

  cat >"$stub_dir/agent-browser" <<'EOF'
#!/bin/bash
set -euo pipefail

STATE_DIR="${TEST_STATE_DIR:?}"

if [ "$#" -ge 3 ] && [ "$1" = "--session" ] && [ "$3" = "close" ]; then
  if [ -f "$STATE_DIR/close-remove" ]; then
    while IFS= read -r pid; do
      [ -n "$pid" ] || continue
      rm -f "$STATE_DIR/alive.$pid"
    done <"$STATE_DIR/close-remove"
  fi
  exit 0
fi

exit 0
EOF
  chmod +x "$stub_dir/agent-browser"

  cat >"$stub_dir/pgrep" <<'EOF'
#!/bin/bash
set -euo pipefail

STATE_DIR="${TEST_STATE_DIR:?}"

parent_pid=""
pattern=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    -P)
      parent_pid="$2"
      shift 2
      ;;
    -f)
      pattern="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

[ -n "$parent_pid" ] || exit 1

for file in "$STATE_DIR"/alive.*; do
  [ -e "$file" ] || continue
  pid="${file##*.}"
  ppid_file="$STATE_DIR/ppid.$pid"
  command_file="$STATE_DIR/command.$pid"
  [ -f "$ppid_file" ] || continue
  [ "$(tr -d '[:space:]' <"$ppid_file")" = "$parent_pid" ] || continue
  if [ -n "$pattern" ]; then
    command_line="$(tr -d '\n' <"$command_file")"
    if [[ ! "$command_line" =~ $pattern ]]; then
      continue
    fi
  fi
  printf '%s\n' "$pid"
done
EOF
  chmod +x "$stub_dir/pgrep"

  cat >"$stub_dir/ps" <<'EOF'
#!/bin/bash
set -euo pipefail

STATE_DIR="${TEST_STATE_DIR:?}"

if [ "$#" -eq 2 ] && [ "$1" = "-p" ]; then
  pid="$2"
  [ -f "$STATE_DIR/alive.$pid" ] && exit 0
  exit 1
fi

if [ "$#" -eq 4 ] && [ "$1" = "-p" ] && [ "$3" = "-o" ] && [ "$4" = "command=" ]; then
  pid="$2"
  [ -f "$STATE_DIR/alive.$pid" ] || exit 1
  tr -d '\n' <"$STATE_DIR/command.$pid"
  printf '\n'
  exit 0
fi

if [ "$#" -eq 4 ] && [ "$1" = "-p" ] && [ "$3" = "-o" ] && [ "$4" = "etime=" ]; then
  pid="$2"
  [ -f "$STATE_DIR/alive.$pid" ] || exit 1
  tr -d '\n' <"$STATE_DIR/etime.$pid"
  printf '\n'
  exit 0
fi

if [ "$#" -eq 2 ] && [ "$1" = "-axo" ] && [ "$2" = "pid=,command=" ]; then
  for file in "$STATE_DIR"/alive.*; do
    [ -e "$file" ] || continue
    pid="${file##*.}"
    printf '%s ' "$pid"
    tr -d '\n' <"$STATE_DIR/command.$pid"
    printf '\n'
  done | sort -n
  exit 0
fi

exit 1
EOF
  chmod +x "$stub_dir/ps"

  cat >"$stub_dir/kill" <<'EOF'
#!/bin/bash
set -euo pipefail

STATE_DIR="${TEST_STATE_DIR:?}"
signal="TERM"

if [ "$1" = "-9" ]; then
  signal="KILL"
  shift
fi

for pid in "$@"; do
  printf '%s %s\n' "$signal" "$pid" >>"$STATE_DIR/kill.log"
  rm -f "$STATE_DIR/alive.$pid"
done
EOF
  chmod +x "$stub_dir/kill"

  cat >"$stub_dir/sleep" <<'EOF'
#!/bin/bash
set -euo pipefail

STATE_DIR="${TEST_STATE_DIR:?}"

count_file="$STATE_DIR/sleep-count"
count=0
if [ -f "$count_file" ]; then
  count="$(tr -d '[:space:]' <"$count_file")"
fi
count=$((count + 1))
printf '%s\n' "$count" >"$count_file"

if [ -f "$STATE_DIR/delayed-remove-after" ] && [ -f "$STATE_DIR/delayed-remove" ]; then
  target="$(tr -d '[:space:]' <"$STATE_DIR/delayed-remove-after")"
  if [ "$count" -ge "$target" ]; then
    while IFS= read -r pid; do
      [ -n "$pid" ] || continue
      rm -f "$STATE_DIR/alive.$pid"
    done <"$STATE_DIR/delayed-remove"
    rm -f "$STATE_DIR/delayed-remove" "$STATE_DIR/delayed-remove-after"
  fi
elif [ -f "$STATE_DIR/delayed-remove" ]; then
  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    rm -f "$STATE_DIR/alive.$pid"
  done <"$STATE_DIR/delayed-remove"
  rm -f "$STATE_DIR/delayed-remove"
fi

exit 0
EOF
  chmod +x "$stub_dir/sleep"
}

run_cleanup() {
  local work_dir="$1"
  local extra_args="$2"

  HOME="$work_dir/home" TEST_STATE_DIR="$work_dir/state" AGENT_BROWSER_CLEANUP_KILL_HELPER="$work_dir/stubs/kill" PATH="$work_dir/stubs:/usr/bin:/bin:/usr/sbin:/sbin" \
    "$SCRIPT_PATH" --minutes 60 $extra_args
}

test_native_agent_browser_binary_is_detected() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'rm -rf "$tmp_dir"' RETURN

  printf '12345\n' >"$tmp_dir/home/.agent-browser/test-session.pid"
  define_process \
    "$tmp_dir/state" \
    "12345" \
    "1" \
    "01:30:00" \
    "/opt/homebrew/lib/node_modules/agent-browser/bin/agent-browser-darwin-arm64"
  make_stub_commands "$tmp_dir/stubs" "$tmp_dir/state"

  local output
  output="$(run_cleanup "$tmp_dir" "--dry-run")"

  assert_contains "$output" "CLOSE test-session: pid=12345 age=90m"
}

test_legacy_daemon_js_command_still_works() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'rm -rf "$tmp_dir"' RETURN

  printf '12345\n' >"$tmp_dir/home/.agent-browser/legacy-session.pid"
  define_process \
    "$tmp_dir/state" \
    "12345" \
    "1" \
    "02:00:00" \
    "node /opt/homebrew/lib/node_modules/agent-browser/daemon.js --session legacy-session"
  make_stub_commands "$tmp_dir/stubs" "$tmp_dir/state"

  local output
  output="$(run_cleanup "$tmp_dir" "--dry-run")"

  assert_contains "$output" "CLOSE legacy-session: pid=12345 age=120m"
}

test_lingering_browser_processes_are_reported_as_failure() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'rm -rf "$tmp_dir"' RETURN

  printf '12345\n' >"$tmp_dir/home/.agent-browser/leaky-session.pid"
  define_process \
    "$tmp_dir/state" \
    "12345" \
    "1" \
    "02:00:00" \
    "/opt/homebrew/lib/node_modules/agent-browser/bin/agent-browser-darwin-arm64"
  define_process \
    "$tmp_dir/state" \
    "23456" \
    "12345" \
    "01:59:59" \
    "/path/Google Chrome for Testing --user-data-dir=/tmp/agent-browser-chrome-test-a"
  define_process \
    "$tmp_dir/state" \
    "34567" \
    "23456" \
    "01:59:58" \
    "/path/Google Chrome for Testing Helper (Renderer) --user-data-dir=/tmp/agent-browser-chrome-test-a"
  printf '12345\n' >"$tmp_dir/state/close-remove"
  make_stub_commands "$tmp_dir/stubs" "$tmp_dir/state"

  local output
  output="$(run_cleanup "$tmp_dir" "")"

  assert_contains "$output" "WARN  leaky-session: related browser processes still running"
}

test_force_kill_terminates_related_processes() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'rm -rf "$tmp_dir"' RETURN

  printf '12345\n' >"$tmp_dir/home/.agent-browser/sticky-session.pid"
  define_process \
    "$tmp_dir/state" \
    "12345" \
    "1" \
    "02:00:00" \
    "/opt/homebrew/lib/node_modules/agent-browser/bin/agent-browser-darwin-arm64"
  define_process \
    "$tmp_dir/state" \
    "23456" \
    "12345" \
    "01:59:59" \
    "/path/Google Chrome for Testing --user-data-dir=/tmp/agent-browser-chrome-test-b"
  define_process \
    "$tmp_dir/state" \
    "34567" \
    "23456" \
    "01:59:58" \
    "/path/Google Chrome for Testing Helper (Renderer) --user-data-dir=/tmp/agent-browser-chrome-test-b"
  : >"$tmp_dir/state/close-remove"
  make_stub_commands "$tmp_dir/stubs" "$tmp_dir/state"

  local output
  output="$(run_cleanup "$tmp_dir" "--force-kill")"

  assert_contains "$output" "OK    sticky-session closed"
  assert_contains "$(tr '\n' ' ' <"$tmp_dir/state/kill.log")" "TERM 12345"
}

test_force_kill_uses_known_descendants_when_marker_matches_are_incomplete() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'rm -rf "$tmp_dir"' RETURN

  printf '12345\n' >"$tmp_dir/home/.agent-browser/misaligned-session.pid"
  define_process \
    "$tmp_dir/state" \
    "12345" \
    "1" \
    "02:00:00" \
    "/opt/homebrew/lib/node_modules/agent-browser/bin/agent-browser-darwin-arm64"
  define_process \
    "$tmp_dir/state" \
    "23456" \
    "12345" \
    "01:59:59" \
    "/path/Google Chrome for Testing --window-size=1280,720"
  define_process \
    "$tmp_dir/state" \
    "34567" \
    "23456" \
    "01:59:58" \
    "/path/Google Chrome for Testing Helper (Renderer) --user-data-dir=/tmp/agent-browser-chrome-test-c"
  : >"$tmp_dir/state/close-remove"
  make_stub_commands "$tmp_dir/stubs" "$tmp_dir/state"

  local output
  output="$(run_cleanup "$tmp_dir" "--force-kill")"

  assert_contains "$output" "OK    misaligned-session closed"
  assert_contains "$(tr '\n' ' ' <"$tmp_dir/state/kill.log")" "TERM 23456"
}

test_transient_marker_process_is_rechecked_before_failure() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'rm -rf "$tmp_dir"' RETURN

  printf '12345\n' >"$tmp_dir/home/.agent-browser/transient-session.pid"
  define_process \
    "$tmp_dir/state" \
    "12345" \
    "1" \
    "02:00:00" \
    "/opt/homebrew/lib/node_modules/agent-browser/bin/agent-browser-darwin-arm64"
  define_process \
    "$tmp_dir/state" \
    "23456" \
    "12345" \
    "01:59:59" \
    "/path/Google Chrome for Testing --user-data-dir=/tmp/agent-browser-chrome-test-d"
  define_process \
    "$tmp_dir/state" \
    "34567" \
    "23456" \
    "01:59:58" \
    "/path/Google Chrome for Testing Helper (Renderer) --user-data-dir=/tmp/agent-browser-chrome-test-d"
  printf '12345\n23456\n34567\n' >"$tmp_dir/state/close-remove"
  printf '45678\n' >"$tmp_dir/state/delayed-remove"
  printf '7\n' >"$tmp_dir/state/delayed-remove-after"
  define_process \
    "$tmp_dir/state" \
    "45678" \
    "1" \
    "00:00:01" \
    "/path/Google Chrome for Testing Helper (Renderer) --user-data-dir=/tmp/agent-browser-chrome-test-d"
  make_stub_commands "$tmp_dir/stubs" "$tmp_dir/state"

  local output
  output="$(run_cleanup "$tmp_dir" "")"

  assert_contains "$output" "OK    transient-session closed"
}

test_native_agent_browser_binary_is_detected
test_legacy_daemon_js_command_still_works
test_lingering_browser_processes_are_reported_as_failure
test_force_kill_terminates_related_processes
test_force_kill_uses_known_descendants_when_marker_matches_are_incomplete
test_transient_marker_process_is_rechecked_before_failure

echo "PASS: agent-browser-cleanup"
