#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_PATH="$PROJECT_ROOT/subagent.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_equals() {
  local actual="$1"
  local expected="$2"
  [[ "$actual" == "$expected" ]] || fail "expected:$'\n'$expected$'\n'actual:$'\n'$actual"
}

setup_fixture_dir() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  mkdir -p "$tmp_dir/bin" "$tmp_dir/home/dev-external/pi-focus-guard" \
    "$tmp_dir/home/.pi/profiles/partner/agent/extensions"
  : >"$tmp_dir/home/dev-external/pi-focus-guard/index.ts"
  : >"$tmp_dir/home/.pi/profiles/partner/agent/extensions/herdr-agent-state.ts"
  printf '%s\n' "$tmp_dir"
}

cleanup_fixture_dir() {
  local tmp_dir="$1"
  local tmp_root="${TMPDIR:-/tmp}"
  tmp_root="${tmp_root%/}"

  [[ -d "$tmp_dir" && "$tmp_dir" == "$tmp_root"/tmp.* ]] \
    || fail "refusing to clean unexpected fixture directory: $tmp_dir"
  find "$tmp_dir" -depth -mindepth 1 -delete
  rmdir "$tmp_dir"
}

make_pi_profile_stub() {
  local tmp_dir="$1"
  cat >"$tmp_dir/bin/pi-profile" <<'EOF'
#!/bin/bash
set -euo pipefail

if [[ "$1" == "partner" && "$2" == "auth" && "$3" == "check" && "$4" == "--provider" ]]; then
  case "$5" in
    openai-codex) [[ "${AUTH_OPENAI:-ready}" == "ready" ]] && printf 'ready\n' ;;
    github-copilot) [[ "${AUTH_COPILOT:-unready}" == "ready" ]] && printf 'ready\n' ;;
  esac
  exit 0
fi

printf '%s\n' "$@" >"${ARGV_FILE:?}"
EOF
  chmod +x "$tmp_dir/bin/pi-profile"
}

run_wrapper() {
  local tmp_dir="$1"
  shift
  HOME="$tmp_dir/home" PATH="$tmp_dir/bin:/usr/bin:/bin" ARGV_FILE="$tmp_dir/argv" \
    AUTH_OPENAI="${AUTH_OPENAI:-ready}" AUTH_COPILOT="${AUTH_COPILOT:-unready}" \
    HERDR_ENV="${TEST_HERDR_ENV:-}" "$SCRIPT_PATH" "$@"
}

assert_argv() {
  local tmp_dir="$1"
  shift
  local expected actual
  expected="$(printf '%s\n' "$@")"
  actual="$(<"$tmp_dir/argv")"
  assert_equals "$actual" "$expected"
}

assert_no_argv_argument() {
  local tmp_dir="$1"
  local argument="$2"
  ! grep -Fx -- "$argument" "$tmp_dir/argv" \
    || fail "Pi invocation must not receive wrapper delimiter: $argument"
}

test_no_forbidden_recursive_cleanup() {
  local forbidden_command="rm -r""f"
  if grep -F -- "$forbidden_command" "$BASH_SOURCE" >/dev/null; then
    fail "test file must not contain the forbidden recursive cleanup command"
  fi
}

test_requires_one_mode_before_delimiter() {
  local tmp_dir output status
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN
  make_pi_profile_stub "$tmp_dir"

  set +e
  output="$(run_wrapper "$tmp_dir" -- @handoff 2>&1)"
  status=$?
  set -e
  [[ "$status" -eq 2 ]] || fail "missing mode should exit 2, got $status"
  assert_contains "$output" 'requires exactly one --mode readonly|editable before --'

  set +e
  output="$(run_wrapper "$tmp_dir" --mode readonly --mode editable -- @handoff 2>&1)"
  status=$?
  set -e
  [[ "$status" -eq 2 ]] || fail "duplicate mode should exit 2, got $status"
  assert_contains "$output" 'requires exactly one --mode readonly|editable before --'

  set +e
  output="$(run_wrapper "$tmp_dir" --mode readonly @handoff 2>&1)"
  status=$?
  set -e
  [[ "$status" -eq 2 ]] || fail "missing delimiter should exit 2, got $status"
}

