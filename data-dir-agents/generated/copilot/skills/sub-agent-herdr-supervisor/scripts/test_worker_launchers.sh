#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME="$SCRIPT_DIR/pi-worker-runtime.sh"
SHARED_RUNTIME="$SCRIPT_DIR/../../../runtime/pi-worker-runtime.sh"
[[ -f "$SHARED_RUNTIME" ]] && RUNTIME="$SHARED_RUNTIME"
HERDR_ADAPTER="$SCRIPT_DIR/herdr-worker.sh"
STARTER="$SCRIPT_DIR/herdr-start-subagent.sh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -r "$TMPDIR_TEST"' EXIT
# Ensure the outer shell's PI_WORKER_DEFAULT_MODEL does not leak into tests
# that do not explicitly set it.
unset PI_WORKER_DEFAULT_MODEL

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

mkdir -p "$TMPDIR_TEST/bin" "$TMPDIR_TEST/direct-bin" \
  "$TMPDIR_TEST/home/.pi/profiles/minimal/agent/extensions" \
  "$TMPDIR_TEST/home/.pi/profiles/partner/agent/extensions" \
  "$TMPDIR_TEST/direct-home/.pi/agent/extensions"
: >"$TMPDIR_TEST/home/.pi/profiles/minimal/agent/extensions/herdr-agent-state.ts"
: >"$TMPDIR_TEST/home/.pi/profiles/partner/agent/extensions/herdr-agent-state.ts"
: >"$TMPDIR_TEST/direct-home/.pi/agent/extensions/herdr-agent-state.ts"
cat >"$TMPDIR_TEST/bin/pi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ -n "${PI_INVOCATION_CAPTURE:-}" ]; then
  {
    printf '%s' "$(basename "$0")"
    printf '\t%s' "$@"
    printf '\n'
  } >>"$PI_INVOCATION_CAPTURE"
fi
# Emulate Pi model discovery so the launcher cannot pass availability by
# accident: under -ne a provider whose models come from an extension is visible
# only when that extension is loaded explicitly with -e.
probe_args=("$@")
list_query=''
list_models=false
discovery=true
explicit_extensions=()
probe_index=0
while [ "$probe_index" -lt "${#probe_args[@]}" ]; do
  probe_argument="${probe_args[$probe_index]}"
  case "$probe_argument" in
    --list-models)
      list_models=true
      probe_next="${probe_args[$((probe_index + 1))]:-}"
      case "$probe_next" in ''|-*) ;; *) list_query="$probe_next" ;; esac
      ;;
    -ne|--no-extensions) discovery=false ;;
    -e|--extension)
      probe_index=$((probe_index + 1))
      explicit_extensions+=("${probe_args[$probe_index]:-}")
      ;;
    --extension=*) explicit_extensions+=("${probe_argument#--extension=}") ;;
    -e?*) explicit_extensions+=("${probe_argument#-e}") ;;
  esac
  probe_index=$((probe_index + 1))
done

if [ "$list_models" = true ]; then
  if [ -n "${PI_PROFILE_LIST_CAPTURE:-}" ]; then
    printf '%s\n' "$@" >"$PI_PROFILE_LIST_CAPTURE"
  fi
  if [ "$discovery" = false ]; then
    case "${list_query%%/*}" in
      home-llm)
        extension_seen=false
        for loaded_extension in ${explicit_extensions[@]+"${explicit_extensions[@]}"}; do
          case "$loaded_extension" in
            *pi-olla-autodetect*) extension_seen=true ;;
          esac
        done
        [ "$extension_seen" = true ] || exit 0
        ;;
    esac
  fi
  if [[ "${MODEL_AVAILABLE:-}" == "$list_query" ]]; then
    printf 'provider  model\n%s\n' "${MODEL_AVAILABLE//\//  }"
  fi
  exit 0
fi
for ((auth_index = 1; auth_index <= $# - 3; auth_index++)); do
  check_index=$((auth_index + 1))
  provider_flag_index=$((auth_index + 2))
  provider_index=$((auth_index + 3))
  if [[ "${!auth_index}" == auth ]] &&
    [[ "${!check_index}" == check ]] &&
    [[ "${!provider_flag_index}" == --provider ]]; then
    case "${!provider_index}" in
      openai-codex) [ "${AUTH_OPENAI:-ready}" = ready ] && printf 'ready\n' ;;
      github-copilot) [ "${AUTH_COPILOT:-unready}" = ready ] && printf 'ready\n' ;;
    esac
    exit 0
  fi
