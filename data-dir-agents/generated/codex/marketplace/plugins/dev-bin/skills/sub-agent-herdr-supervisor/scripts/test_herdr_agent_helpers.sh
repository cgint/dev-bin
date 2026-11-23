#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWAIT="$SCRIPT_DIR/herdr_await_agent.sh"
PROMPT="$SCRIPT_DIR/herdr_prompt_agent.sh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -r "$TMPDIR_TEST"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$TMPDIR_TEST/bin"
cat >"$TMPDIR_TEST/bin/herdr" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$HERDR_FAKE_LOG"

case "$1 $2" in
  'agent wait')
    printf '{"result":{"matched":"done"}}\n'
    if [[ "${HERDR_WAIT_EXIT:-0}" != 0 ]]; then
      printf 'wait timeout\n' >&2
      exit "$HERDR_WAIT_EXIT"
    fi
    ;;
  'agent prompt')
    printf '{"result":{"accepted":true}}\n'
    if [[ "${HERDR_PROMPT_EXIT:-0}" != 0 ]]; then
      printf 'prompt rejected\n' >&2
      exit "$HERDR_PROMPT_EXIT"
    fi
    ;;
  'agent get')
    printf '{"result":{"agent":{"agent_status":"%s","state_change_seq":17}}}\n' "${HERDR_AGENT_STATUS:-done}"
    ;;
  'agent read')
    printf 'WORK REPORT\nHEADLINE: quoted "evidence"\n'
    ;;
  *)
    printf 'unexpected herdr call: %s\n' "$*" >&2
    exit 64
    ;;
esac
EOF
chmod +x "$TMPDIR_TEST/bin/herdr"

run_helper() {
  PATH="$TMPDIR_TEST/bin:$PATH" HERDR_ENV=1 HERDR_FAKE_LOG="$TMPDIR_TEST/calls.log" "$@"
}

: >"$TMPDIR_TEST/calls.log"
payload="$(run_helper "$AWAIT" worker-a --timeout-ms 10 --lines 4)"
jq -e '
  .ok == true and
  .operation == "await" and
  .target == "worker-a" and
  .wait.exit_code == 0 and
  .agent.status == "done" and
  (.terminal.text | contains("quoted \"evidence\""))
' <<<"$payload" >/dev/null || fail 'await did not return lifecycle and terminal evidence'
grep -qx 'agent wait worker-a --timeout 10' "$TMPDIR_TEST/calls.log" || fail 'await did not wait'
grep -qx 'agent get worker-a' "$TMPDIR_TEST/calls.log" || fail 'await did not get current state'

: >"$TMPDIR_TEST/calls.log"
payload="$(HERDR_WAIT_EXIT=1 run_helper "$AWAIT" worker-a --timeout-ms 10 --lines 4)"
jq -e '.ok == true and .wait.exit_code == 1 and .agent.status == "done" and (.terminal.text | contains("WORK REPORT"))' <<<"$payload" >/dev/null || fail 'await did not preserve evidence after a failed wait'

: >"$TMPDIR_TEST/calls.log"
payload="$(HERDR_AGENT_STATUS=working run_helper "$PROMPT" worker-a 'Benjamin → Judith: inspect the failure.')"
jq -e '.ok == true and .operation == "prompt" and .prompt.sent == false and .prompt.reason == "agent_working" and .agent.status == "working"' <<<"$payload" >/dev/null || fail 'prompt did not refuse a busy worker'
if grep -q '^agent prompt ' "$TMPDIR_TEST/calls.log"; then
  fail 'prompt sent a prompt to a working worker'
fi

: >"$TMPDIR_TEST/calls.log"
payload="$(HERDR_AGENT_STATUS=blocked run_helper "$PROMPT" worker-a 'Benjamin → Judith: inspect the failure.')"
jq -e '.ok == true and .prompt.sent == false and .prompt.reason == "agent_blocked" and .agent.status == "blocked"' <<<"$payload" >/dev/null || fail 'prompt did not refuse a blocked worker'
if grep -q '^agent prompt ' "$TMPDIR_TEST/calls.log"; then
  fail 'prompt sent a prompt to a blocked worker'
fi

: >"$TMPDIR_TEST/calls.log"
payload="$(HERDR_AGENT_STATUS=idle run_helper "$PROMPT" w1Z:pA 'Benjamin → Judith: inspect the failure.')"
jq -e '.ok == true and .operation == "prompt" and .target == "w1Z:pA" and .prompt.sent == true and .prompt.exit_code == 0 and .agent.status == "idle" and (.terminal.text | contains("WORK REPORT"))' <<<"$payload" >/dev/null || fail 'prompt did not dispatch and collect pane-target evidence'
grep -qx 'agent prompt w1Z:pA Benjamin → Judith: inspect the failure. --wait --timeout 1800000' "$TMPDIR_TEST/calls.log" || fail 'prompt used the wrong pane-target prompt/wait invocation'

if error_output="$(run_helper "$PROMPT" worker-a '' 2>&1)"; then
  fail 'prompt accepted an empty prompt'
fi
jq -e '.ok == false and .error == "message must be non-empty"' <<<"$error_output" >/dev/null || fail 'empty prompt did not produce structured error JSON'

if ! env -u HERDR_ENV "$AWAIT" --help >/dev/null; then
  fail 'await help requires a Herdr-managed pane'
fi

if missing_env_output="$(env -u HERDR_ENV PATH="$TMPDIR_TEST/bin:$PATH" HERDR_FAKE_LOG="$TMPDIR_TEST/calls.log" "$AWAIT" worker-a 2>&1)"; then
  fail 'await accepted execution outside a Herdr-managed pane'
fi
jq -e '.ok == false and .error == "must run inside a Herdr-managed pane (HERDR_ENV=1)"' <<<"$missing_env_output" >/dev/null || fail 'missing HERDR_ENV did not produce structured error JSON'

printf 'PASS: Herdr agent helper contract\n'
