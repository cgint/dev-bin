#!/bin/bash

# Search the web using Gemini, GitHub Copilot, or Codex.
# Usage: webs.sh [@file] [query ...] [-f output] [-m model] [-o format]

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_env_loader.sh"

provider="${WEBS_PROVIDER:-gemini}"
output_file=""
output_format="text"
input_file=""
prompt_parts=()

die() {
    echo "Error: $*" >&2
    exit 1
}

show_help() {
    sed -n '3,7p' "$0" | sed 's/^# //' | sed 's/^#//'
    cat >&2 <<'EOF'

Options:
  @file.txt     Include a file in the search prompt
  -f <file>     Copy the output to a file after completion
  -o <format>   text, json, or stream-json (stream-json is Gemini-only)
  -h, --help    Show this help

Environment (.env or shell):
  WEBS_PROVIDER=gemini|copilot|codex  (default: gemini)
  COPILOT_MODEL=auto
  COPILOT_EFFORT=minimal  (used only when COPILOT_MODEL is not auto)
  CODEX_MODEL=             (uses Codex's configured default when unset)
EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) show_help ;;
            -f)
                [[ -n "${2:-}" && "$2" != -* ]] || die "-f requires a filename argument"
                output_file="$2"; shift 2 ;;
            -o)
                [[ -n "${2:-}" && "$2" != -* ]] || die "-o requires a format argument"
                output_format="$2"; shift 2 ;;
            @*)
                input_file="${1#@}"
                [[ -f "$input_file" ]] || die "File not found: $input_file"
                shift ;;
            -*) die "Unknown option: $1" ;;
            *) prompt_parts+=("$1"); shift ;;
        esac
    done

    [[ ${#prompt_parts[@]} -gt 0 || -n "$input_file" ]] || die "No search query provided"
    case "$provider" in
        gemini|copilot|codex) ;;
        *) die "WEBS_PROVIDER must be 'gemini', 'copilot', or 'codex', got '$provider'" ;;
    esac
    [[ "$output_format" == text || "$output_format" == json || "$output_format" == stream-json ]] || \
        die "Output format must be text, json, or stream-json"
    [[ "$provider" == gemini || "$output_format" != stream-json ]] || \
        die "stream-json output is only supported with the Gemini provider"
}

build_prompt() {
    local prompt=""
    if [[ -n "$input_file" ]]; then
        prompt="--- FILE CONTENT ($input_file) ---
$(cat "$input_file")
--- END FILE CONTENT ---

"
    fi

    if [[ ${#prompt_parts[@]} -gt 0 ]]; then
        prompt+="${prompt_parts[*]}"
    else
        prompt+="Please analyze and research the above content using web search."
    fi

    if [[ "$provider" == gemini ]]; then
        printf 'Use google_web_search to research the following and provide a comprehensive answer with sources:\n\n%s' "$prompt"
    else
        printf 'Use the native web_search tool to research the following and provide a comprehensive answer with sources. Do not use webs.sh, Gemini, or external wrappers:\n\n%s' "$prompt"
    fi
}

run_gemini() {
    local prompt="$1"
    local disable_mcp="__DISABLE_ALL_MCP__"
    echo "$prompt" | GEMINI_CLI_TRUST_WORKSPACE=true "$SCRIPT_DIR/gem.sh" flash \
        -o "$output_format" --allowed-mcp-server-names "$disable_mcp"
}

run_copilot() {
    local prompt="$1"
    local copilot_model="${COPILOT_MODEL:-auto}"
    local copilot_effort="${COPILOT_EFFORT:-minimal}"
    local -a copilot_model_args=(--model "$copilot_model")
    if [[ "$copilot_model" != "auto" ]]; then
        copilot_model_args+=(--effort "$copilot_effort")
    fi
    command -v copilot >/dev/null 2>&1 || die "Copilot CLI not found on PATH"
    copilot -p "$prompt" \
        "${copilot_model_args[@]}" \
        --allow-tool=web_search --allow-all-urls --output-format "$output_format"
}

run_codex() {
    local prompt="$1"
    local codex_model="${CODEX_MODEL:-}"
    local last_message_file
    local -a codex_model_args=()
    last_message_file="$(mktemp /tmp/webs_codex_last_message.XXXXXX)"
    trap 'rm -f "$last_message_file"' RETURN

    command -v codex >/dev/null 2>&1 || die "Codex CLI not found on PATH"
    if [[ -n "$codex_model" ]]; then
        codex_model_args=(--model "$codex_model")
    fi
    if [[ "$output_format" == json ]]; then
        codex --search --sandbox read-only --ask-for-approval never exec --ephemeral --skip-git-repo-check \
            "${codex_model_args[@]}" --json "$prompt"
    else
        codex --search --sandbox read-only --ask-for-approval never exec --ephemeral --skip-git-repo-check \
            "${codex_model_args[@]}" --output-last-message "$last_message_file" "$prompt" >&2
        cat "$last_message_file"
    fi
}

main() {
    parse_args "$@"
    local prompt
    prompt="$(build_prompt)"
    local tmp_out_file
    tmp_out_file="$(mktemp /tmp/webs_output.XXXXXX)"

    echo "Searching the web with $provider..." >&2
    echo "Streaming results to: $tmp_out_file" >&2
    case "$provider" in
        gemini) run_gemini "$prompt" ;;
        copilot) run_copilot "$prompt" ;;
        codex) run_codex "$prompt" ;;
    esac | tee "$tmp_out_file"

    if [[ -n "$output_file" ]]; then
        cp "$tmp_out_file" "$output_file"
        echo "Results written to your configured output file: $output_file" >&2
    fi
}

main "$@"
