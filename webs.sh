#!/bin/bash

# Search the web using Gemini or GitHub Copilot.
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
  WEBS_PROVIDER=gemini|copilot  (default: gemini)
  COPILOT_MODEL=gpt-5.6-luna
  COPILOT_EFFORT=none
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
        gemini|copilot) ;;
        *) die "WEBS_PROVIDER must be 'gemini' or 'copilot', got '$provider'" ;;
    esac
    [[ "$output_format" == text || "$output_format" == json || "$output_format" == stream-json ]] || \
        die "Output format must be text, json, or stream-json"
    [[ "$provider" != copilot || "$output_format" != stream-json ]] || \
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
    local copilot_effort="${COPILOT_EFFORT:-none}"
    command -v copilot >/dev/null 2>&1 || die "Copilot CLI not found on PATH"
    copilot -p "$prompt" \
        --model "$copilot_model" --effort "$copilot_effort" \
        --allow-tool=web_search --allow-all-urls --output-format "$output_format"
}

main() {
    parse_args "$@"
    local prompt
    prompt="$(build_prompt)"
    local tmp_out_file
    tmp_out_file="$(mktemp /tmp/webs_output.XXXXXX)"

    echo "Searching the web with $provider..." >&2
    echo "Streaming results to: $tmp_out_file" >&2
    if [[ "$provider" == gemini ]]; then
        run_gemini "$prompt"
    else
        run_copilot "$prompt"
    fi | tee "$tmp_out_file"

    if [[ -n "$output_file" ]]; then
        cp "$tmp_out_file" "$output_file"
        echo "Results written to your configured output file: $output_file" >&2
    fi
}

main "$@"
