#!/usr/bin/env bash
# Start a Pi subagent through a hardened wrapper in a new Herdr sibling pane.
# Herdr remains the sole control plane after launch: inspect/read/prompt/wait
# through Herdr using the returned pane ID or agent name.
set -euo pipefail

readonly DEFAULT_TIMEOUT_SECONDS=5
readonly POLL_INTERVAL_SECONDS=0.5
readonly READONLY_WRAPPER="$HOME/.local/bin/subagent-readonly.sh"
readonly EDITABLE_WRAPPER="$HOME/.local/bin/subagent.sh"

usage() {
  cat <<'EOF'
Usage:
  herdr_start_subagent.sh \
    --name <agent-name> \
    --mode <readonly|editable> \
    --handoff <absolute-handoff-path> \
    --report <absolute-report-path> \
    [--instruction <one-line-instruction>] \
    [--direction <right|down>] \
    [--cwd <absolute-directory>] \
    [--timeout-seconds <1-30>]

Creates a non-focused sibling Herdr pane, starts the selected subagent wrapper with
@<handoff> plus the initial instruction, and polls for Herdr agent detection.

On successful pane launch, prints one JSON object to stdout containing the pane ID.
If Pi is detected before the bounded timeout, the JSON also contains its Herdr name,
status, and state_change_seq. If registration is still pending, it reports
"agent_detected": false and "agent_status": "initializing"; use Herdr to continue
observing that pane. Errors are JSON on stderr and exit non-zero.

The handoff itself must state the complete report path and all worker boundaries.
EOF
}

fail() {
  local code="$1"
  local message="$2"
  jq -cn --arg error "$message" --argjson exit_code "$code" \
    '{ok: false, error: $error, exit_code: $exit_code}' >&2
  exit "$code"
}

