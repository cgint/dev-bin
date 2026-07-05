#!/bin/bash
# cg-task.sh — Unified codegiant task dispatcher
#
# Intent: Single entry point for structured codegiant tasks. Each task is
# defined by a prompt file with a # codegiant: header that declares its
# configuration (mode, ext filter, untracked check). The script auto-discovers
# tasks from prompt files — no hardcoded dispatch.
#
# Resolution order:
#   1. ./codegiant-tasks/ (repo-local, version-controlled)
#   2. <script-dir>/defaults/ (global defaults)
#
# Requirements:
#   - codegiant.py and codecollector.py in PATH
#   - GEMINI_API_KEY set
#   - Git repository (for diff-based tasks)
#
# Prompt file header format (first line):
#   # codegiant: mode=<diff-context|diff-only|context> [ext="*.md *.py"] [check_ut=yes]
#
# Modes:
#   diff-context  — Full repo context + diff attached (-a diff.txt)
#   diff-only     — Diff file only, no repo context (-i diff.txt)
#   context       — Full repo context, no diff (arch review, security, etc.)

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SDIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULTS_DIR="$SDIR/cg-task/defaults"
LOCAL_DIR="./codegiant-tasks"

# Resolve prompt directory: local first, then global
if [[ -d "$LOCAL_DIR" ]] && ls "$LOCAL_DIR"/*.txt 1>/dev/null 2>&1; then
    PROMPT_DIR="$LOCAL_DIR"
elif [[ -d "$DEFAULTS_DIR" ]] && ls "$DEFAULTS_DIR"/*.txt 1>/dev/null 2>&1; then
    PROMPT_DIR="$DEFAULTS_DIR"
else
    echo "Error: no prompt files found." >&2
    echo "  Local: $LOCAL_DIR/*.txt" >&2
    echo "  Global: $DEFAULTS_DIR/*.txt" >&2
    exit 1
fi

# Discover tasks: txt files with # codegiant: header
discover_tasks() {
    for f in "$PROMPT_DIR"/*.txt; do
        [[ -f "$f" ]] || continue
        if head -1 "$f" 2>/dev/null | grep -q '^# codegiant:'; then
            basename "$f" .txt
        fi
    done
}

TASK_LIST=$(discover_tasks)
if [[ -z "$TASK_LIST" ]]; then
    echo "Error: no valid task prompts found (missing '# codegiant:' header)." >&2
    exit 1
fi

usage() {
    echo "Usage: $SCRIPT_NAME <task> [--staged] [--diff-only] [hint]"
    echo ""
    echo "Tasks (from $(basename "$PROMPT_DIR")):"
    echo "$TASK_LIST" | while read -r t; do
        local prompt_file="$PROMPT_DIR/${t}.txt"
        local desc=$(sed -n '2p' "$prompt_file" | head -c 60)
        printf "  %-20s %s\n" "$t" "$desc"
    done
    echo ""
    echo "Options:"
    echo "  --staged      Review staged changes instead of working tree"
    echo "  --diff-only   Override task mode to diff-only (no repo context)"
    echo "  -h, --help    Show this help"
    echo ""
    echo "Hint:"
    echo "  Any trailing argument is appended to the prompt as dynamic focus."
}

# Args
if [[ $# -eq 0 ]] || [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage; exit 0
fi

TASK="$1"; shift

# Validate task
if ! echo "$TASK_LIST" | grep -qx "$TASK"; then
    echo "Unknown task: $TASK" >&2
    echo "Available: $(echo $TASK_LIST | tr '\n' ' ')" >&2
    exit 1
fi

STAGED=false
FORCE_DIFF_ONLY=false
HINT=""

for arg in "$@"; do
    case "$arg" in
        --staged) STAGED=true ;;
        --diff-only) FORCE_DIFF_ONLY=true ;;
        *) HINT="$arg" ;;
    esac
done

PROMPT_FILE="$PROMPT_DIR/${TASK}.txt"

# Parse config header
CONFIG_LINE=$(head -1 "$PROMPT_FILE" | grep '^# codegiant:' || true)
if [[ -z "$CONFIG_LINE" ]]; then
    echo "Missing config header in $PROMPT_FILE" >&2
    exit 1
fi

# Extract mode
DEFAULT_MODE=$(echo "$CONFIG_LINE" | grep -o 'mode=[^ ;]*' | head -1 | cut -d= -f2)
case "$DEFAULT_MODE" in
    diff-context|diff-only|context) ;;
    *) echo "Invalid mode '$DEFAULT_MODE' in $PROMPT_FILE" >&2; exit 1 ;;
esac

# Apply --diff-only override
if [[ "$FORCE_DIFF_ONLY" == true ]]; then
    MODE=diff-only
else
    MODE="$DEFAULT_MODE"
fi

# Extract ext and check_ut
EXT=$(echo "$CONFIG_LINE" | grep -o 'ext="[^"]*"' | cut -d'"' -f2 || true)
CHECK_UT=$(echo "$CONFIG_LINE" | grep -o 'check_ut=[^ ;]*' | cut -d= -f2 || echo "no")

# Output filename
OUT_NAME="${TASK}-review.md"
[[ "$MODE" == "diff-only" ]] && OUT_NAME="${TASK}-diffonly.md"

# Temp files
TMP_DIFF="$PROMPT_DIR/_tmp_diff.txt"
TMP_PRMPT="$PROMPT_DIR/_tmp_prompt.txt"
cleanup() { rm -f "$TMP_DIFF" "$TMP_PRMPT"; }
trap cleanup EXIT

# Diff-based modes: generate diff
if [[ "$MODE" == diff-context || "$MODE" == diff-only ]]; then
    # Untracked check
    if [[ "$CHECK_UT" == "yes" && -n "$EXT" ]]; then
        UT=$(git ls-files --others --exclude-standard -- $EXT 2>/dev/null || true)
        if [[ -n "$UT" ]]; then
            echo "Error: untracked files detected (not included in review):" >&2
            echo "$UT" | sed 's/^/  /' >&2
            echo "" >&2
            echo "  git add <files> then re-run" >&2
            exit 1
        fi
    fi

    # Generate diff
    if [[ -n "$EXT" ]]; then
        if [[ "$STAGED" == true ]]; then
            git diff --cached -- $EXT > "$TMP_DIFF" 2>/dev/null
        else
            git diff -- $EXT > "$TMP_DIFF" 2>/dev/null
        fi
    else
        if [[ "$STAGED" == true ]]; then
            git diff --cached > "$TMP_DIFF" 2>/dev/null
        else
            git diff > "$TMP_DIFF" 2>/dev/null
        fi
    fi

    [[ -s "$TMP_DIFF" ]] || { echo "No changes to review."; exit 0; }
fi

# Build prompt: static + hint
{
    cat "$PROMPT_FILE"
    if [[ -n "$HINT" ]]; then
        printf '\n\n**Additional focus:** %s\n' "$HINT"
    fi
} > "$TMP_PRMPT"

# Run codegiant
if [[ "$MODE" == diff-context ]]; then
    codegiant.py -y -F -o "$PROMPT_DIR/$OUT_NAME" -f "$TMP_PRMPT" -a "_tmp_diff.txt"
elif [[ "$MODE" == diff-only ]]; then
    codegiant.py -y -F -o "$PROMPT_DIR/$OUT_NAME" -f "$TMP_PRMPT" -i "_tmp_diff.txt"
else
    codegiant.py -y -F -o "$PROMPT_DIR/$OUT_NAME" -f "$TMP_PRMPT"
fi

echo "✓ Written to: $(basename "$PROMPT_DIR")/$OUT_NAME"