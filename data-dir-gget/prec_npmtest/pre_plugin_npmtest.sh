#!/bin/bash

set -euo pipefail

PLUGIN_NAME="NPMTest"

# Check if package.json contains playwright/test
if grep -q "playwright/test" package.json; then
  echo "Playwright test dependency detected in package.json"
  
  # Check if playwright is installed
  if ! npx playwright --version &>/dev/null; then
    echo "Installing Playwright..."
    npx playwright install --with-deps
  else
    echo "Playwright is already installed"
  fi
fi

echo
echo "Running Plugin $PLUGIN_NAME ..."
echo
npm run test
npm_status=$? # Capture the exit status

# Optional: Add logging based on status
if [ $npm_status -ne 0 ]; then
  echo "Plugin $PLUGIN_NAME failed with status $npm_status" >&2
fi

exit $npm_status # Exit with the actual status of the npm command
