#!/usr/bin/env bash
# Launch a read-only Pi subagent. pi-focus-guard permits only classified
# read-only Bash commands while --dm-read blocks edit and write tools.
set -euo pipefail

for argument in "$@"; do
  [ "$argument" = "--" ] && break
  case "$argument" in
    --print|--print=*|-p|-p?*|--extension|--extension=*|-e|-e?*|--model|--model=*|--provider|--provider=*|--thinking|--thinking=*|--tools|--tools=*|-t|-t?*|--dm-off|--dm-off=*|--dm-read|--dm-read=*|--dm-block|--dm-block=*)
      printf 'subagent-readonly.sh: caller may not override wrapper configuration: %s\n' "$argument" >&2
      exit 2
      ;;
  esac
done

FOCUS_GUARD="$HOME/dev-external/pi-focus-guard/index.ts"

if [ ! -f "$FOCUS_GUARD" ]; then
  printf 'subagent-readonly.sh: pi-focus-guard not found: %s\n' "$FOCUS_GUARD" >&2
  exit 1
fi

if pi-profile partner auth check --provider openai-codex 2>/dev/null | grep -qx 'ready'; then
  SUBAGENT_MODEL='openai-codex/gpt-5.6-terra'
elif pi-profile partner auth check --provider github-copilot 2>/dev/null | grep -qx 'ready'; then
  SUBAGENT_MODEL='github-copilot/gpt-5.6-terra'
else
  printf 'subagent-readonly.sh: neither openai-codex nor github-copilot is authenticated\n' >&2
  exit 1
fi

exec pi-profile partner -ne \
  -e "$FOCUS_GUARD" \
  --model "$SUBAGENT_MODEL" \
  --thinking minimal \
  --tools read,bash,grep,find,ls \
  --dm-read \
  "$@"