done
printf 'PI_WRITE_GUARD_DIRS=%s\n' "${PI_WRITE_GUARD_DIRS:-}" >"$PI_PROFILE_CAPTURE"
printf '%s\n' "$@" >>"$PI_PROFILE_CAPTURE"
EOF
chmod +x "$TMPDIR_TEST/bin/pi"
ln -s pi "$TMPDIR_TEST/bin/pi-profile"
ln -s ../bin/pi "$TMPDIR_TEST/direct-bin/pi"

# Install a git shim before any worker invocation so the runtime's
# `git rev-parse --show-toplevel` never resolves a real repository root
# (and its real .sub_agent_conf) during tests.
cat >"$TMPDIR_TEST/bin/git" <<'EOF'
#!/usr/bin/env bash
if [[ "$1 $2" == 'rev-parse --show-toplevel' && -n "${FAKE_GIT_ROOT:-}" ]]; then
  printf '%s\n' "$FAKE_GIT_ROOT"
  exit 0
fi
exit 1
EOF
chmod +x "$TMPDIR_TEST/bin/git"
ln -s ../bin/git "$TMPDIR_TEST/direct-bin/git"

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
    MODEL_AVAILABLE="${MODEL_AVAILABLE:-}" FAKE_GIT_ROOT="${FAKE_GIT_ROOT:-}" \
    PI_WORKER_DEFAULT_MODEL="${PI_WORKER_DEFAULT_MODEL:-}" \
    "$herdr_worker" --mode readonly -- @/tmp/handoff.md 'Execute the bounded task.'
}

