#!/bin/bash

set -euo pipefail

PLUGIN_NAME="Trivy"
echo
echo "Running Plugin $PLUGIN_NAME..."

TRIVY_IMAGE="aquasec/trivy:0.60.0"
TRIVY_CACHE_VOLUME="trivy-db-cache"

docker run --rm \
    -v "$PWD:/work" \
    -w /work \
    -v "$TRIVY_CACHE_VOLUME:/root/.cache/" \
    "$TRIVY_IMAGE" \
    fs \
    --scanners vuln \
    --severity HIGH,CRITICAL \
    --exit-code 1 \
    --format json \
    --output /work/.scan-results/trivy.json \
    . 2>&1

trivy_status=$?

if [ $trivy_status -ne 0 ]; then
    echo "Plugin $PLUGIN_NAME failed with status $trivy_status" >&2
fi

exit $trivy_status
