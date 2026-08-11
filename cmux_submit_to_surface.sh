#!/usr/bin/env bash
# Submit one steering message to a CMUX terminal surface.
#
# Usage: cmux_submit_to_surface.sh <surface-id> <message>
#
# This keeps Pi-agent steering to one physical line: the message is typed and
# Enter is sent separately. Physical newlines and CMUX's \n/\r escapes are
# rejected because either could create multiple Pi TUI submissions or corrupt a
# path. The target is then read back for immediate delivery feedback.

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: cmux_submit_to_surface.sh <surface-id> <message>

Types one message into the CMUX surface, submits it with Enter, waits two
seconds, then prints the target's last 22 screen lines.
Physical newlines and CMUX \n/\r escapes are rejected.
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

[[ $# -eq 2 ]] || {
  usage
  die "expected <surface-id> and one quoted <message>"
}

surface="$1"
message="$2"

[[ -n "$surface" ]] || die "surface-id must not be empty"
[[ -n "$message" ]] || die "message must not be empty"

newline_error() {
  local before after
  if [[ "$message" == *$'\n'* ]]; then
    before="${message%%$'\n'*}"
    after="${message#*$'\n'}"
  else
    before="${message%%$'\r'*}"
    after="${message#*$'\r'}"
  fi
  (( ${#before} > 20 )) && before="${before:${#before}-20}"
  after="${after:0:20}"
  die "message contains a physical line break near: ${before}[newline]${after}; join it explicitly"
}

[[ "$message" != *$'\n'* && "$message" != *$'\r'* ]] || newline_error

case "$message" in
  *'\n'*|*'\r'*)
    die "message must not contain CMUX \\n/\\r escapes"
    ;;
esac

cmux send --surface "$surface" -- "$message"
cmux send-key --surface "$surface" Enter
sleep 2
if ! cmux read-screen --surface "$surface" --lines 22; then
  echo "SUBMITTED; READ-BACK FAILED for $surface" >&2
  exit 3
fi