run_direct_worker() {
  local capture="$1"
  PATH="$TMPDIR_TEST/direct-bin:/usr/bin:/bin" HOME="$TMPDIR_TEST/direct-home" PI_PROFILE_CAPTURE="$capture" \
    PI_INVOCATION_CAPTURE="${PI_INVOCATION_CAPTURE:-}" \
    AUTH_OPENAI="${AUTH_OPENAI:-ready}" AUTH_COPILOT="${AUTH_COPILOT:-unready}" \
    MODEL_AVAILABLE="${MODEL_AVAILABLE:-}" FAKE_GIT_ROOT="${FAKE_GIT_ROOT:-}" \
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

direct_capture="$TMPDIR_TEST/direct.txt"
direct_invocations="$TMPDIR_TEST/direct-invocations.txt"
PI_INVOCATION_CAPTURE="$direct_invocations" run_direct_worker "$direct_capture"
assert_capture "$direct_capture" \
  'PI_WRITE_GUARD_DIRS=.' \
  -ne -e 'https://github.com/cgint/pi-focus-guard' \
  -e "$TMPDIR_TEST/direct-home/.pi/agent/extensions/herdr-agent-state.ts" \
  --model openai-codex/gpt-5.6-terra --thinking minimal \
  --tools read,bash,grep,find,ls --dm-read \
  @/tmp/handoff.md 'Execute the bounded task.'
grep -Fqx $'pi\tauth\tcheck\t--provider\topenai-codex' "$direct_invocations" \
  || fail 'direct-Pi worker did not use plain pi for authentication'
if grep -Fq $'pi\tdefault\t' "$direct_invocations"; then
  fail 'direct-Pi worker passed a profile name to plain pi'
fi

if direct_profile_output="$(PI_WORKER_PROFILE=partner run_direct_worker "$TMPDIR_TEST/direct-invalid.txt" 2>&1)"; then
  fail 'direct-Pi worker accepted a non-default PI_WORKER_PROFILE'
fi
grep -q 'pi-profile is unavailable; cannot select non-default profile: partner' <<<"$direct_profile_output" \
  || fail 'direct-Pi worker did not explain the rejected profile'

if invalid_profile_output="$(PI_WORKER_PROFILE='../unsafe' run_worker "$TMPDIR_TEST/invalid.txt" 2>&1)"; then
  fail 'Herdr worker accepted an invalid PI_WORKER_PROFILE'
fi
grep -q 'invalid PI_WORKER_PROFILE: ../unsafe' <<<"$invalid_profile_output" \
  || fail 'Herdr worker did not explain the rejected PI_WORKER_PROFILE'

config_root="$TMPDIR_TEST/repository"
mkdir -p "$config_root/nested"
cat >"$config_root/.sub_agent_conf" <<'EOF'
# Repository policy: use the local model.
PROVIDER=home-llm
MODEL=qwen38-flashnext-twins-direct
THINKING=medium
EOF
config_capture="$TMPDIR_TEST/config.txt"
config_list_capture="$TMPDIR_TEST/config-list.txt"
(
  cd "$config_root/nested"
  PI_PROFILE_LIST_CAPTURE="$config_list_capture" FAKE_GIT_ROOT="$config_root" \
    MODEL_AVAILABLE='home-llm/qwen38-flashnext-twins-direct' run_worker "$config_capture"
)
grep -Fqx 'https://github.com/cgint/pi-olla-autodetect' "$config_capture" \
  || fail 'Herdr worker did not load the extension that registers the configured provider'
grep -qx -- '-ne' "$config_list_capture" \
  || fail 'availability probe did not use the worker discovery mode'
grep -Fqx 'https://github.com/cgint/pi-olla-autodetect' "$config_list_capture" \
  || fail 'availability probe did not load the provider extension used by the worker'

direct_config_capture="$TMPDIR_TEST/direct-config.txt"
direct_config_list_capture="$TMPDIR_TEST/direct-config-list.txt"
direct_config_invocations="$TMPDIR_TEST/direct-config-invocations.txt"
(
  cd "$config_root/nested"
  PI_INVOCATION_CAPTURE="$direct_config_invocations" PI_PROFILE_LIST_CAPTURE="$direct_config_list_capture" \
    FAKE_GIT_ROOT="$config_root" MODEL_AVAILABLE='home-llm/qwen38-flashnext-twins-direct' \
    run_direct_worker "$direct_config_capture"
)
grep -qx -- '-ne' "$direct_config_list_capture" \
  || fail 'direct-Pi availability probe did not use the worker discovery mode'
grep -Fqx 'https://github.com/cgint/pi-olla-autodetect' "$direct_config_list_capture" \
  || fail 'direct-Pi availability probe did not load the provider extension'
grep -Fq $'pi\t-ne\t-e\thttps://github.com/cgint/pi-focus-guard' "$direct_config_invocations" \
  || fail 'direct-Pi availability probe did not use plain pi'
if grep -Fq $'pi\tdefault\t' "$direct_config_invocations"; then
  fail 'direct-Pi availability probe passed a profile name to plain pi'
fi

grep -qx -- '--provider' "$config_capture" || fail 'Herdr worker did not pass configured provider'
grep -qx 'home-llm' "$config_capture" || fail 'Herdr worker did not pass configured provider value'
grep -qx -- '--model' "$config_capture" || fail 'Herdr worker did not pass configured model'
grep -qx 'qwen38-flashnext-twins-direct' "$config_capture" || fail 'Herdr worker did not pass configured model value'
grep -qx -- '--thinking' "$config_capture" || fail 'Herdr worker did not pass configured thinking flag'
grep -qx 'medium' "$config_capture" || fail 'Herdr worker did not pass configured thinking value'

cat >"$config_root/.sub_agent_conf" <<'EOF'
PROVIDER=home-llm
MODEL=qwen38-flashnext-twins-direct
EOF
omitted_thinking_capture="$TMPDIR_TEST/omitted-thinking.txt"
(
  cd "$config_root"
  FAKE_GIT_ROOT="$config_root" MODEL_AVAILABLE='home-llm/qwen38-flashnext-twins-direct' run_worker "$omitted_thinking_capture"
)
if grep -qx -- '--thinking' "$omitted_thinking_capture"; then
  fail 'Herdr worker forced a thinking level when configured THINKING was omitted'
fi

cat >"$config_root/.sub_agent_conf" <<'EOF'
PROVIDER=home-llm
MODEL=qwen38-flashnext-twins-direct
THINKING=unsupported
EOF
if invalid_thinking_output="$(cd "$config_root" && FAKE_GIT_ROOT="$config_root" run_worker "$TMPDIR_TEST/invalid-thinking.txt" 2>&1)"; then
  fail 'Herdr worker accepted invalid .sub_agent_conf THINKING'
fi
grep -q 'invalid .sub_agent_conf THINKING line: THINKING=unsupported' <<<"$invalid_thinking_output" \
  || fail 'Herdr worker did not explain invalid .sub_agent_conf THINKING'

printf 'PROVIDER=home-llm\n' >"$config_root/.sub_agent_conf"
if malformed_output="$(cd "$config_root" && FAKE_GIT_ROOT="$config_root" run_worker "$TMPDIR_TEST/malformed.txt" 2>&1)"; then
  fail 'Herdr worker accepted incomplete .sub_agent_conf'
fi
grep -q '.sub_agent_conf requires both PROVIDER and MODEL' <<<"$malformed_output" \
  || fail 'Herdr worker did not explain incomplete .sub_agent_conf'

# A provider whose models are statically known must launch without any mapped
# extension, so the trusted map cannot become a hard dependency or a gate.
cat >"$config_root/.sub_agent_conf" <<'EOF'
PROVIDER=static-llm
MODEL=known-model
EOF
static_capture="$TMPDIR_TEST/static.txt"
FAKE_GIT_ROOT="$config_root" MODEL_AVAILABLE='static-llm/known-model' run_worker "$static_capture"
grep -qx 'static-llm' "$static_capture" || fail 'Herdr worker rejected a provider without a mapped extension'
grep -Fq 'pi-olla-autodetect' "$static_capture" \
  && fail 'Herdr worker loaded an unrelated provider extension'

# Repository configuration selects a provider; it must never add extensions.
cat >"$config_root/.sub_agent_conf" <<'EOF'
PROVIDER=home-llm
MODEL=qwen38-flashnext-twins-direct
EXTENSIONS=https://example.invalid/untrusted
EOF
if injected_output="$(cd "$config_root" && FAKE_GIT_ROOT="$config_root" run_worker "$TMPDIR_TEST/injected.txt" 2>&1)"; then
  fail '.sub_agent_conf was allowed to introduce an extension'
fi
grep -q 'invalid .sub_agent_conf line: EXTENSIONS=https://example.invalid/untrusted' <<<"$injected_output" \
  || fail '.sub_agent_conf did not reject an extension key'
grep -Fq 'example.invalid/untrusted' "$TMPDIR_TEST/injected.txt" 2>/dev/null \
  && fail 'untrusted extension reached the worker invocation'

cat >"$config_root/.sub_agent_conf" <<'EOF'
PROVIDER=home-llm
MODEL=unknown-model
EOF
if unavailable_output="$(cd "$config_root" && FAKE_GIT_ROOT="$config_root" run_worker "$TMPDIR_TEST/unavailable.txt" 2>&1)"; then
  fail 'Herdr worker accepted unavailable .sub_agent_conf model'
fi
grep -q '.sub_agent_conf model is unavailable: home-llm/unknown-model' <<<"$unavailable_output" \
  || fail 'Herdr worker did not explain unavailable .sub_agent_conf model'

printf '# no selection\n\n' >"$config_root/.sub_agent_conf"
if comment_only_output="$(cd "$config_root" && FAKE_GIT_ROOT="$config_root" run_worker "$TMPDIR_TEST/comment-only.txt" 2>&1)"; then
  fail 'Herdr worker accepted comment-only .sub_agent_conf'
fi
grep -q '.sub_agent_conf requires both PROVIDER and MODEL' <<<"$comment_only_output" \
  || fail 'Herdr worker did not explain comment-only .sub_agent_conf'

cat >"$config_root/.sub_agent_conf" <<'EOF'
PROVIDER=home-llm
PROVIDER=other-llm
MODEL=qwen38-flashnext-twins-direct
EOF
if duplicate_output="$(cd "$config_root" && FAKE_GIT_ROOT="$config_root" run_worker "$TMPDIR_TEST/duplicate.txt" 2>&1)"; then
  fail 'Herdr worker accepted duplicate .sub_agent_conf key'
fi
grep -q 'invalid .sub_agent_conf PROVIDER line: PROVIDER=other-llm' <<<"$duplicate_output" \
  || fail 'Herdr worker did not explain duplicate .sub_agent_conf key'

non_git_capture="$TMPDIR_TEST/non-git.txt"
FAKE_GIT_ROOT='' run_worker "$non_git_capture"
grep -qx 'openai-codex/gpt-5.6-terra' "$non_git_capture" \
  || fail 'Herdr worker did not retain default selection outside Git'

env_model_capture="$TMPDIR_TEST/env-model.txt"
FAKE_GIT_ROOT='' PI_WORKER_DEFAULT_MODEL='home-llm/qwen-model' \
  MODEL_AVAILABLE='home-llm/qwen-model' run_worker "$env_model_capture"
grep -qx -- '--provider' "$env_model_capture" || fail 'Herdr worker did not pass PI_WORKER_DEFAULT_MODEL provider'
grep -qx 'home-llm' "$env_model_capture" || fail 'Herdr worker did not pass PI_WORKER_DEFAULT_MODEL provider value'
grep -qx 'qwen-model' "$env_model_capture" || fail 'Herdr worker did not pass PI_WORKER_DEFAULT_MODEL model value'
grep -Fqx 'https://github.com/cgint/pi-olla-autodetect' "$env_model_capture" \
  || fail 'Herdr worker did not load the trusted extension for the PI_WORKER_DEFAULT_MODEL provider'
if grep -qx -- '--thinking' "$env_model_capture"; then
  fail 'Herdr worker forced a thinking level when PI_WORKER_DEFAULT_MODEL omitted one'
fi

env_thinking_capture="$TMPDIR_TEST/env-thinking.txt"
FAKE_GIT_ROOT='' PI_WORKER_DEFAULT_MODEL='home-llm/qwen-model:off' \
  MODEL_AVAILABLE='home-llm/qwen-model' run_worker "$env_thinking_capture"
grep -qx -- '--thinking' "$env_thinking_capture" \
  || fail 'Herdr worker did not pass the PI_WORKER_DEFAULT_MODEL thinking level'
grep -qx 'off' "$env_thinking_capture" \
  || fail 'Herdr worker did not pass the PI_WORKER_DEFAULT_MODEL thinking value'

if invalid_env_thinking_output="$(FAKE_GIT_ROOT='' PI_WORKER_DEFAULT_MODEL='home-llm/qwen-model:ultra' run_worker "$TMPDIR_TEST/invalid-env-thinking.txt" 2>&1)"; then
  fail 'Herdr worker accepted an invalid thinking level in PI_WORKER_DEFAULT_MODEL'
fi
grep -q 'invalid thinking level in PI_WORKER_DEFAULT_MODEL: ultra' <<<"$invalid_env_thinking_output" \
  || fail 'Herdr worker did not explain invalid PI_WORKER_DEFAULT_MODEL thinking level'

if malformed_env_output="$(FAKE_GIT_ROOT='' PI_WORKER_DEFAULT_MODEL='not-a-model' run_worker "$TMPDIR_TEST/malformed-env.txt" 2>&1)"; then
  fail 'Herdr worker accepted a malformed PI_WORKER_DEFAULT_MODEL'
fi
grep -q 'invalid PI_WORKER_DEFAULT_MODEL: not-a-model' <<<"$malformed_env_output" \
  || fail 'Herdr worker did not explain malformed PI_WORKER_DEFAULT_MODEL'

if missing_provider_env_output="$(FAKE_GIT_ROOT='' PI_WORKER_DEFAULT_MODEL='justamod' run_worker "$TMPDIR_TEST/missing-provider-env.txt" 2>&1)"; then
  fail 'Herdr worker accepted a PI_WORKER_DEFAULT_MODEL without a provider'
fi
grep -q 'invalid PI_WORKER_DEFAULT_MODEL: justamod' <<<"$missing_provider_env_output" \
  || fail 'Herdr worker did not explain PI_WORKER_DEFAULT_MODEL without a provider'

env_unavailable_capture="$TMPDIR_TEST/env-unavailable.txt"
if unavailable_env_output="$(FAKE_GIT_ROOT='' PI_WORKER_DEFAULT_MODEL='home-llm/unknown-model' MODEL_AVAILABLE='' run_worker "$env_unavailable_capture" 2>&1)"; then
  fail 'Herdr worker accepted an unavailable PI_WORKER_DEFAULT_MODEL'
fi
grep -q 'PI_WORKER_DEFAULT_MODEL model is unavailable: home-llm/unknown-model' <<<"$unavailable_env_output" \
  || fail 'Herdr worker did not explain unavailable PI_WORKER_DEFAULT_MODEL'

cat >"$config_root/.sub_agent_conf" <<'EOF'
PROVIDER=home-llm
MODEL=qwen38-flashnext-twins-direct
EOF
env_override_capture="$TMPDIR_TEST/env-override.txt"
env_override_list_capture="$TMPDIR_TEST/env-override-list.txt"
(
  cd "$config_root/nested"
  PI_PROFILE_LIST_CAPTURE="$env_override_list_capture" FAKE_GIT_ROOT="$config_root" \
    PI_WORKER_DEFAULT_MODEL='home-llm/should-not-be-used' \
    MODEL_AVAILABLE='home-llm/qwen38-flashnext-twins-direct' run_worker "$env_override_capture"
)
grep -qx 'qwen38-flashnext-twins-direct' "$env_override_capture" \
  || fail '.sub_agent_conf did not override PI_WORKER_DEFAULT_MODEL'
if grep -qx 'should-not-be-used' "$env_override_capture"; then
  fail 'PI_WORKER_DEFAULT_MODEL leaked past an active .sub_agent_conf'
fi

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
  'pane run')
    # Herdr requires pane-run commands to be valid UTF-8. This deliberately
    # rejects the mixed raw-byte/octal-escape output formerly made by %q.
    printf '%s' "$4" | iconv -f UTF-8 -t UTF-8 >/dev/null \
      || { printf 'argument 4 is not valid UTF-8\n' >&2; exit 65; }
    printf 'pane run\t%s\t%s\n' "$3" "$4" >>"$HERDR_FAKE_LOG"
    ;;
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

