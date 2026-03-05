#!/bin/bash

# Strict mode for better error handling
set -euo pipefail

# Configurable base directory with environment variable fallback
BASE_DIR=$HOME/dev

# Check if base directory exists
if [ ! -d "$BASE_DIR" ]; then
    echo "Error: Directory $BASE_DIR does not exist"
    exit 1
fi

# Show usage if no query provided
usage() {
    echo "Usage: $0 <query> [extension1] [extension2] ..."
    echo "Default extensions: ts py yaml yml toml json md rst"
    echo "Example: $0 'function name' py ts html"
    echo "Example: $0 search-term (uses default extensions)"
    exit 1
}

# Validate input
[ $# -eq 0 ] && usage

# Set up variables
QUERY=$1
shift  # Remove the query from arguments
DEFAULT_EXTENSIONS="ts js py yaml yml toml json md rst ex exs heex"
EXCLUDE_DIRS=".venv venv .git .ruff_cache .svelte-kit __pycache__ .mypy_cache node_modules build dist .wrangler"

# Use remaining arguments as extensions, or default if none provided
if [ $# -eq 0 ]; then
    EXTENSION_LIST="$DEFAULT_EXTENSIONS"
else
    EXTENSION_LIST="$*"
fi

# Main search function
search_files() {
    local query="$1"
    local base_dir="$2"
    local extensions="$3"
    local exclude_dirs="$4"

    local globs=()
    for ext in $extensions; do
        globs+=(--glob "*.$ext")
    done
    for dir in $exclude_dirs; do
        globs+=(--glob "!$dir/**")
    done

    echo "Searching for '$query' in extensions: $extensions ..."
    echo "Base Directory: $base_dir"

    rg -n -i --color=always "${globs[@]}" -- "$query" "$base_dir" || true
}

# Execute search
search_files "$QUERY" "$BASE_DIR" "$EXTENSION_LIST" "$EXCLUDE_DIRS"