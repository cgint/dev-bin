#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME="$SCRIPT_DIR/pi-worker-runtime.sh"
HERDR_ADAPTER="$SCRIPT_DIR/herdr-worker.sh"
STARTER="$SCRIPT_DIR/herdr-start-subagent.sh"
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

compose_worker() {
  local package="$TMPDIR_TEST/herdr/scripts"
  mkdir -p "$package"
  cp "$HERDR_ADAPTER" "$package/worker.sh"
  cp "$RUNTIME" "$package/pi-worker-runtime.sh"
  chmod +x "$package/worker.sh"
  printf '%s\n' "$package/worker.sh"
}

herdr_worker="$(compose_worker)"

run_worker() {
  local capture="$1"
  PATH="$TMPDIR_TEST/bin:$PATH" HOME="$TMPDIR_TEST/home" PI_PROFILE_CAPTURE="$capture" \
    AUTH_OPENAI="${AUTH_OPENAI:-ready}" AUTH_COPILOT="${AUTH_COPILOT:-unready}" \
    "$herdr_worker" --mode readonly -- @/tmp/handoff.md 'Execute the bounded task.'
}

assert_invalid_arguments() {
  local invalid_output
  if invalid_output="$(PATH="$TMPDIR_TEST/bin:$PATH" HOME="$TMPDIR_TEST/home" "$herdr_worker" "$@" 2>&1)"; then
    fail "Herdr worker accepted invalid arguments: $*"
  fi
  grep -q 'requires exactly one --mode readonly|editable before --' <<<"$invalid_output" \
    || fail "Herdr worker did not explain invalid arguments: $*"
}

assert_invalid_arguments -- @/tmp/handoff.md
assert_invalid_arguments --mode readonly --mode editable -- @/tmp/handoff.md
assert_invalid_arguments --mode unsafe -- @/tmp/handoff.md
assert_invalid_arguments --mode readonly @/tmp/handoff.md

editable_capture="$TMPDIR_TEST/editable.txt"
PATH="$TMPDIR_TEST/bin:$PATH" HOME="$TMPDIR_TEST/home" PI_PROFILE_CAPTURE="$editable_capture" \
  "$herdr_worker" --mode editable -- @/tmp/handoff.md 'Execute the bounded task.'
assert_capture "$editable_capture" \
  'PI_WRITE_GUARD_DIRS=.' \
  minimal -ne -e 'https://github.com/cgint/pi-focus-guard' \
  -e "$TMPDIR_TEST/home/.pi/profiles/minimal/agent/extensions/herdr-agent-state.ts" \
  --model openai-codex/gpt-5.6-terra --thinking minimal \
  @/tmp/handoff.md 'Execute the bounded task.'

fallback_capture="$TMPDIR_TEST/fallback.txt"
AUTH_OPENAI=unready AUTH_COPILOT=ready run_worker "$fallback_capture"
grep -qx 'github-copilot/gpt-5.6-terra' "$fallback_capture" \
  || fail 'Herdr worker did not fall back to the GitHub Copilot model'

herdr_capture="$TMPDIR_TEST/herdr.txt"
run_worker "$herdr_capture"
grep -qx 'PI_WRITE_GUARD_DIRS=\.' "$herdr_capture" || fail 'Herdr worker did not set the cwd write guard'
grep -qx "$TMPDIR_TEST/home/.pi/profiles/minimal/agent/extensions/herdr-agent-state.ts" "$herdr_capture" \
  || fail 'Herdr worker did not use the default minimal lifecycle reporter'
grep -qx 'minimal' "$herdr_capture" \
  || fail 'Herdr worker did not use the default minimal profile'

partner_capture="$TMPDIR_TEST/partner.txt"
PI_WORKER_PROFILE=partner run_worker "$partner_capture"
grep -qx 'partner' "$partner_capture" \
  || fail 'Herdr worker did not honor PI_WORKER_PROFILE override'
grep -qx "$TMPDIR_TEST/home/.pi/profiles/partner/agent/extensions/herdr-agent-state.ts" "$partner_capture" \
  || fail 'Herdr worker did not derive its reporter from PI_WORKER_PROFILE'

if invalid_profile_output="$(PI_WORKER_PROFILE='../unsafe' run_worker "$TMPDIR_TEST/invalid.txt" 2>&1)"; then
  fail 'Herdr worker accepted an invalid PI_WORKER_PROFILE'
