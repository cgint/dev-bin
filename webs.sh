#!/bin/bash

# webs.sh
#
# A web search wrapper for the Gemini CLI that performs grounded web searches.
# Uses gem.sh to invoke Gemini with web search capabilities.
#
# Usage: 
#   webs.sh "your search query"
#   webs.sh @file.txt "additional prompt about the file"
#   webs.sh @file.txt "find out more about this" -f output.txt
#   webs.sh -f result.txt "your search query"
#   webs.sh -o stream-json "your search query"
#
# Options:
#   @file.txt     Reference a file whose content will be included in the prompt
#   -f <file>     Write output to specified file instead of stdout
#   -m <model>    Model to use: flash, pro (default: flash, avoid using pro as it usually takes too long)
#   -o <format>   Output format: text, json, stream-json (default: text) - e.g. stream-json will contain the search queries used, json contains a lot of statistical details
#   -h, --help    Show this help message
#
# Examples:
#   webs.sh "What are the latest news about AI?"
#   webs.sh @notes.txt "research this topic and find recent developments"
#   webs.sh @code.py "find documentation for the libraries used" -f docs.txt

set -e

SCRIPT_DIR="$(dirname "$0")"

show_help() {
    sed -n '3,25p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

# Parse arguments
output_file=""
model="flash"
output_format="text"
input_file=""
prompt_parts=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -f)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: -f requires a filename argument" >&2
                exit 1
            fi
            output_file="$2"
            shift 2
            ;;
        -m)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: -m requires a model argument (flash, pro, lite)" >&2
                exit 1
            fi
            model="$2"
            shift 2
            ;;
        -o)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: -o requires a format argument (text, json, stream-json)" >&2
                exit 1
            fi
            output_format="$2"
            shift 2
            ;;
        @*)
            # File reference - strip the @ prefix
            input_file="${1#@}"
            if [[ ! -f "$input_file" ]]; then
                echo "Error: File not found: $input_file" >&2
                exit 1
            fi
            shift
            ;;
        *)
            # Collect as prompt part
            prompt_parts+=("$1")
            shift
            ;;
    esac
done

# Validate we have something to search
if [[ ${#prompt_parts[@]} -eq 0 && -z "$input_file" ]]; then
    echo "Error: No search query provided" >&2
    echo "Usage: webs.sh [@file.txt] \"your search query\" [-f output.txt]" >&2
    exit 1
fi

# Build the prompt
prompt=""

# Add file content if specified
if [[ -n "$input_file" ]]; then
    file_content=$(cat "$input_file")
    prompt="--- FILE CONTENT ($input_file) ---
$file_content
--- END FILE CONTENT ---

"
fi

# Add the user's prompt parts
user_prompt="${prompt_parts[*]}"
if [[ -n "$user_prompt" ]]; then
    prompt="${prompt}${user_prompt}"
else
    prompt="${prompt}Please analyze and research the above content using web search."
fi

# Add instruction to use web search
full_prompt="Use google_web_search to research the following and provide a comprehensive answer with sources:

$prompt"

# Execute gemini via gem.sh
if [[ -n "$output_file" ]]; then
    echo "Searching the web..." >&2
    echo "$full_prompt" | "$SCRIPT_DIR/gem.sh" "$model" -o "$output_format" > "$output_file"
    echo "Results written to: $output_file" >&2
else
    echo "$full_prompt" | "$SCRIPT_DIR/gem.sh" "$model" -o "$output_format"
fi
