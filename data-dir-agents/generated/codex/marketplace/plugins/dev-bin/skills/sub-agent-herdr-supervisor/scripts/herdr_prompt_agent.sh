#!/usr/bin/env bash
# Prompt an idle Herdr agent target and return lifecycle plus terminal evidence.
set -uo pipefail

readonly DEFAULT_TIMEOUT_MS=1800000
readonly DEFAULT_LINES=100
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=herdr_agent_observation_lib.sh
source "$SCRIPT_DIR/herdr_agent_observation_lib.sh"

usage() {
  cat <<'EOF'
Usage: herdr_prompt_agent.sh <target> <message> [--timeout-ms <milliseconds>] [--lines <count>]

Preflights a Herdr agent target (named worker or pane ID). If it is working, sends
nothing and returns evidence with prompt.sent=false. Otherwise sends one message
through `herdr agent prompt --wait`, then returns one JSON document with prompt,
lifecycle, and terminal evidence. A lifecycle result is evidence for inspection,
never automatic task acceptance.
EOF
}

if [[ $# -eq 1 && ( "$1" == '-h' || "$1" == '--help' ) ]]; then
  usage
  exit 0
fi

herdr_helper_require_environment
helper_environment_exit=$?
if [[ "$helper_environment_exit" != 0 ]]; then
  exit "$helper_environment_exit"
fi

[[ $# -ge 2 ]] || { usage >&2; herdr_helper_error 'target and message are required'; exit 2; }
HERDR_HELPER_TARGET="$1"
message="$2"
shift 2
[[ -n "$message" ]] || { herdr_helper_error 'message must be non-empty'; exit 2; }
timeout_ms="$DEFAULT_TIMEOUT_MS"
HERDR_HELPER_LINES="$DEFAULT_LINES"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout-ms)
      [[ $# -ge 2 ]] || { herdr_helper_error '--timeout-ms requires a value'; exit 2; }
      timeout_ms="$2"
      shift 2
      ;;
    --lines)
      [[ $# -ge 2 ]] || { herdr_helper_error '--lines requires a value'; exit 2; }
      HERDR_HELPER_LINES="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      herdr_helper_error "unknown argument: $1"
      exit 2
      ;;
  esac
done

herdr_helper_validate_positive_integer "$timeout_ms" || { herdr_helper_error '--timeout-ms must be a positive integer'; exit 2; }
herdr_helper_validate_positive_integer "$HERDR_HELPER_LINES" || { herdr_helper_error '--lines must be a positive integer'; exit 2; }

herdr_helper_collect_agent
preflight_response="$HERDR_HELPER_AGENT_RESPONSE"
if [[ "$(jq -r '.exit_code' <<<"$preflight_response")" != 0 ]]; then
  herdr_helper_collect_terminal
  herdr_helper_emit prompt 'null' '{"sent": false, "reason": "preflight_unavailable"}'
  exit 0
fi

if [[ "$HERDR_HELPER_AGENT_STATUS" == working || "$HERDR_HELPER_AGENT_STATUS" == blocked ]]; then
  herdr_helper_collect_terminal
  prompt_reason="agent_${HERDR_HELPER_AGENT_STATUS}"
  prompt_payload="$(jq -cn --arg reason "$prompt_reason" '{sent: false, reason: $reason}')"
  herdr_helper_emit prompt 'null' "$prompt_payload"
  exit 0
fi

herdr_helper_capture herdr agent prompt "$HERDR_HELPER_TARGET" "$message" --wait --timeout "$timeout_ms"
prompt_capture="$(herdr_helper_capture_json)"
prompt_payload="$(jq -cn --argjson capture "$prompt_capture" '{sent: true} + $capture')"
herdr_helper_collect_agent
herdr_helper_collect_terminal
herdr_helper_emit prompt "$prompt_capture" "$prompt_payload"
