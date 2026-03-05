#!/bin/bash

# _env_loader.sh
#
# Helper script to load environment variables from a local .env file.
# This enables scripts to run in environments where .zshrc is not sourced.
#
# Usage: source this script at the beginning of your shell scripts:
#   source "$(dirname "$0")/_env_loader.sh"

# Determine the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to the .env file
ENV_FILE="$SCRIPT_DIR/.env"

# Check if .env file exists and source it
if [ -f "$ENV_FILE" ]; then
    # Export all variables from .env file
    set -a
    source "$ENV_FILE"
    set +a
else
    # Silently continue if .env doesn't exist (fallback to system env vars)
    :
fi
