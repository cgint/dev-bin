#!/bin/bash
# cg-task.sh — Unified codegiant task dispatcher
#
# Intent: Single entry point for structured codegiant tasks. Each task is
# defined by a prompt file whose top-of-file frontmatter declares its
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
# Prompt file format (top of file):
#   ---
#   mode: diff-context
#   scan-dirs: "src tests"
#   ignore-dirs: "archive screenshots"
#   ---
#   Prompt body starts here.
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
    echo "Usage: $SCRIPT_NAME <task> [-d <dir>] [-e <exts>] [--staged] [--diff-only] [hint]"
    echo ""
    echo "Options:"
    echo "  -d, --dir, --scan-dir <dir> Limit context collection to specified directory (can be used multiple times)"
    echo "  -e, --ext, --extensions <exts> Limit file extensions (e.g. py,sh or 'py,sh')"
    echo "  --staged                     Review staged changes instead of working tree"
    echo "  --diff-only                  Override task mode to diff-only (no repo context)"
    echo "  -h, --help                   Show this help"
    echo ""
    echo "Hint:"
    echo "  Any trailing argument is appended to the prompt as dynamic focus."
    echo ""
    echo "Run without arguments to see available tasks."
    exit 0
fi

is_frontmatter_prompt() {
    local prompt_file="$1"
    head -1 "$prompt_file" 2>/dev/null | grep -qx '^---$'
}

frontmatter_end_line() {
    local prompt_file="$1"
    awk '
        NR == 1 {
            if ($0 != "---") {
                exit 1
            }
            next
        }
        $0 == "---" {
            print NR
            found = 1
            exit
        }
        END {
            if (!found) {
                exit 1
            }
        }
    ' "$prompt_file" 2>/dev/null || true
}

frontmatter_has_only_supported_keys() {
    local prompt_file="$1"
    awk '
        BEGIN {
            allowed["mode"] = 1
            allowed["scan-dirs"] = 1
            allowed["ignore-dirs"] = 1
            allowed["add"] = 1
            allowed["ext"] = 1
            allowed["check_ut"] = 1
            allowed["omit"] = 1
            closed = 0
        }
        NR == 1 {
            if ($0 != "---") {
                exit 1
            }
            next
        }
        $0 == "---" {
            closed = 1
            exit
        }
        {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            sub(/[[:space:]]+$/, "", line)
            if (line == "") {
                next
            }
            if (line !~ /^[[:alnum:]_-]+:[[:space:]]*/) {
                exit 1
            }
            key = line
            sub(/:.*/, "", key)
            if (!(key in allowed)) {
                exit 1
            }
        }
        END {
            if (!closed) {
                exit 1
            }
        }
    ' "$prompt_file" >/dev/null 2>&1
}

frontmatter_value() {
    local prompt_file="$1"
    local wanted="$2"
    awk -v wanted="$wanted" '
        NR == 1 {
            if ($0 != "---") {
                exit 1
            }
            next
        }
        $0 == "---" {
            exit
        }
        {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            sub(/[[:space:]]+$/, "", line)
            if (line !~ /^[[:alnum:]_-]+:[[:space:]]*/) {
                next
            }
            field = line
            sub(/:.*/, "", field)
            if (field != wanted) {
                next
            }
            value = substr(line, index(line, ":") + 1)
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            if (value ~ /^".*"$/) {
                value = substr(value, 2, length(value) - 2)
            }
            print value
            found = 1
            exit
        }
        END {
            if (!found) {
                exit 1
            }
        }
    ' "$prompt_file" 2>/dev/null || true
}

prompt_file_is_valid_task() {
    local prompt_file="$1"
    local mode

    [[ -f "$prompt_file" ]] || return 1
    is_frontmatter_prompt "$prompt_file" || return 1
    [[ -n "$(frontmatter_end_line "$prompt_file")" ]] || return 1
    frontmatter_has_only_supported_keys "$prompt_file" || return 1

    mode="$(frontmatter_value "$prompt_file" mode)"
    case "$mode" in
        diff-context|diff-only|context) return 0 ;;
        *) return 1 ;;
    esac
}

