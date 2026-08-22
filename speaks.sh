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
  -v, --voice <name> Select the TTS voice (default: Puck)
  --wav <out.wav>    Write a WAV file using GenerateContent TTS (no playback)

Examples:
  $SCRIPT_NAME "Hello world"                         # stream playback (Live API)
  $SCRIPT_NAME --voice Fenrir notes.md                # stream playback from file (Live API)
  $SCRIPT_NAME --wav out.wav --voice Kore "Hello"    # write WAV (GenerateContent)
EOF
}

VOICE=""
OUT=""

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--voice)
            if [ $# -lt 2 ] || [ -z "$2" ]; then
                echo "Error: --voice requires a voice name." >&2
                exit 2
            fi
            VOICE="$2"
            shift 2
            ;;
        --wav)
            if [ $# -lt 2 ] || [ -z "$2" ]; then
                echo "Error: --wav requires an output path." >&2
                exit 2
            fi
            OUT="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -eq 0 ]; then
    echo "Error: provide text or a file path." >&2
    echo >&2
    show_help
    exit 2
fi

VOICE_ARGS=()
if [ -n "$VOICE" ]; then
    VOICE_ARGS=(--voice "$VOICE")
fi

# WAV output mode (GenerateContent TTS)
if [ -n "$OUT" ]; then
    # If a single arg is a file, read it and synthesize.
    if [ $# -eq 1 ] && [ -f "$1" ]; then
        FILE="$1"
        [[ "$FILE" != /* ]] && FILE="$(pwd)/$FILE"
        (cd "$SPEAK_TO_ME_DIR" && uv run speakwavf -f "$FILE" -o "$OUT" "${VOICE_ARGS[@]}")
        exit $?
    fi

    # Otherwise treat remaining args as text.
    (cd "$SPEAK_TO_ME_DIR" && uv run speakwav -t "$*" -o "$OUT" "${VOICE_ARGS[@]}")
    exit $?
fi

# Default: streaming playback (Live API)
if [ $# -eq 1 ] && [ -f "$1" ]; then
    FILE="$1"
    [[ "$FILE" != /* ]] && FILE="$(pwd)/$FILE"
    (cd "$SPEAK_TO_ME_DIR" && uv run speak -s "${VOICE_ARGS[@]}" -f "$FILE")
    exit $?
fi

(cd "$SPEAK_TO_ME_DIR" && uv run speak -s "${VOICE_ARGS[@]}" -t "$*")
