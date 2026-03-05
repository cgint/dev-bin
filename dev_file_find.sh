#!/bin/bash

# Optional: emit only matching file paths (one per line).
# Useful for piping into tools like: dev_file_find.sh --files-only foo | xargs cat
FILES_ONLY=0
if [ "$1" = "--files-only" ] || [ "$1" = "--quiet" ] || [ "$1" = "-q" ] || [ "$1" = "-F" ]; then
    FILES_ONLY=1
    shift
fi

# Check if base directory exists
BASE_DIR=$HOME/dev
if [ ! -d "$BASE_DIR" ]; then
    echo "Error: Directory $BASE_DIR does not exist" >&2
    exit 1
fi

# Show help/usage if no query provided
if [ -z "$1" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Find files by name in your dev workspace."
    echo
    echo "Who this is for:"
    echo "- You (quick CLI lookup) or an AI agent (tooling/automation)"
    echo
    echo "Where it searches:"
    echo "- Base directory: $HOME/dev"
    echo "- Matches filenames containing your query (case-insensitive)"
    echo "- Skips common build/venv/cache dirs (e.g. node_modules, .git, build, dist)"
    echo
    echo "Usage: $0 [--files-only|--quiet|-q] <query>"
    exit 1
fi

# Set up variables
QUERY=$1

if [ "$FILES_ONLY" -ne 1 ]; then
    echo
    echo "Searching for filenames containing '$QUERY'..."
    echo
fi
# Set up exclude directories
EXCLUDE_DIRS=".venv venv .git .ruff_cache .svelte-kit __pycache__ .mypy_cache node_modules build dist .wrangler"

# Build exclude pattern for find command
build_exclude_pattern() {
    local dirs="$1"
    local pattern=""
    for dir in $dirs; do
        pattern+="-path '*/$dir/*' -o -path '*/$dir' -o "
    done
    # Remove the trailing " -o " and wrap the entire pattern in parentheses
    pattern="( ${pattern% -o } ) -prune -o"
    echo "$pattern"
}

# Execute search for filenames
exclude_pattern=$(build_exclude_pattern "$EXCLUDE_DIRS")
# Suppress permission denied errors by redirecting stderr to /dev/null
find "$BASE_DIR" $exclude_pattern -type f -iname "*$QUERY*" 2>/dev/null
