#!/bin/bash

SPEAK_TO_ME_DIR="$HOME/dev/speak-to-me"
SCRIPT_NAME="$(basename "$0")"

show_help() {
    cat <<EOF
Usage:
  $SCRIPT_NAME [OPTIONS] <text>
  $SCRIPT_NAME [OPTIONS] <file>

Options:
  -h, --help         Show this help message
  --wav <out.wav>    Write a WAV file using GenerateContent TTS (no playback)

Examples:
  $SCRIPT_NAME "Hello world"                 # stream playback (Live API)
  $SCRIPT_NAME notes.md                       # stream playback from file (Live API)
  $SCRIPT_NAME --wav out.wav "Hello world"   # write WAV (GenerateContent)
EOF
}

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# WAV output mode (GenerateContent TTS)
if [ "$1" = "--wav" ]; then
    OUT="$2"
    shift 2
    if [ -z "$OUT" ] || [ $# -eq 0 ]; then
        echo "Error: --wav requires an output path and some text (or a file path)." >&2
        echo >&2
        show_help
        exit 2
    fi

    # If a single arg is a file, read it and synthesize.
    if [ $# -eq 1 ] && [ -f "$1" ]; then
        FILE="$1"
        [[ "$FILE" != /* ]] && FILE="$(pwd)/$FILE"
        (cd "$SPEAK_TO_ME_DIR" && uv run speakwavf -f "$FILE" -o "$OUT")
        exit $?
    fi

    # Otherwise treat remaining args as text.
    (cd "$SPEAK_TO_ME_DIR" && uv run speakwav -t "$*" -o "$OUT")
    exit $?
fi

# Default: streaming playback (Live API)
if [ $# -eq 1 ] && [ -f "$1" ]; then
    FILE="$1"
    [[ "$FILE" != /* ]] && FILE="$(pwd)/$FILE"
    (cd "$SPEAK_TO_ME_DIR" && uv run speak -s -f "$FILE")
    exit $?
fi

(cd "$SPEAK_TO_ME_DIR" && uv run speak -s -t "$*")
