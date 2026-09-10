#!/usr/bin/env bash
# Shared Pi worker safety/runtime behavior. PI_WORKER_PROFILE selects the
# deployed Pi profile for every worker and defaults to the minimal profile.

readonly PI_WORKER_PROFILE="${PI_WORKER_PROFILE:-minimal}"

pi_worker_profile_agent_dir() {
  case "$PI_WORKER_PROFILE" in
    ""|*[!A-Za-z0-9_-]*)
      printf 'worker launcher: invalid PI_WORKER_PROFILE: %s\n' "$PI_WORKER_PROFILE" >&2
      return 2
      ;;
    default)
      printf '%s\n' "$HOME/.pi/agent"
      ;;
    *)
      printf '%s\n' "$HOME/.pi/profiles/$PI_WORKER_PROFILE/agent"
      ;;
  esac
}

pi_worker_herdr_reporter_path() {
  printf '%s/extensions/herdr-agent-state.ts\n' "$(pi_worker_profile_agent_dir)"
}

pi_worker_runtime_main() {
  pi_worker_profile_agent_dir >/dev/null || exit $?

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

  local config_root config_path config_line config_provider="" config_model="" config_thinking=""
  config_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$config_root" && -f "$config_root/.sub_agent_conf" ]]; then
    config_path="$config_root/.sub_agent_conf"
    while IFS= read -r config_line || [[ -n "$config_line" ]]; do
      case "$config_line" in
        ""|\#*) ;;
        PROVIDER=*)
          [[ -z "$config_provider" && "$config_line" =~ ^PROVIDER=([A-Za-z0-9._-]+)$ ]] || {
            printf 'worker launcher: invalid .sub_agent_conf PROVIDER line: %s\n' "$config_line" >&2
            exit 2
          }
          config_provider="${BASH_REMATCH[1]}"
          ;;
        MODEL=*)
          [[ -z "$config_model" && "$config_line" =~ ^MODEL=([A-Za-z0-9._-]+)$ ]] || {
            printf 'worker launcher: invalid .sub_agent_conf MODEL line: %s\n' "$config_line" >&2
            exit 2
          }
          config_model="${BASH_REMATCH[1]}"
          ;;
        THINKING=*)
          [[ -z "$config_thinking" && "$config_line" =~ ^THINKING=(off|minimal|low|medium|high|xhigh|max)$ ]] || {
            printf 'worker launcher: invalid .sub_agent_conf THINKING line: %s\n' "$config_line" >&2
            exit 2
          }
          config_thinking="${BASH_REMATCH[1]}"
          ;;
        *)
          printf 'worker launcher: invalid .sub_agent_conf line: %s\n' "$config_line" >&2
          exit 2
          ;;
      esac
    done <"$config_path"

    [[ -n "$config_provider" && -n "$config_model" ]] || {
      printf 'worker launcher: .sub_agent_conf requires both PROVIDER and MODEL\n' >&2
      exit 2
    }

    local available_models
    if ! available_models="$(pi-profile "$PI_WORKER_PROFILE" --list-models "$config_provider/$config_model" 2>&1)" ||
      ! awk -v provider="$config_provider" -v model="$config_model" '$1 == provider && $2 == model { found = 1 } END { exit !found }' <<<"$available_models"; then
      printf 'worker launcher: .sub_agent_conf model is unavailable: %s/%s\n' "$config_provider" "$config_model" >&2
      exit 1
    fi
  fi

  local subagent_model
  if [[ -z "$config_provider" ]]; then
    if pi-profile "$PI_WORKER_PROFILE" auth check --provider openai-codex 2>/dev/null | grep -qx 'ready'; then
      subagent_model='openai-codex/gpt-5.6-terra'
    elif pi-profile "$PI_WORKER_PROFILE" auth check --provider github-copilot 2>/dev/null | grep -qx 'ready'; then
      subagent_model='github-copilot/gpt-5.6-terra'
    else
      printf 'worker launcher: neither openai-codex nor github-copilot is authenticated\n' >&2
      exit 1
    fi
  fi

  local -a pi_args=("$PI_WORKER_PROFILE" -ne)
  pi_args+=("${extension_args[@]}")
  if [[ -n "$config_provider" ]]; then
    pi_args+=(--provider "$config_provider" --model "$config_model")
    if [[ -n "$config_thinking" ]]; then
      pi_args+=(--thinking "$config_thinking")
    fi
  else
    pi_args+=(--model "$subagent_model" --thinking minimal)
  fi
  if [ "$mode" = "readonly" ]; then
    pi_args+=(--tools read,bash,grep,find,ls --dm-read)
  fi

  PI_WRITE_GUARD_DIRS="."
  export PI_WRITE_GUARD_DIRS
  exec pi-profile "${pi_args[@]}" "$@"
}
