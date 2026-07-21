#!/bin/bash

set -euo pipefail

PLUGIN_NAME="Gitleaks"
echo
echo "Running Plugin $PLUGIN_NAME..."

GITLEAKS_IMAGE="ghcr.io/gitleaks/gitleaks:latest"

docker run --rm \
    -v "$PWD:/repo" \
    "$GITLEAKS_IMAGE" \
    git --report-format json --report-path /repo/.scan-results/gitleaks.json /repo 2>&1

gitleaks_status=$?

if [ $gitleaks_status -ne 0 ]; then
    echo "Plugin $PLUGIN_NAME failed with status $gitleaks_status" >&2
fi

exit $gitleaks_status
