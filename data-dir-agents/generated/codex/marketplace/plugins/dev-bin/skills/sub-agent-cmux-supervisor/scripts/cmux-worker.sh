#!/usr/bin/env bash
# CMUX-local worker launcher. Its runtime library is bundled beside this file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=pi-worker-runtime.sh
source "$SCRIPT_DIR/pi-worker-runtime.sh"

pi_worker_runtime_main '' "$@"
