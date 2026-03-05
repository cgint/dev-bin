#!/bin/bash

SPEAK_TO_ME_DIR="$HOME/dev/speak-to-me"
SCRIPT_NAME="$(basename "$0")"

show_help() {
    cat <<EOF
Usage:
  $SCRIPT_NAME [OPTIONS] <text>
  $SCRIPT_NAME [OPTIONS] <file>

Options:
  -h, --help    Show this help message

Examples:
  $SCRIPT_NAME "Hello world"
  $SCRIPT_NAME notes.md
EOF
}

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

if [ $# -eq 1 ] && [ -f "$1" ]; then
    FILE="$1"
    [[ "$FILE" != /* ]] && FILE="$(pwd)/$FILE"
    (cd "$SPEAK_TO_ME_DIR" && uv run speak -s -f "$FILE")
    exit $?
fi

(cd "$SPEAK_TO_ME_DIR" && uv run speak -s -t "$*")
