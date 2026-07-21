#!/bin/bash

set -euo pipefail

PLUGIN_NAME="Stylelint"
echo
echo "Running Plugin $PLUGIN_NAME..."

# Pre-flight guardrail: check if npm is available
if ! command -v npm >/dev/null 2>&1; then
    if [ "${CI:-false}" = "true" ]; then
        echo "❌ [Error] 'npm' is not installed in CI environment."
        exit 1
    else
        echo "⚠️  [Warning] 'npm' is not installed. Skipping $PLUGIN_NAME."
        exit 0
    fi
fi

# Run Stylelint directly on target paths in strict-blocking mode
npx stylelint "web/static/css/**/*.css"
