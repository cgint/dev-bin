#!/bin/bash

set -euo pipefail

# Check if eslint is installed globally
if ! (npm list -g --depth=0 | grep -q "eslint" > /dev/null); then
    echo
    echo "Installing 'eslint' globally"
    echo
    npm install -g eslint
fi

# Check if eslint-plugin-unused-imports is installed locally
if ! (npm list --depth=0 | grep -q "eslint-plugin-unused-imports" > /dev/null 2>&1); then
    echo
    echo "Installing 'eslint-plugin-unused-imports' locally"
    echo
    npm install eslint-plugin-unused-imports
fi

PLUGIN_NAME="ESLint"
echo
FILE_FILTER_COMMAND="find ./ -maxdepth 1 -name '*.js'"
FILE_FILTER_FILES=$(eval "$FILE_FILTER_COMMAND")
FILE_FILTER_FILE_COUNT=$(wc -l <<< "$FILE_FILTER_FILES" | awk '{print $1}')
echo "Running Plugin $PLUGIN_NAME on $FILE_FILTER_FILE_COUNT files ..."
echo
if [ -n "$FILE_FILTER_FILES" ]; then
    eslint --fix $FILE_FILTER_FILES
    ESLINT_STATUS=$?
    if [ $ESLINT_STATUS -ne 0 ]; then
        echo "$PLUGIN_NAME check failed."
        exit 1
    fi
else
    echo "No files to lint with $PLUGIN_NAME."
fi

exit 0
