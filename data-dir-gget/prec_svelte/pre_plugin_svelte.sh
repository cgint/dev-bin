#!/bin/bash

set -euo pipefail

# Run checks
echo "Running npm build and npm run check in parallel..."
npm run build & BUILD_PID=$!
npm run check & CHECK_PID=$!
npm install & INSTALL_PID=$!

# Wait for both processes to finish
wait $BUILD_PID
BUILD_STATUS=$?
wait $CHECK_PID
CHECK_STATUS=$?
wait $INSTALL_PID
INSTALL_STATUS=$?

# Check the exit status of npm build
if [ $BUILD_STATUS -ne 0 ]; then
    echo "npm build failed. Aborting."
    exit 1
fi

# Check the exit status of npm run check
if [ $CHECK_STATUS -ne 0 ]; then
    echo "npm run check failed. Aborting."
    exit 1
fi

if [ $INSTALL_STATUS -ne 0 ]; then
    echo "npm install failed. Aborting."
    exit 1
fi

echo "Pre-commit checks passed successfully."
exit 0
