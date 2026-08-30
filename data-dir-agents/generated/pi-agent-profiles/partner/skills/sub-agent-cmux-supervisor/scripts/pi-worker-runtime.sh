#!/usr/bin/env bash
# Shared Pi worker safety/runtime behavior. Skill-local adapters supply one
# trusted extension path (or an empty string) before forwarding user arguments.

pi_worker_runtime_main() {
  local trusted_extension="$1"
  shift

  usage_error() {
    printf 'worker launcher: requires exactly one --mode readonly|editable before --\n' >&2
    exit 2
  }

  local mode=""
  local mode_count=0
  local delimiter_seen=false
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
      *) usage_error ;;
    esac
  done

  [ "$delimiter_seen" = true ] && [ "$mode_count" -eq 1 ] || usage_error

  local argument
  for argument in "$@"; do
    case "$argument" in
      --print|--print=*|-p|-p?*|--extension|--extension=*|-e|-e?*|--model|--model=*|--provider|--provider=*|--thinking|--thinking=*|--tools|--tools=*|-t|-t?*|--dm-*)
        printf 'worker launcher: caller may not override launcher configuration: %s\n' "$argument" >&2
        exit 2
        ;;
    esac
  done

  local focus_guard="https://github.com/cgint/pi-focus-guard"
  local -a extension_args=(-e "$focus_guard")
  if [ -n "$trusted_extension" ]; then
    [ -f "$trusted_extension" ] || {
      printf 'worker launcher: required trusted extension not found: %s\n' "$trusted_extension" >&2
      exit 1
    }
    extension_args+=(-e "$trusted_extension")
  fi

  local subagent_model
  if pi-profile partner auth check --provider openai-codex 2>/dev/null | grep -qx 'ready'; then
    subagent_model='openai-codex/gpt-5.6-terra'
  elif pi-profile partner auth check --provider github-copilot 2>/dev/null | grep -qx 'ready'; then
    subagent_model='github-copilot/gpt-5.6-terra'
  else
    printf 'worker launcher: neither openai-codex nor github-copilot is authenticated\n' >&2
    exit 1
  fi

  local -a pi_args=(partner -ne)
  pi_args+=("${extension_args[@]}" --model "$subagent_model" --thinking minimal)
  if [ "$mode" = "readonly" ]; then
    pi_args+=(--tools read,bash,grep,find,ls --dm-read)
  fi

  PI_WRITE_GUARD_DIRS="."
  export PI_WRITE_GUARD_DIRS
  exec pi-profile "${pi_args[@]}" "$@"
}
