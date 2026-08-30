#!/usr/bin/env bash
# Wait for a worker and return its lifecycle snapshot plus bounded terminal evidence.
set -uo pipefail

readonly DEFAULT_TIMEOUT_MS=1800000
readonly DEFAULT_LINES=100
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=herdr_subagent_observation_lib.sh
source "$SCRIPT_DIR/herdr_subagent_observation_lib.sh"

usage() {
  cat <<'EOF'
Usage: herdr_await_subagent.sh <target> [--timeout-ms <milliseconds>] [--lines <count>]

Waits for Herdr's normal terminal lifecycle set, then returns one JSON document
with the wait result, current agent status, and bounded recent terminal output.
A lifecycle result is evidence for inspection, never automatic task acceptance.
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

[[ $# -ge 1 ]] || { usage >&2; herdr_helper_error 'target is required'; exit 2; }
HERDR_HELPER_TARGET="$1"
shift
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

herdr_helper_capture herdr agent wait "$HERDR_HELPER_TARGET" --timeout "$timeout_ms"
wait_payload="$(herdr_helper_capture_json)"
herdr_helper_collect_agent
herdr_helper_collect_terminal
herdr_helper_emit await "$wait_payload" 'null'