test_editable_effective_arguments_and_forwarding() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN
  make_pi_profile_stub "$tmp_dir"

  run_wrapper "$tmp_dir" --mode editable -- @handoff 'worker instruction'
  assert_argv "$tmp_dir" partner -ne --model openai-codex/gpt-5.6-terra --thinking minimal @handoff 'worker instruction'
}

test_readonly_effective_arguments() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN
  make_pi_profile_stub "$tmp_dir"

  run_wrapper "$tmp_dir" --mode readonly -- @handoff 'worker instruction'
  assert_argv "$tmp_dir" partner -ne -e "$tmp_dir/home/dev-external/pi-focus-guard/index.ts" --model openai-codex/gpt-5.6-terra --thinking minimal --tools read,bash,grep,find,ls --dm-read @handoff 'worker instruction'
}

test_protected_flags_are_rejected_after_delimiter() {
  local tmp_dir output status
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN
  make_pi_profile_stub "$tmp_dir"

  for flag in --print --extension --model --provider --thinking --tools --dm-off --dm-read --dm-block; do
    set +e
    output="$(run_wrapper "$tmp_dir" --mode readonly -- "$flag" @handoff 2>&1)"
    status=$?
    set -e
    [[ "$status" -eq 2 ]] || fail "protected flag $flag should exit 2, got $status"
    assert_contains "$output" 'caller may not override wrapper configuration'
  done
}

test_missing_security_dependencies_fail_closed() {
  local tmp_dir output status
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN
  make_pi_profile_stub "$tmp_dir"
  rm -f "$tmp_dir/home/dev-external/pi-focus-guard/index.ts"

  set +e
  output="$(run_wrapper "$tmp_dir" --mode readonly -- @handoff 2>&1)"
  status=$?
  set -e
  [[ "$status" -eq 1 ]] || fail "missing focus guard should exit 1, got $status"
  assert_contains "$output" 'pi-focus-guard not found'

  : >"$tmp_dir/home/dev-external/pi-focus-guard/index.ts"
  rm -f "$tmp_dir/home/.pi/profiles/partner/agent/extensions/herdr-agent-state.ts"
  set +e
  output="$(TEST_HERDR_ENV=1 run_wrapper "$tmp_dir" --mode editable -- @handoff 2>&1)"
  status=$?
  set -e
  [[ "$status" -eq 1 ]] || fail "missing Herdr reporter should exit 1, got $status"
  assert_contains "$output" 'Herdr Pi reporter not found'
}

test_auth_fallback_and_herdr_reporter() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN
  make_pi_profile_stub "$tmp_dir"

  AUTH_OPENAI=unready AUTH_COPILOT=ready TEST_HERDR_ENV=1 \
    run_wrapper "$tmp_dir" --mode editable -- @handoff
  assert_argv "$tmp_dir" partner -ne -e "$tmp_dir/home/.pi/profiles/partner/agent/extensions/herdr-agent-state.ts" --model github-copilot/gpt-5.6-terra --thinking minimal @handoff
}

test_wrapper_delimiter_is_not_forwarded_to_pi_profile() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN
  make_pi_profile_stub "$tmp_dir"

  run_wrapper "$tmp_dir" --mode editable -- @handoff
  assert_no_argv_argument "$tmp_dir" --
}

test_requires_valid_mode() {
  local tmp_dir output status
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN
  make_pi_profile_stub "$tmp_dir"

  set +e
  output="$(run_wrapper "$tmp_dir" --mode unsafe -- @handoff 2>&1)"
  status=$?
  set -e
  [[ "$status" -eq 2 ]] || fail "invalid mode should exit 2, got $status"
  assert_contains "$output" 'requires exactly one --mode readonly|editable before --'
}

test_no_forbidden_recursive_cleanup
test_requires_one_mode_before_delimiter
test_editable_effective_arguments_and_forwarding
test_readonly_effective_arguments
test_protected_flags_are_rejected_after_delimiter
test_missing_security_dependencies_fail_closed
test_auth_fallback_and_herdr_reporter
test_wrapper_delimiter_is_not_forwarded_to_pi_profile
test_requires_valid_mode

echo "PASS: subagent"