brief='Implement: retain spaces, quotes "and", an apostrophe (can'"'"'t), and shell metacharacters $HOME.'
: >"$TMPDIR_TEST/herdr.log"
brief_payload="$(run_starter --name brief-worker --mode editable --brief "$brief" --report "$report" --cwd "$TMPDIR_TEST" --timeout-seconds 1)"
jq -e --arg brief "$brief" --arg report "$report" \
  '.ok == true and .brief == $brief and .report == $report and has("handoff") | not' <<<"$brief_payload" >/dev/null \
  || fail '--brief launch did not preserve its structured JSON contract'
shell_quote_for_test() {
  local value="$1"
  local quoted_apostrophe="'\"'\"'"
  value=${value//\'/$quoted_apostrophe}
  printf "'%s'" "$value"
}
expected_command="$(shell_quote_for_test "$SCRIPT_DIR/herdr-worker.sh") $(shell_quote_for_test --mode) $(shell_quote_for_test editable) $(shell_quote_for_test --) $(shell_quote_for_test "$brief") $(shell_quote_for_test "Complete the brief exactly and write the required report to $report.")"
grep -Fqx $'pane run\tpane-test\t'"$expected_command" "$TMPDIR_TEST/herdr.log" \
  || fail '--brief launch did not safely preserve wrapper arguments'

# Run under C.UTF-8 because Bash printf %q used to produce an invalid command:
# the arrow's leading byte was raw but its continuation bytes were octal escapes.
unicode_instruction='Ash → Mercury: preserve UTF-8 in this instruction.'
: >"$TMPDIR_TEST/herdr.log"
(
  export LC_ALL=C.UTF-8
  run_starter --name unicode-worker --mode editable --brief "$brief" --report "$report" \
    --instruction "$unicode_instruction" --cwd "$TMPDIR_TEST" --timeout-seconds 1
) >/dev/null || fail 'starter did not submit a valid UTF-8 command for a Unicode instruction'
unicode_command="$(cut -f3- "$TMPDIR_TEST/herdr.log")"
printf '%s' "$unicode_command" | iconv -f UTF-8 -t UTF-8 >/dev/null \
  || fail 'starter submitted an invalid UTF-8 command for a Unicode instruction'
grep -Fq "'$unicode_instruction'" <<<"$unicode_command" \
  || fail 'starter did not preserve the Unicode instruction in the shell command'

# A literal apostrophe must use the POSIX '"'"' idiom, without introducing
# backslashes. Parse the complete command with shlex, then compare the final
# argv element byte-for-byte with the original UTF-8 instruction.
apostrophe_unicode_instruction="Mercury → Ash: it's a test"
: >"$TMPDIR_TEST/herdr.log"
(
  export LC_ALL=C.UTF-8
  run_starter --name apostrophe-unicode-worker --mode editable --brief "$brief" --report "$report" \
    --instruction "$apostrophe_unicode_instruction" --cwd "$TMPDIR_TEST" --timeout-seconds 1
) >/dev/null || fail 'starter did not submit a valid command for an apostrophe and Unicode instruction'
apostrophe_unicode_command="$(cut -f3- "$TMPDIR_TEST/herdr.log")"
printf '%s' "$apostrophe_unicode_command" | iconv -f UTF-8 -t UTF-8 >/dev/null \
  || fail 'starter submitted invalid UTF-8 for an apostrophe and Unicode instruction'
printf '%s' "$apostrophe_unicode_command" | grep -Fq '\' \
  && fail 'starter used a backslash in the apostrophe and Unicode command'
parsed_instruction="$(python3 -c 'import shlex, sys; print(shlex.split(sys.argv[1])[-1], end="")' "$apostrophe_unicode_command")" \
  || fail 'shlex could not parse the apostrophe and Unicode command'
[ "$parsed_instruction" = "$apostrophe_unicode_instruction" ] \
  || fail 'shlex did not round-trip the apostrophe and Unicode instruction byte-exactly'

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
