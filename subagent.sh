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

if pi-profile partner auth check --provider openai-codex 2>/dev/null | grep -qx 'ready'; then
  SUBAGENT_MODEL='openai-codex/gpt-5.6-terra'
elif pi-profile partner auth check --provider github-copilot 2>/dev/null | grep -qx 'ready'; then
  SUBAGENT_MODEL='github-copilot/gpt-5.6-terra'
else
  printf 'subagent.sh: neither openai-codex nor github-copilot is authenticated\n' >&2
  exit 1
fi

exec pi-profile partner -ne --model "$SUBAGENT_MODEL" --thinking minimal "$@"
