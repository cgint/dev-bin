#!/bin/bash

set -euo pipefail

# Check if htmlhint is installed globally
if ! (npm list -g --depth=0 | grep -q "htmlhint" > /dev/null); then
    echo
    echo "Installing 'htmlhint' globally"
    echo
    npm install -g htmlhint
fi

PLUGIN_NAME="HTMLHint"
echo
FILE_FILTER_COMMAND="find ./web -type d -name external -prune -false -o -name '*.html'"
FILE_FILTER_FILES=$(eval "$FILE_FILTER_COMMAND")
FILE_FILTER_FILE_COUNT=$(wc -l <<< "$FILE_FILTER_FILES" | awk '{print $1}')
echo "Running Plugin $PLUGIN_NAME on $FILE_FILTER_FILE_COUNT files ..."
echo
if [ -n "$FILE_FILTER_FILES" ]; then
    NODE_NO_WARNINGS=1 htmlhint $FILE_FILTER_FILES
    HTMLHINT_STATUS=$?
    if [ $HTMLHINT_STATUS -ne 0 ]; then
        echo "$PLUGIN_NAME check failed."
        exit 1
    fi
else
    echo "No files to lint with $PLUGIN_NAME."
fi

exit 0
