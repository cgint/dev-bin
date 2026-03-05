#!/bin/bash

# Consider removing set -e if you want to capture the status explicitly
# set -euo pipefail
set -uo pipefail # Keep pipefail and nounset

PLUGIN_NAME="NPMRunPrecommit"

echo
echo "Running Plugin $PLUGIN_NAME ..."
echo
npm run precommit
npm_status=$? # Capture the exit status

# Optional: Add logging based on status
if [ $npm_status -ne 0 ]; then
  echo "Plugin $PLUGIN_NAME failed with status $npm_status" >&2
fi

exit $npm_status # Exit with the actual status of the npm command
