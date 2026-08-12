#!/usr/bin/env bash
# Launch an editable Pi subagent with the isolated partner profile.
set -euo pipefail

for argument in "$@"; do
  [ "$argument" = "--" ] && break
  case "$argument" in
    --print|--print=*|-p|-p?*|--extension|--extension=*|-e|-e?*|--model|--model=*|--provider|--provider=*|--thinking|--thinking=*|--tools|--tools=*|-t|-t?*)
      printf 'subagent.sh: caller may not override wrapper configuration: %s\n' "$argument" >&2
      exit 2
      ;;
  esac
done

HERDR_REPORTER="$HOME/.pi/profiles/partner/agent/extensions/herdr-agent-state.ts"
HERDR_EXTENSION_ARGS=()
if [ "${HERDR_ENV:-}" = "1" ]; then
  if [ ! -f "$HERDR_REPORTER" ]; then
    printf 'subagent.sh: Herdr Pi reporter not found: %s\n' "$HERDR_REPORTER" >&2
    exit 1
  fi
  HERDR_EXTENSION_ARGS=(-e "$HERDR_REPORTER")
fi

if pi-profile partner auth check --provider openai-codex 2>/dev/null | grep -qx 'ready'; then
  SUBAGENT_MODEL='openai-codex/gpt-5.6-terra'
elif pi-profile partner auth check --provider github-copilot 2>/dev/null | grep -qx 'ready'; then
  SUBAGENT_MODEL='github-copilot/gpt-5.6-terra'
else
  printf 'subagent.sh: neither openai-codex nor github-copilot is authenticated\n' >&2
  exit 1
fi

exec pi-profile partner -ne "${HERDR_EXTENSION_ARGS[@]}" --model "$SUBAGENT_MODEL" --thinking minimal "$@"
