#!/bin/bash

set -euo pipefail

PLUGIN_NAME="PyTest"
echo
echo "Running Plugin $PLUGIN_NAME ..."
echo
# The last run makes sure that the tests are run once without waiting for changes and auto-rerunning
uv run pytest -vv
pytest_status=$? # Capture the exit status

# Optional: Add logging based on status
if [ $pytest_status -ne 0 ]; then
  echo "Plugin $PLUGIN_NAME failed with status $pytest_status" >&2
fi

exit $pytest_status # Exit with the actual status of the pytest command