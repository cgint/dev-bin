#!/usr/bin/env bash
# Shared Pi worker safety/runtime behavior. Prefer named Pi profiles when the
# pi-profile wrapper is installed; otherwise use the direct ~/.pi/agent layout.

if command -v pi-profile >/dev/null 2>&1; then
  readonly PI_WORKER_PROFILE="${PI_WORKER_PROFILE:-minimal}"
  readonly -a PI_WORKER_COMMAND=(pi-profile "$PI_WORKER_PROFILE")
else
  if [[ -n "${PI_WORKER_PROFILE:-}" && "$PI_WORKER_PROFILE" != "default" ]]; then
    printf 'worker launcher: pi-profile is unavailable; cannot select non-default profile: %s\n' "$PI_WORKER_PROFILE" >&2
    exit 2
  fi
  readonly PI_WORKER_PROFILE="default"
  readonly -a PI_WORKER_COMMAND=(pi)
fi

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

# Some providers register their models from inside a Pi extension, so their
# models are invisible under -ne unless that extension is loaded explicitly.
# This map is the launcher's own trusted set: .sub_agent_conf selects a provider
# but can never introduce extension sources.
pi_worker_provider_extensions() {
  case "$1" in
    home-llm) printf '%s\n' 'https://github.com/cgint/pi-olla-autodetect' ;;
  esac
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
  fi

  if [[ -n "$config_provider" ]]; then
    local provider_extension
    while IFS= read -r provider_extension; do
      if [ -n "$provider_extension" ]; then
        extension_args+=(-e "$provider_extension")
      fi
    done < <(pi_worker_provider_extensions "$config_provider")

    # Availability must be probed under the same discovery mode and explicit
    # extensions as the eventual launch, otherwise the probe can succeed while
    # the worker itself cannot resolve the provider.
    local available_models
    if ! available_models="$("${PI_WORKER_COMMAND[@]}" -ne "${extension_args[@]}" --list-models "$config_provider/$config_model" 2>&1)" ||
      ! awk -v provider="$config_provider" -v model="$config_model" '$1 == provider && $2 == model { found = 1 } END { exit !found }' <<<"$available_models"; then
      printf 'worker launcher: .sub_agent_conf model is unavailable: %s/%s\n' "$config_provider" "$config_model" >&2
      exit 1
    fi
  fi

  local subagent_model
  local env_provider="" env_model="" env_thinking=""
  if [[ -z "$config_provider" && -n "${PI_WORKER_DEFAULT_MODEL:-}" ]]; then
    if [[ "$PI_WORKER_DEFAULT_MODEL" =~ ^([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)(:([a-z]+))?$ ]]; then
      env_provider="${BASH_REMATCH[1]}"
      env_model="${BASH_REMATCH[2]}"
      if [[ -n "${BASH_REMATCH[4]:-}" ]]; then
        env_thinking="${BASH_REMATCH[4]}"
      fi
    else
      printf 'worker launcher: invalid PI_WORKER_DEFAULT_MODEL: %s (expected provider/model or provider/model:thinking)\n' "$PI_WORKER_DEFAULT_MODEL" >&2
      exit 2
    fi
    if [[ -n "$env_thinking" && ! "$env_thinking" =~ ^(off|minimal|low|medium|high|xhigh|max)$ ]]; then
      printf 'worker launcher: invalid thinking level in PI_WORKER_DEFAULT_MODEL: %s\n' "$env_thinking" >&2
      exit 2
    fi
  fi

  if [[ -n "$env_provider" ]]; then
    local env_provider_extension
    while IFS= read -r env_provider_extension; do
      if [ -n "$env_provider_extension" ]; then
        extension_args+=(-e "$env_provider_extension")
      fi
    done < <(pi_worker_provider_extensions "$env_provider")

    # Availability must be probed under the same discovery mode and explicit
    # extensions as the eventual launch, otherwise the probe can succeed while
    # the worker itself cannot resolve the provider.
    local env_available_models
    if ! env_available_models=$("${PI_WORKER_COMMAND[@]}" -ne "${extension_args[@]}" --list-models "$env_provider/$env_model" 2>&1) ||
      ! awk -v provider="$env_provider" -v model="$env_model" '$1 == provider && $2 == model { found = 1 } END { exit !found }' <<<"$env_available_models"; then
      printf 'worker launcher: PI_WORKER_DEFAULT_MODEL model is unavailable: %s/%s\n' "$env_provider" "$env_model" >&2
      exit 1
    fi
  fi

  if [[ -z "$config_provider" && -z "$env_provider" ]]; then
    if "${PI_WORKER_COMMAND[@]}" auth check --provider openai-codex 2>/dev/null | grep -qx 'ready'; then
      subagent_model='openai-codex/gpt-5.6-terra'
    elif "${PI_WORKER_COMMAND[@]}" auth check --provider github-copilot 2>/dev/null | grep -qx 'ready'; then
      subagent_model='github-copilot/gpt-5.6-terra'
    else
      printf 'worker launcher: neither openai-codex nor github-copilot is authenticated\n' >&2
      exit 1
    fi
  fi

  local -a pi_args=(-ne)
  pi_args+=("${extension_args[@]}")
  if [[ -n "$config_provider" ]]; then
    pi_args+=(--provider "$config_provider" --model "$config_model")
    if [[ -n "$config_thinking" ]]; then
      pi_args+=(--thinking "$config_thinking")
    fi
  elif [[ -n "$env_provider" ]]; then
    pi_args+=(--provider "$env_provider" --model "$env_model")
    if [[ -n "$env_thinking" ]]; then
      pi_args+=(--thinking "$env_thinking")
    fi
  else
    pi_args+=(--model "$subagent_model" --thinking minimal)
  fi
  if [ "$mode" = "readonly" ]; then
    pi_args+=(--tools read,bash,grep,find,ls --dm-read)
  fi

  PI_WRITE_GUARD_DIRS="."
  export PI_WRITE_GUARD_DIRS
  exec "${PI_WORKER_COMMAND[@]}" "${pi_args[@]}" "$@"
}