fi
grep -q 'invalid PI_WORKER_PROFILE: ../unsafe' <<<"$invalid_profile_output" \
  || fail 'Herdr worker did not explain the rejected PI_WORKER_PROFILE'

if override_output="$(PATH="$TMPDIR_TEST/bin:$PATH" HOME="$TMPDIR_TEST/home" PI_PROFILE_CAPTURE="$TMPDIR_TEST/override.txt" "$herdr_worker" --mode editable -- --model unsafe 2>&1)"; then
  fail 'Herdr worker accepted a caller model override'
fi
grep -q 'caller may not override launcher configuration: --model' <<<"$override_output" \
  || fail 'Herdr worker did not explain the rejected override'

cat >"$TMPDIR_TEST/bin/herdr" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  'agent list') printf '{"result":{"agents":[]}}\n' ;;
  'pane split') printf '{"result":{"pane":{"pane_id":"pane-test"}}}\n' ;;
  'pane run') printf 'pane run\t%s\t%s\n' "$3" "$4" >>"$HERDR_FAKE_LOG" ;;
  'agent get') printf '{"result":{"agent":{"agent_status":"idle","state_change_seq":3}}}\n' ;;
  'agent rename') : ;;
  *) printf 'unexpected herdr call: %s\n' "$*" >&2; exit 64 ;;
esac
EOF
chmod +x "$TMPDIR_TEST/bin/herdr"

run_starter() {
  PATH="$TMPDIR_TEST/bin:$PATH" HERDR_ENV=1 HERDR_FAKE_LOG="$TMPDIR_TEST/herdr.log" "$STARTER" "$@"
}

report="$TMPDIR_TEST/report.md"
handoff="$TMPDIR_TEST/handoff.md"
printf '# handoff\n' >"$handoff"
: >"$TMPDIR_TEST/herdr.log"
handoff_payload="$(run_starter --name handoff-worker --mode editable --handoff "$handoff" --report "$report" --cwd "$TMPDIR_TEST" --timeout-seconds 1)"
jq -e --arg handoff "$handoff" --arg report "$report" \
  '.ok == true and .handoff == $handoff and .report == $report and has("brief") | not' <<<"$handoff_payload" >/dev/null \
  || fail '--handoff launch did not preserve its structured JSON contract'

brief='Implement: retain spaces, quotes "and" shell metacharacters $HOME.'
: >"$TMPDIR_TEST/herdr.log"
brief_payload="$(run_starter --name brief-worker --mode editable --brief "$brief" --report "$report" --cwd "$TMPDIR_TEST" --timeout-seconds 1)"
jq -e --arg brief "$brief" --arg report "$report" \
  '.ok == true and .brief == $brief and .report == $report and has("handoff") | not' <<<"$brief_payload" >/dev/null \
  || fail '--brief launch did not preserve its structured JSON contract'
printf -v expected_command '%q ' "$SCRIPT_DIR/herdr-worker.sh" --mode editable -- "$brief" "Complete the brief exactly and write the required report to $report."
expected_command="${expected_command% }"
grep -Fqx $'pane run\tpane-test\t'"$expected_command" "$TMPDIR_TEST/herdr.log" \
  || fail '--brief launch did not safely preserve wrapper arguments'

if missing_source_output="$(run_starter --name missing-source --mode editable --report "$report" --cwd "$TMPDIR_TEST" 2>&1)"; then
  fail 'starter accepted a launch without --handoff or --brief'
fi
jq -e '.ok == false and .error == "one of --handoff or --brief is required"' <<<"$missing_source_output" >/dev/null \
  || fail 'starter did not return a clean missing-source error'

if conflicting_source_output="$(run_starter --name conflicting-source --mode editable --handoff "$handoff" --brief 'also supplied' --report "$report" --cwd "$TMPDIR_TEST" 2>&1)"; then
  fail 'starter accepted both --handoff and --brief'
fi
jq -e '.ok == false and .error == "--handoff and --brief are mutually exclusive"' <<<"$conflicting_source_output" >/dev/null \
  || fail 'starter did not return a clean conflicting-source error'

printf 'PASS: self-contained Herdr worker and subagent launcher contracts\n'
