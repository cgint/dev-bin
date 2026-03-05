#!/bin/bash
# browsershot.sh
#
# A simple wrapper for agent-browser to take a screenshot of a URL.
# Automates the process of setting viewport, navigating, and capturing.
#
# Usage:
#   browsershot.sh [--full|-f] [WIDTH HEIGHT] <url> [output_file]
#
# Examples:
#   browsershot.sh https://google.com
#   browsershot.sh https://google.com google.png
#   browsershot.sh 1440 900 https://google.com
#   browsershot.sh --full https://google.com full-page.png
#   browsershot.sh -f 1920 1080 https://google.com desktop.png
#
# Note: Defaults to 1024x768 viewport. --full captures entire page.

set -e

WIDTH=1024
HEIGHT=768
FULL=""

show_help() {
    sed -n '3,24p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

if [[ -z "$1" || "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

# Parse --full/-f
while [[ "$1" == "--full" || "$1" == "-f" ]]; do
    FULL="--full"
    shift
done

# If first two args are numbers, treat as resolution
if [[ "$1" =~ ^[0-9]+$ && -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
    WIDTH="$1"
    HEIGHT="$2"
    shift 2
fi

URL="$1"
OUTPUT="$2"

# Ensure URL has protocol
if [[ ! "$URL" =~ ^https?:// ]]; then
    URL="https://$URL"
fi

# Generate filename if not provided
if [ -z "$OUTPUT" ]; then
    # Create a safe filename from URL
    # Remove protocol
    SAFE_NAME=$(echo "$URL" | sed 's|https\{0,1\}://||')
    # Replace non-alphanumeric with dash
    SAFE_NAME=$(echo "$SAFE_NAME" | sed 's/[^a-zA-Z0-9]/./g')
    # Remove trailing/leading dots
    SAFE_NAME=$(echo "$SAFE_NAME" | sed 's/^\.*//;s/\.*$//')
    # Add timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    OUTPUT="${SAFE_NAME}_${TIMESTAMP}.png"
fi

# Ensure extension
if [[ ! "$OUTPUT" =~ \.png$ ]]; then
    OUTPUT="${OUTPUT}.png"
fi

echo "Browsing $URL..."
echo "Target: $OUTPUT"

# Execute agent-browser commands
# We set the viewport first to ensure consistent rendering
agent-browser set viewport "$WIDTH" "$HEIGHT"
agent-browser open "$URL"
agent-browser screenshot $FULL "$OUTPUT"

echo "Screenshot saved to $OUTPUT"