require_absolute_file() {
  local flag="$1"
  local path="$2"
  [[ "$path" == /* ]] || fail 2 "$flag must be an absolute path"
  [[ -f "$path" && -r "$path" ]] || fail 2 "$flag must name a readable file: $path"
}

require_absolute_report_path() {
  local path="$1"
  local parent
  [[ "$path" == /* ]] || fail 2 "--report must be an absolute path"
  parent="$(dirname "$path")"
  [[ -d "$parent" && -w "$parent" ]] || fail 2 "--report parent must be a writable directory: $parent"
}

name=""
mode=""
handoff=""
report=""
instruction=""
direction="right"
cwd="$PWD"
timeout_seconds="$DEFAULT_TIMEOUT_SECONDS"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      [[ $# -ge 2 ]] || fail 2 "--name requires a value"
      name="$2"
      shift 2
      ;;
    --mode)
      [[ $# -ge 2 ]] || fail 2 "--mode requires a value"
      mode="$2"
      shift 2
      ;;
    --handoff)
      [[ $# -ge 2 ]] || fail 2 "--handoff requires a value"
      handoff="$2"
      shift 2
      ;;
    --report)
      [[ $# -ge 2 ]] || fail 2 "--report requires a value"
      report="$2"
      shift 2
      ;;
    --instruction)
      [[ $# -ge 2 ]] || fail 2 "--instruction requires a value"
      instruction="$2"
      shift 2
      ;;
    --direction)
      [[ $# -ge 2 ]] || fail 2 "--direction requires a value"
      direction="$2"
      shift 2
      ;;
    --cwd)
      [[ $# -ge 2 ]] || fail 2 "--cwd requires a value"
      cwd="$2"
      shift 2
      ;;
    --timeout-seconds)
      [[ $# -ge 2 ]] || fail 2 "--timeout-seconds requires a value"
      timeout_seconds="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail 2 "unknown argument: $1"
      ;;
  esac
done

[[ "${HERDR_ENV:-}" == "1" ]] || fail 2 "must run inside a Herdr-managed pane (HERDR_ENV=1)"
[[ "$name" =~ ^[a-z][a-z0-9_-]{0,31}$ ]] || fail 2 "--name must match [a-z][a-z0-9_-]{0,31}"
[[ "$mode" == "readonly" || "$mode" == "editable" ]] || fail 2 "--mode must be readonly or editable"
[[ "$direction" == "right" || "$direction" == "down" ]] || fail 2 "--direction must be right or down"
[[ "$timeout_seconds" =~ ^[0-9]+$ ]] && (( timeout_seconds >= 1 && timeout_seconds <= 30 )) \
  || fail 2 "--timeout-seconds must be an integer from 1 to 30"
[[ "$cwd" == /* && -d "$cwd" ]] || fail 2 "--cwd must be an existing absolute directory"
require_absolute_file "--handoff" "$handoff"
require_absolute_report_path "$report"
[[ -z "$instruction" || "$instruction" != *$'\n'* && "$instruction" != *$'\r'* ]] \
  || fail 2 "--instruction must be one physical line"

if [[ -z "$instruction" ]]; then
  instruction="Read @$handoff. Complete the handoff exactly and write the required report to $report."
fi

case "$mode" in
  readonly) wrapper="$READONLY_WRAPPER" ;;
  editable) wrapper="$EDITABLE_WRAPPER" ;;
esac
[[ -x "$wrapper" ]] || fail 2 "selected wrapper is not executable: $wrapper"

command -v herdr >/dev/null 2>&1 || fail 2 "herdr is not on PATH"
command -v jq >/dev/null 2>&1 || fail 2 "jq is not on PATH"

if herdr agent list | jq -e --arg name "$name" '.result.agents[]? | select(.name == $name)' >/dev/null; then
  fail 2 "an existing live Herdr agent already uses --name: $name"
fi

split_json="$(herdr pane split --current --direction "$direction" --cwd "$cwd" --no-focus)" \
  || fail 1 "Herdr failed to create a sibling pane"
pane_id="$(jq -er '.result.pane.pane_id' <<<"$split_json")" \
  || fail 1 "Herdr pane creation returned no pane ID"

# printf %q produces a single shell command whose arguments preserve paths and
# instruction text. pane run then submits that command atomically with Enter.
printf -v launch_command '%q ' "$wrapper" "@$handoff" "$instruction"
launch_command="${launch_command% }"
herdr pane run "$pane_id" "$launch_command" >/dev/null \
  || fail 1 "Herdr created pane $pane_id but failed to submit the wrapper command; inspect that pane"

agent_detected=false
agent_status="initializing"
state_change_seq=null
agent_json=""
attempts=$(( timeout_seconds * 2 ))

for (( attempt = 1; attempt <= attempts; attempt++ )); do
  if candidate_json="$(herdr agent get "$pane_id" 2>/dev/null)"; then
    candidate_status="$(jq -r '.result.agent.agent_status // "unknown"' <<<"$candidate_json")"
    if [[ "$candidate_status" != "unknown" ]]; then
      if herdr agent rename "$pane_id" "$name" >/dev/null; then
        agent_json="$(herdr agent get "$name")" || fail 1 "Herdr detected pane $pane_id but could not read renamed agent $name"
        agent_status="$(jq -r '.result.agent.agent_status' <<<"$agent_json")"
        state_change_seq="$(jq -r '.result.agent.state_change_seq' <<<"$agent_json")"
        agent_detected=true
        break
      fi
      fail 1 "Herdr detected an agent in pane $pane_id but could not rename it to $name"
    fi
  fi
  sleep "$POLL_INTERVAL_SECONDS"
done

jq -cn \
  --arg name "$name" \
  --arg mode "$mode" \
  --arg pane_id "$pane_id" \
  --arg handoff "$handoff" \
  --arg report "$report" \
  --arg agent_status "$agent_status" \
  --argjson agent_detected "$agent_detected" \
  --argjson state_change_seq "$state_change_seq" \
  --argjson timeout_seconds "$timeout_seconds" \
  '{ok: true, name: $name, mode: $mode, pane_id: $pane_id, handoff: $handoff, report: $report, agent_detected: $agent_detected, agent_status: $agent_status, state_change_seq: $state_change_seq, detection_timeout_seconds: $timeout_seconds}'
