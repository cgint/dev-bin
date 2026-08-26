#!/usr/bin/env bash
# Launch a Pi subagent with an explicit editable or read-only execution mode.
set -euo pipefail

usage_error() {
  printf 'subagent.sh: requires exactly one --mode readonly|editable before --\n' >&2
  exit 2
}

mode=""
mode_count=0
delimiter_seen=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --)
      delimiter_seen=true
      shift
      break
      ;;
    --mode)
      [ "$#" -ge 2 ] || usage_error
      case "$2" in
        readonly|editable) ;;
        *) usage_error ;;
      esac
      mode="$2"
      mode_count=$((mode_count + 1))
      shift 2
      ;;
    *)
      usage_error
      ;;
  esac
done

[ "$delimiter_seen" = true ] && [ "$mode_count" -eq 1 ] || usage_error

for argument in "$@"; do
  case "$argument" in
    --print|--print=*|-p|-p?*|--extension|--extension=*|-e|-e?*|--model|--model=*|--provider|--provider=*|--thinking|--thinking=*|--tools|--tools=*|-t|-t?*|--dm-*)
      printf 'subagent.sh: caller may not override wrapper configuration: %s\n' "$argument" >&2
      exit 2
      ;;
  esac
done

FOCUS_GUARD="https://github.com/cgint/pi-focus-guard"
HERDR_REPORTER="$HOME/.pi/profiles/partner/agent/extensions/herdr-agent-state.ts"
# Always use FOCUS_GUARD to start with write permission limited to current dir
EXTENSION_ARGS=(-e "$FOCUS_GUARD") 


if [ "${HERDR_ENV:-}" = "1" ]; then
  if [ ! -f "$HERDR_REPORTER" ]; then
    printf 'subagent.sh: Herdr Pi reporter not found: %s\n' "$HERDR_REPORTER" >&2
    exit 1
  fi
  EXTENSION_ARGS+=(-e "$HERDR_REPORTER")
fi

if pi-profile partner auth check --provider openai-codex 2>/dev/null | grep -qx 'ready'; then
  SUBAGENT_MODEL='openai-codex/gpt-5.6-terra'
elif pi-profile partner auth check --provider github-copilot 2>/dev/null | grep -qx 'ready'; then
  SUBAGENT_MODEL='github-copilot/gpt-5.6-terra'
else
  printf 'subagent.sh: neither openai-codex nor github-copilot is authenticated\n' >&2
  exit 1
fi

PI_ARGS=(partner -ne)
if [ "${#EXTENSION_ARGS[@]}" -gt 0 ]; then
  PI_ARGS+=("${EXTENSION_ARGS[@]}")
fi
PI_ARGS+=(--model "$SUBAGENT_MODEL" --thinking minimal)

if [ "$mode" = "readonly" ]; then
  PI_ARGS+=(--tools read,bash,grep,find,ls --dm-read)
fi

# Scope the write guard to the launching working directory.
# This is the single source of truth for HOW sub-agent write boundaries are enforced;
# the delegation skills (sub-agent-handoff, -herdr-supervisor, -cmux-supervisor) state the
# durable rule without repeating this mechanism.
# subagent.sh has no --cwd option: the agent inherits this process's cwd, and
# PI_WRITE_GUARD_DIRS="." makes the pi-focus-guard allowlist resolve to that cwd, so an
# editable worker can write only within the directory tree rooted at its launch cwd.
# Set unconditionally (deliberate encapsulation, not a fallback). A per-session
# flag/session write-guard override still outranks this env value, and it overrides any
# .pi/settings.json allowlist.
PI_WRITE_GUARD_DIRS="."
export PI_WRITE_GUARD_DIRS

exec pi-profile "${PI_ARGS[@]}" "$@"
