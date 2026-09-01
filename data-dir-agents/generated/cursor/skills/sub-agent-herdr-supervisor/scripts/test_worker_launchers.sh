#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFINITIONS_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RUNTIME="$DEFINITIONS_DIR/runtime/pi-worker-runtime.sh"
CMUX_ADAPTER="$DEFINITIONS_DIR/skills/sub-agent-cmux-supervisor/scripts/cmux-worker.sh"
HERDR_ADAPTER="$SCRIPT_DIR/herdr-worker.sh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -r "$TMPDIR_TEST"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_capture() {
  local capture="$1"
  shift
  local expected actual
  expected="$(printf '%s\n' "$@")"
  actual="$(<"$capture")"
  [ "$actual" = "$expected" ] || fail "unexpected Pi invocation: $actual"
}

mkdir -p "$TMPDIR_TEST/bin" \
  "$TMPDIR_TEST/home/.pi/profiles/minimal/agent/extensions" \
  "$TMPDIR_TEST/home/.pi/profiles/partner/agent/extensions"
: >"$TMPDIR_TEST/home/.pi/profiles/minimal/agent/extensions/herdr-agent-state.ts"
: >"$TMPDIR_TEST/home/.pi/profiles/partner/agent/extensions/herdr-agent-state.ts"
cat >"$TMPDIR_TEST/bin/pi-profile" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$2 $3 $4" == "auth check --provider" ]]; then
  case "$5" in
    openai-codex) [ "${AUTH_OPENAI:-ready}" = ready ] && printf 'ready\n' ;;
    github-copilot) [ "${AUTH_COPILOT:-unready}" = ready ] && printf 'ready\n' ;;
  esac
  exit 0
fi
printf 'PI_WRITE_GUARD_DIRS=%s\n' "${PI_WRITE_GUARD_DIRS:-}" >"$PI_PROFILE_CAPTURE"
printf '%s\n' "$@" >>"$PI_PROFILE_CAPTURE"
EOF
chmod +x "$TMPDIR_TEST/bin/pi-profile"

compose_skill() {
  local name="$1"
  local adapter="$2"
  local package="$TMPDIR_TEST/$name/scripts"
  mkdir -p "$package"
  cp "$adapter" "$package/worker.sh"
  cp "$RUNTIME" "$package/pi-worker-runtime.sh"
  chmod +x "$package/worker.sh"
  printf '%s\n' "$package/worker.sh"
}

cmux_worker="$(compose_skill cmux "$CMUX_ADAPTER")"
herdr_worker="$(compose_skill herdr "$HERDR_ADAPTER")"

run_worker() {
  local worker="$1"
  local capture="$2"
  PATH="$TMPDIR_TEST/bin:$PATH" HOME="$TMPDIR_TEST/home" PI_PROFILE_CAPTURE="$capture" \
    AUTH_OPENAI="${AUTH_OPENAI:-ready}" AUTH_COPILOT="${AUTH_COPILOT:-unready}" \
    "$worker" --mode readonly -- @/tmp/handoff.md 'Execute the bounded task.'
}

assert_invalid_arguments() {
  local invalid_output
  if invalid_output="$(PATH="$TMPDIR_TEST/bin:$PATH" HOME="$TMPDIR_TEST/home" "$cmux_worker" "$@" 2>&1)"; then
    fail "CMUX worker accepted invalid arguments: $*"
  fi
  grep -q 'requires exactly one --mode readonly|editable before --' <<<"$invalid_output" \
    || fail "CMUX worker did not explain invalid arguments: $*"
}

assert_invalid_arguments -- @/tmp/handoff.md
assert_invalid_arguments --mode readonly --mode editable -- @/tmp/handoff.md
assert_invalid_arguments --mode unsafe -- @/tmp/handoff.md
assert_invalid_arguments --mode readonly @/tmp/handoff.md

editable_capture="$TMPDIR_TEST/editable.txt"
PATH="$TMPDIR_TEST/bin:$PATH" HOME="$TMPDIR_TEST/home" PI_PROFILE_CAPTURE="$editable_capture" \
  "$cmux_worker" --mode editable -- @/tmp/handoff.md 'Execute the bounded task.'
