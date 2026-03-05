#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
TOOLS_AGENTS_FILE="$SCRIPT_DIR/TOOLS_AGENTS.txt"

if [ ! -f "$TOOLS_AGENTS_FILE" ]; then
    echo "TOOLS_AGENTS.txt file not found"
    exit 1
fi

cat "$TOOLS_AGENTS_FILE"