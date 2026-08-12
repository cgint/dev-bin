#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_PATH="$PROJECT_ROOT/md2html"

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
  mktemp -d
}

cleanup_fixture_dir() {
  local tmp_dir="$1"
  rm -rf "$tmp_dir"
}

test_help_flag_short() {
  local output exit_status
  set +e
  output="$("$SCRIPT_PATH" -h 2>&1)"
  exit_status=$?
  set -e

  [[ "$exit_status" -eq 0 ]] || fail "expected zero exit status for -h, got $exit_status"
  assert_contains "$output" "Usage: md2html [options] <file.md>"
  assert_contains "$output" "beautifully styled HTML"
  assert_contains "$output" "-h, --help"
}

test_help_flag_long() {
  local output exit_status
  set +e
  output="$("$SCRIPT_PATH" --help 2>&1)"
  exit_status=$?
  set -e

  [[ "$exit_status" -eq 0 ]] || fail "expected zero exit status for --help, got $exit_status"
  assert_contains "$output" "Usage: md2html [options] <file.md>"
  assert_contains "$output" "beautifully styled HTML"
  assert_contains "$output" "-h, --help"
}

test_no_arguments() {
  local output exit_status
  set +e
  output="$("$SCRIPT_PATH" 2>&1)"
  exit_status=$?
  set -e

  [[ "$exit_status" -eq 1 ]] || fail "expected exit status 1 for no args, got $exit_status"
  assert_contains "$output" "Usage: md2html [options] <file.md>"
}

test_too_many_arguments() {
  local output exit_status
  set +e
  output="$("$SCRIPT_PATH" arg1 arg2 2>&1)"
  exit_status=$?
  set -e

  [[ "$exit_status" -eq 1 ]] || fail "expected exit status 1 for multiple args, got $exit_status"
  assert_contains "$output" "Usage: md2html [options] <file.md>"
}

test_successful_conversion() {
  local tmp_dir output exit_status
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN

  echo "# Test Title" > "$tmp_dir/test.md"
  echo "This is some test markdown." >> "$tmp_dir/test.md"

  set +e
  output="$("$SCRIPT_PATH" "$tmp_dir/test.md" 2>&1)"
  exit_status=$?
  set -e

  [[ "$exit_status" -eq 0 ]] || fail "expected successful conversion, got $exit_status"
  [[ -f "$tmp_dir/test.html" ]] || fail "expected output html file to be created"
  
  local html_content
  html_content="$(cat "$tmp_dir/test.html")"
  assert_contains "$html_content" "Test Title"
  assert_contains "$html_content" "This is some test markdown."
  assert_contains "$output" "→ $tmp_dir/test.html"
}

test_open_option() {
  local tmp_dir output exit_status
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN

  # Create a stub 'open' command that writes to a file when called
  mkdir -p "$tmp_dir/bin"
  cat >"$tmp_dir/bin/open" <<'EOF'
#!/bin/bash
echo "MOCKED_OPEN_CALLED: $1" > "$TEST_OPEN_CALL_LOG"
EOF
  chmod +x "$tmp_dir/bin/open"

  echo "# Test Title" > "$tmp_dir/test.md"
  
  export TEST_OPEN_CALL_LOG="$tmp_dir/open_call.log"
  set +e
  output="$(PATH="$tmp_dir/bin:$PATH" "$SCRIPT_PATH" --open "$tmp_dir/test.md" 2>&1)"
  exit_status=$?
  set -e

  [[ "$exit_status" -eq 0 ]] || fail "expected successful conversion with --open, got $exit_status"
  [[ -f "$tmp_dir/test.html" ]] || fail "expected output html file to be created"
  [[ -f "$tmp_dir/open_call.log" ]] || fail "expected mocked open command to be called"
  
  local open_log_content
  open_log_content="$(cat "$tmp_dir/open_call.log")"
  assert_contains "$open_log_content" "MOCKED_OPEN_CALLED: $tmp_dir/test.html"
}

test_help_flag_short
test_help_flag_long
test_no_arguments
test_too_many_arguments
test_successful_conversion
test_open_option

echo "PASS: md2html"
