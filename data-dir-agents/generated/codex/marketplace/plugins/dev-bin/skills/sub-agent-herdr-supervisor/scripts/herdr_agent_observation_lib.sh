#!/usr/bin/env bash
# Shared implementation for Herdr agent observation helpers. Source only.

herdr_helper_error() {
  jq -cn --arg error "$1" '{ok: false, error: $error}'
}

herdr_helper_require_environment() {
  if [[ "${HERDR_ENV:-}" != "1" ]]; then
    herdr_helper_error 'must run inside a Herdr-managed pane (HERDR_ENV=1)'
    return 2
  fi
  command -v herdr >/dev/null 2>&1 || {
    herdr_helper_error 'herdr is not on PATH'
    return 127
  }
  command -v jq >/dev/null 2>&1 || {
    herdr_helper_error 'jq is not on PATH'
    return 127
  }
}

herdr_helper_validate_positive_integer() {
  local value="$1"
  [[ "$value" =~ ^[1-9][0-9]*$ ]]
}

herdr_helper_capture() {
  local stdout_file stderr_file exit_code
  stdout_file="$(mktemp "${TMPDIR:-/tmp}/herdr-subagent-stdout.XXXXXX")" || return 70
  stderr_file="$(mktemp "${TMPDIR:-/tmp}/herdr-subagent-stderr.XXXXXX")" || {
    rm -f "$stdout_file"
    return 70
  }

  if "$@" >"$stdout_file" 2>"$stderr_file"; then
    exit_code=0
  else
    exit_code=$?
  fi

  HERDR_CAPTURE_EXIT="$exit_code"
  HERDR_CAPTURE_STDOUT="$(<"$stdout_file")"
  HERDR_CAPTURE_STDERR="$(<"$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

herdr_helper_capture_json() {
  jq -cn \
    --argjson exit_code "$HERDR_CAPTURE_EXIT" \
    --arg stdout "$HERDR_CAPTURE_STDOUT" \
    --arg stderr "$HERDR_CAPTURE_STDERR" \
    '{exit_code: $exit_code, stdout: $stdout, stderr: $stderr}'
}

herdr_helper_collect_agent() {
  local candidate
  herdr_helper_capture herdr agent get "$HERDR_HELPER_TARGET"
  HERDR_HELPER_AGENT_RESPONSE="$(herdr_helper_capture_json)"
  HERDR_HELPER_AGENT_STATUS='unknown'
  HERDR_HELPER_AGENT_PAYLOAD='null'

  candidate="$HERDR_CAPTURE_STDOUT"
  if [[ "$HERDR_CAPTURE_EXIT" == 0 ]] && jq -e . >/dev/null 2>&1 <<<"$candidate"; then
    HERDR_HELPER_AGENT_PAYLOAD="$candidate"
    HERDR_HELPER_AGENT_STATUS="$(jq -r '.result.agent.agent_status // "unknown"' <<<"$candidate")"
  fi
}

herdr_helper_collect_terminal() {
  herdr_helper_capture herdr agent read "$HERDR_HELPER_TARGET" \
    --source recent-unwrapped --lines "$HERDR_HELPER_LINES" --format text
  HERDR_HELPER_TERMINAL_RESPONSE="$(herdr_helper_capture_json)"
  HERDR_HELPER_TERMINAL_TEXT="$HERDR_CAPTURE_STDOUT"
}

herdr_helper_emit() {
  local operation="$1"
  local wait_payload="$2"
  local prompt_payload="$3"
  local ok=true

  if [[ "$(jq -r '.exit_code' <<<"$HERDR_HELPER_AGENT_RESPONSE")" != 0 ]] || \
     [[ "$(jq -r '.exit_code' <<<"$HERDR_HELPER_TERMINAL_RESPONSE")" != 0 ]]; then
    ok=false
  fi

  jq -cn \
    --argjson ok "$ok" \
    --arg operation "$operation" \
    --arg target "$HERDR_HELPER_TARGET" \
    --arg status "$HERDR_HELPER_AGENT_STATUS" \
    --argjson wait "$wait_payload" \
    --argjson prompt "$prompt_payload" \
    --argjson agent_payload "$HERDR_HELPER_AGENT_PAYLOAD" \
    --argjson agent_response "$HERDR_HELPER_AGENT_RESPONSE" \
    --arg text "$HERDR_HELPER_TERMINAL_TEXT" \
    --argjson terminal_response "$HERDR_HELPER_TERMINAL_RESPONSE" \
    '{
      ok: $ok,
      operation: $operation,
      target: $target,
      agent: {status: $status, payload: $agent_payload, response: $agent_response},
      wait: $wait,
      prompt: $prompt,
      terminal: {text: $text, response: $terminal_response}
    }'
}