# Count valid prompts (files with frontmatter headers) in a directory
count_valid_prompts() {
    local dir="$1"
    local count=0
    for f in "$dir"/*.txt; do
        [[ -f "$f" ]] || continue
        if prompt_file_is_valid_task "$f"; then
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
    echo "Error: no valid task prompts found (missing top-of-file '---' frontmatter)." >&2
    echo "  Local: $LOCAL_DIR/*.txt ($LOCAL_VALID valid)" >&2
    echo "  Global: $DEFAULTS_DIR/*.txt ($DEFAULTS_VALID valid)" >&2
    exit 1
fi

# Discover tasks: txt files with frontmatter headers
discover_tasks() {
    for f in "$PROMPT_DIR"/*.txt; do
        [[ -f "$f" ]] || continue
        if prompt_file_is_valid_task "$f"; then
            basename "$f" .txt
        fi
    done
}

TASK_LIST=$(discover_tasks)

prompt_body_start_line() {
    local prompt_file="$1"
    local end_line
    end_line="$(frontmatter_end_line "$prompt_file")" || return 1
    printf '%s\n' "$((end_line + 1))"
}

prompt_preview_line() {
    local prompt_file="$1"
    local start_line
    start_line="$(prompt_body_start_line "$prompt_file")" || return 0
    sed -n "${start_line},\$p" "$prompt_file" | awk 'NF { print; exit }'
}

usage() {
    echo "Usage: $SCRIPT_NAME <task> [-d <dir>] [-e <exts>] [--staged] [--diff-only] [hint]"
    echo ""
    echo "Tasks (from $(basename "$PROMPT_DIR")):"
    printf '%s\n' "$TASK_LIST" | while read -r t; do
        [[ -n "$t" ]] || continue
        local prompt_file="$PROMPT_DIR/${t}.txt"
        local desc
        desc="$(prompt_preview_line "$prompt_file" | head -c 60)"
        printf "  %-20s %s\n" "$t" "$desc"
    done
    echo ""
    echo "Options:"
    echo "  -d, --dir, --scan-dir <dir> Limit context collection to specified directory (can be used multiple times)"
    echo "  -e, --ext, --extensions <exts> Limit file extensions (e.g. py,sh or 'py,sh')"
    echo "  --staged                     Review staged changes instead of working tree"
    echo "  --diff-only                  Override task mode to diff-only (no repo context)"
    echo "  -h, --help                   Show this help"
    echo ""
    echo "Hint:"
    echo "  Any trailing argument is appended to the prompt as dynamic focus."
}

extract_prompt_body() {
    local prompt_file="$1"
    local start_line
    start_line="$(prompt_body_start_line "$prompt_file")" || {
        echo "Error: missing or unterminated frontmatter in $prompt_file" >&2
        return 1
    }
    sed -n "${start_line},\$p" "$prompt_file"
}

# Args
if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

TASK="$1"
shift

# Validate task
if ! printf '%s\n' "$TASK_LIST" | grep -qx "$TASK"; then
    echo "Unknown task: $TASK" >&2
    echo "Available: $(printf '%s\n' "$TASK_LIST" | tr '\n' ' ')" >&2
    exit 1
fi

STAGED=false
FORCE_DIFF_ONLY=false
CLI_DIRS=()
CLI_EXTS=()
HINT_PARTS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --staged)
            STAGED=true
            shift
            ;;
        --diff-only)
            FORCE_DIFF_ONLY=true
            shift
            ;;
        -d|--dir|--scan-dir)
            if [[ $# -lt 2 ]]; then
                echo "Error: $1 requires a directory argument" >&2
                exit 1
            fi
            CLI_DIRS+=("$2")
            shift 2
            ;;
        -d=*|--dir=*|--scan-dir=*)
            CLI_DIRS+=("${1#*=}")
            shift
            ;;
        -e|--ext|--extensions)
            if [[ $# -lt 2 ]]; then
                echo "Error: $1 requires an extensions argument" >&2
                exit 1
            fi
            CLI_EXTS+=("$2")
            shift 2
            ;;
        -e=*|--ext=*|--extensions=*)
            CLI_EXTS+=("${1#*=}")
            shift
            ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do
                HINT_PARTS+=("$1")
                shift
            done
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            HINT_PARTS+=("$1")
            shift
            ;;
    esac
done

HINT="${HINT_PARTS[*]:-}"

PROMPT_FILE="$PROMPT_DIR/${TASK}.txt"

# Parse config frontmatter
if ! prompt_file_is_valid_task "$PROMPT_FILE"; then
    echo "Invalid or incomplete frontmatter in $PROMPT_FILE" >&2
    exit 1
fi

DEFAULT_MODE="$(frontmatter_value "$PROMPT_FILE" mode)"
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

# Helper: Normalize raw extensions into a comma-separated list for codegiant.py -e
normalize_ext_for_codegiant() {
    local raw="$1"
    [[ -z "$raw" ]] && return 0
    local cleaned
    cleaned="$(echo "$raw" | tr ',' ' ')"
    local items=()
    for item in $cleaned; do
        item="${item#\*}"
        item="${item#.}"
        if [[ -n "$item" ]]; then
            items+=("$item")
        fi
    done
    local IFS=","
    echo "${items[*]:-}"
}

# Helper: Convert raw extensions into pathspecs for git diff
normalize_ext_for_git() {
    local raw="$1"
    [[ -z "$raw" ]] && return 0
    local cleaned
    cleaned="$(echo "$raw" | tr ',' ' ')"
    local pathspecs=()
    for item in $cleaned; do
        if [[ "$item" == *\** || "$item" == */* ]]; then
            pathspecs+=("$item")
        elif [[ "$item" == .* ]]; then
            pathspecs+=("*$item")
        else
            pathspecs+=("*.$item")
        fi
    done
    echo "${pathspecs[@]:-}"
}

