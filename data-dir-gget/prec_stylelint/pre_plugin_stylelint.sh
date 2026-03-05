#!/bin/bash

set -euo pipefail

# Check if stylelint and stylelint-config-standard are installed globally
if ! (npm list -g --depth=0 | grep -q "stylelint-config-standard" > /dev/null); then
    echo
    echo "Installing 'stylelint' and 'stylelint-config-standard' globally"
    echo
    npm install -g stylelint stylelint-config-standard
fi

PLUGIN_NAME="Stylelint"
echo
FILE_FILTER_FILES=$(find ./web -type d -name external -prune -false -o -name '*.css')
FILE_FILTER_FILE_COUNT=$(wc -l <<< "$FILE_FILTER_FILES" | awk '{print $1}')
echo "Running Plugin $PLUGIN_NAME on $FILE_FILTER_FILE_COUNT files ..."
echo
if [ -n "$FILE_FILTER_FILES" ]; then
    stylelint --fix $FILE_FILTER_FILES
    STYLELINT_STATUS=$?
    if [ $STYLELINT_STATUS -ne 0 ]; then
        echo "$PLUGIN_NAME check failed."
        exit 1
    fi
else
    echo "No files to lint with $PLUGIN_NAME."
fi

exit 0
