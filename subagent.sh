#!/usr/bin/env bash
# Launch an editable Pi subagent with the isolated partner profile.
set -euo pipefail

exec pi-profile partner -ne --thinking minimal "$@"