# Extract config values
EXT_FRONTMATTER="$(frontmatter_value "$PROMPT_FILE" ext)"
CHECK_UT="$(frontmatter_value "$PROMPT_FILE" check_ut)"
CHECK_UT="${CHECK_UT:-no}"
DIRS_RAW="$(frontmatter_value "$PROMPT_FILE" scan-dirs)"
EXCLUDE_DIRS_RAW="$(frontmatter_value "$PROMPT_FILE" ignore-dirs)"
ADD_RAW="$(frontmatter_value "$PROMPT_FILE" add)"
OMIT_RAW="$(frontmatter_value "$PROMPT_FILE" omit)"

DIRS=()
ADD_FILES=()
EXCLUDE_DIRS=()
OMIT_FILES=()
[[ -n "$DIRS_RAW" ]] && read -r -a DIRS <<< "$DIRS_RAW"
[[ -n "$ADD_RAW" ]] && read -r -a ADD_FILES <<< "$ADD_RAW"
[[ -n "$EXCLUDE_DIRS_RAW" ]] && read -r -a EXCLUDE_DIRS <<< "$EXCLUDE_DIRS_RAW"
[[ -n "$OMIT_RAW" ]] && read -r -a OMIT_FILES <<< "$OMIT_RAW"

# Override DIRS if CLI -d was specified
if [[ ${#CLI_DIRS[@]} -gt 0 ]]; then
    DIRS=("${CLI_DIRS[@]}")
fi

# Override EXT if CLI -e was specified, else use frontmatter ext
if [[ ${#CLI_EXTS[@]} -gt 0 ]]; then
    RAW_EXT="${CLI_EXTS[*]}"
else
    RAW_EXT="$EXT_FRONTMATTER"
fi

CODEGIANT_EXT="$(normalize_ext_for_codegiant "$RAW_EXT")"
read -r -a GIT_DIFF_PATHSPECS <<< "$(normalize_ext_for_git "$RAW_EXT")"

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
    if [[ "$CHECK_UT" == "yes" && ${#GIT_DIFF_PATHSPECS[@]} -gt 0 ]]; then
        UT=$(git ls-files --others --exclude-standard -- "${GIT_DIFF_PATHSPECS[@]}" 2>/dev/null || true)
        if [[ -n "$UT" ]]; then
            echo "Error: untracked files detected (not included in review):" >&2
            echo "$UT" | sed 's/^/  /' >&2
            echo "" >&2
            echo "  git add <files> then re-run" >&2
            exit 1
        fi
    fi

    # Generate diff
    if [[ ${#GIT_DIFF_PATHSPECS[@]} -gt 0 ]]; then
        if [[ "$STAGED" == true ]]; then
            git diff --cached -- "${GIT_DIFF_PATHSPECS[@]}" > "$TMP_DIFF" 2>/dev/null
        else
            git diff -- "${GIT_DIFF_PATHSPECS[@]}" > "$TMP_DIFF" 2>/dev/null
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

# Build prompt: frontmatter-stripped body + optional hint
{
    extract_prompt_body "$PROMPT_FILE"
    if [[ -n "$HINT" ]]; then
        printf '\n\n**Additional focus:** %s\n' "$HINT"
    fi
} > "$TMP_PRMPT"

# Build codegiant args ### add '-F' for fast - but quality is more valuable than speed
CODEGIANT_ARGS=(-y -o "./$OUT_NAME" -f "$TMP_PRMPT")

if [[ ${#DIRS[@]} -gt 0 ]]; then
    for dir in "${DIRS[@]}"; do
        CODEGIANT_ARGS+=(-d "$dir")
    done
fi
if [[ -n "$CODEGIANT_EXT" ]]; then
    CODEGIANT_ARGS+=(-e "$CODEGIANT_EXT")
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
