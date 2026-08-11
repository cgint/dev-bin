#!/usr/bin/env bash
# Launch a read-only Pi subagent. pi-focus-guard permits only classified
# read-only Bash commands while --dm-read blocks edit and write tools.
set -euo pipefail

FOCUS_GUARD="$HOME/dev-external/pi-focus-guard/index.ts"

if [ ! -f "$FOCUS_GUARD" ]; then
  printf 'subagent-readonly.sh: pi-focus-guard not found: %s\n' "$FOCUS_GUARD" >&2
  exit 1
fi

exec pi-profile partner -ne \
  -e "$FOCUS_GUARD" \
  --thinking minimal \
  --tools read,bash,grep,find,ls \
  --dm-read \
  "$@"
