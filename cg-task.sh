#!/bin/bash
# cg-task.sh — Unified codegiant task dispatcher
#
# Intent: Single entry point for structured codegiant tasks. Each task is
# defined by a prompt file with a # codegiant: header that declares its
# configuration (mode, ext filter, untracked check, and optional context
# scoping). The script auto-discovers tasks from prompt files — no hardcoded
# dispatch.
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
#   # codegiant: mode=<diff-context|diff-only|context> [ext="*.md *.py"] [check_ut=yes] [dirs="src tests"] [add="README.md AGENTS.md"] [xdirs="archive screenshots"] [omit="*.png"]
#
# Modes:
#   diff-context  — Repo context (optionally scoped) + diff attached (-a diff.txt)
#   diff-only     — Diff file only, no repo context (-i diff.txt)
#   context       — Repo context (optionally scoped), no diff

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SDIR="$(cd "$(dirname "$(which "$0")")" && pwd)"
DEFAULTS_DIR="$SDIR/cg-task/defaults"
LOCAL_DIR="./codegiant-tasks"

# Detect help request early so we can skip discovery
HELP_REQUEST=false
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    HELP_REQUEST=true
fi

# If explicit -h/--help, show minimal help and exit before discovery
if [[ "$HELP_REQUEST" == true ]]; then
    echo "Usage: $SCRIPT_NAME <task> [--staged] [--diff-only] [hint]"
    echo ""
    echo "Options:"
    echo "  --staged      Review staged changes instead of working tree"
    echo "  --diff-only   Override task mode to diff-only (no repo context)"
    echo "  -h, --help    Show this help"
    echo ""
    echo "Hint:"
    echo "  Any trailing argument is appended to the prompt as dynamic focus."
    echo ""
    echo "Run without arguments to see available tasks."
    exit 0
fi

# Count valid prompts (files with # codegiant: header) in a directory
count_valid_prompts() {
    local dir="$1"
    local count=0
    for f in "$dir"/*.txt; do
        [[ -f "$f" ]] || continue
        if head -1 "$f" 2>/dev/null | grep -q '^# codegiant:'; then
            ((++count)) || true
        fi
    done
    echo "$count"
}

# Resolve prompt directory: local first (if valid prompts exist), then global
LOCAL_VALID=$(count_valid_prompts "$LOCAL_DIR" 2>/dev/null || echo 0)
DEFAULTS_VALID=$(count_valid_prompts "$DEFAULTS_DIR" 2>/dev/null || echo 0)

if [[ "$LOCAL_VALID" -gt 0 ]]; then
    PROMPT_DIR="$LOCAL_DIR"
elif [[ "$DEFAULTS_VALID" -gt 0 ]]; then
    PROMPT_DIR="$DEFAULTS_DIR"
else
    echo "Error: no valid task prompts found (missing '# codegiant:' header)." >&2
    echo "  Local: $LOCAL_DIR/*.txt ($LOCAL_VALID valid)" >&2
    echo "  Global: $DEFAULTS_DIR/*.txt ($DEFAULTS_VALID valid)" >&2
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

extract_quoted_config() {
    local config_line="$1"
    local key="$2"
    if [[ $config_line =~ (^|[[:space:]])${key}=\"([^\"]*)\" ]]; then
        printf '%s\n' "${BASH_REMATCH[2]}"
    fi
}

# Args
if [[ $# -eq 0 ]]; then
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

# Extract config values
EXT=$(extract_quoted_config "$CONFIG_LINE" ext)
CHECK_UT=$(echo "$CONFIG_LINE" | grep -o 'check_ut=[^ ;]*' | cut -d= -f2 || echo "no")
DIRS_RAW=$(extract_quoted_config "$CONFIG_LINE" dirs)
ADD_RAW=$(extract_quoted_config "$CONFIG_LINE" add)
XDIRS_RAW=$(extract_quoted_config "$CONFIG_LINE" xdirs)
OMIT_RAW=$(extract_quoted_config "$CONFIG_LINE" omit)

DIRS=()
ADD_FILES=()
EXCLUDE_DIRS=()
OMIT_FILES=()
[[ -n "$DIRS_RAW" ]] && read -r -a DIRS <<< "$DIRS_RAW"
[[ -n "$ADD_RAW" ]] && read -r -a ADD_FILES <<< "$ADD_RAW"
[[ -n "$XDIRS_RAW" ]] && read -r -a EXCLUDE_DIRS <<< "$XDIRS_RAW"
[[ -n "$OMIT_RAW" ]] && read -r -a OMIT_FILES <<< "$OMIT_RAW"

# Output filename
OUT_NAME="cg-task-result-${TASK}.md"

# Temp files — always in cwd (not PROMPT_DIR) so codegiant.py can find them
TMP_DIFF="._cg_tmp_diff.txt"
TMP_PRMPT="._cg_tmp_prompt.txt"
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

# Build codegiant args
CODEGIANT_ARGS=(-y -F -o "./$OUT_NAME" -f "$TMP_PRMPT")

if [[ ${#DIRS[@]} -gt 0 ]]; then
    for dir in "${DIRS[@]}"; do
        CODEGIANT_ARGS+=(-d "$dir")
    done
fi
if [[ ${#ADD_FILES[@]} -gt 0 ]]; then
    for file in "${ADD_FILES[@]}"; do
        CODEGIANT_ARGS+=(-a "$file")
    done
fi
if [[ ${#EXCLUDE_DIRS[@]} -gt 0 ]]; then
    for dir in "${EXCLUDE_DIRS[@]}"; do
        CODEGIANT_ARGS+=(-x "$dir")
    done
fi
if [[ ${#OMIT_FILES[@]} -gt 0 ]]; then
    for pattern in "${OMIT_FILES[@]}"; do
        CODEGIANT_ARGS+=(-O "$pattern")
    done
fi

# Run codegiant
if [[ "$MODE" == diff-context ]]; then
    CODEGIANT_ARGS+=(-a "$TMP_DIFF")
elif [[ "$MODE" == diff-only ]]; then
    CODEGIANT_ARGS+=(-i "$TMP_DIFF")
fi

codegiant.py "${CODEGIANT_ARGS[@]}"

echo "✓ Written to: $OUT_NAME"
