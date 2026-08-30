#!/usr/bin/env bash
# Herdr-local worker launcher. Its runtime library is bundled beside this file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=pi-worker-runtime.sh
source "$SCRIPT_DIR/pi-worker-runtime.sh"

HERDR_REPORTER="$HOME/.pi/profiles/partner/agent/extensions/herdr-agent-state.ts"
pi_worker_runtime_main "$HERDR_REPORTER" "$@"