assert_capture "$editable_capture" \
  'PI_WRITE_GUARD_DIRS=.' \
  minimal -ne -e 'https://github.com/cgint/pi-focus-guard' \
  --model openai-codex/gpt-5.6-terra --thinking minimal \
  @/tmp/handoff.md 'Execute the bounded task.'

fallback_capture="$TMPDIR_TEST/fallback.txt"
AUTH_OPENAI=unready AUTH_COPILOT=ready run_worker "$cmux_worker" "$fallback_capture"
grep -qx 'github-copilot/gpt-5.6-terra' "$fallback_capture" \
  || fail 'CMUX worker did not fall back to the GitHub Copilot model'

cmux_capture="$TMPDIR_TEST/cmux.txt"
run_worker "$cmux_worker" "$cmux_capture"
grep -qx 'PI_WRITE_GUARD_DIRS=\.' "$cmux_capture" || fail 'CMUX worker did not set the cwd write guard'
grep -qx -- '--tools' "$cmux_capture" || fail 'CMUX worker omitted read-only tool restriction'
grep -qx 'read,bash,grep,find,ls' "$cmux_capture" || fail 'CMUX worker omitted classified read-only tools'
grep -qx -- '--dm-read' "$cmux_capture" || fail 'CMUX worker omitted read-only mode'
if grep -q 'herdr-agent-state.ts' "$cmux_capture"; then
  fail 'CMUX worker loaded Herdr reporting behavior'
fi

herdr_capture="$TMPDIR_TEST/herdr.txt"
run_worker "$herdr_worker" "$herdr_capture"
grep -qx 'PI_WRITE_GUARD_DIRS=\.' "$herdr_capture" || fail 'Herdr worker did not set the cwd write guard'
grep -qx "$TMPDIR_TEST/home/.pi/profiles/minimal/agent/extensions/herdr-agent-state.ts" "$herdr_capture" \
  || fail 'Herdr worker did not use the default minimal lifecycle reporter'
grep -qx 'minimal' "$herdr_capture" \
  || fail 'Herdr worker did not use the default minimal profile'

partner_capture="$TMPDIR_TEST/partner.txt"
PI_WORKER_PROFILE=partner run_worker "$cmux_worker" "$partner_capture"
grep -qx 'partner' "$partner_capture" \
  || fail 'CMUX worker did not honor PI_WORKER_PROFILE override'

partner_herdr_capture="$TMPDIR_TEST/partner-herdr.txt"
PI_WORKER_PROFILE=partner run_worker "$herdr_worker" "$partner_herdr_capture"
grep -qx 'partner' "$partner_herdr_capture" \
  || fail 'Herdr worker did not honor PI_WORKER_PROFILE override'
grep -qx "$TMPDIR_TEST/home/.pi/profiles/partner/agent/extensions/herdr-agent-state.ts" "$partner_herdr_capture" \
  || fail 'Herdr worker did not derive its reporter from PI_WORKER_PROFILE'

if invalid_profile_output="$(PI_WORKER_PROFILE='../unsafe' run_worker "$cmux_worker" "$TMPDIR_TEST/invalid.txt" 2>&1)"; then
  fail 'CMUX worker accepted an invalid PI_WORKER_PROFILE'
fi
grep -q 'invalid PI_WORKER_PROFILE: ../unsafe' <<<"$invalid_profile_output" \
  || fail 'CMUX worker did not explain the rejected PI_WORKER_PROFILE'

if override_output="$(PATH="$TMPDIR_TEST/bin:$PATH" HOME="$TMPDIR_TEST/home" PI_PROFILE_CAPTURE="$TMPDIR_TEST/override.txt" "$cmux_worker" --mode editable -- --model unsafe 2>&1)"; then
  fail 'CMUX worker accepted a caller model override'
fi
grep -q 'caller may not override launcher configuration: --model' <<<"$override_output" \
  || fail 'CMUX worker did not explain the rejected override'

printf 'PASS: self-contained CMUX and Herdr worker launcher contracts\n'
