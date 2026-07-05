#!/bin/bash

# Lizard pre-commit plugin
# ========================
# Runs the Lizard cyclomatic complexity analyzer (multi-language) as a pre-commit gate.
# https://github.com/terryyin/lizard
#
# Thresholds:
#   -C 15  : warn on CCN > 15 (lizard default)
#   -w     : warnings-only output (clang/gcc style)
#
# Exclusions (adjust per-project):
#   --exclude "./web/int/*"   : skip third-party / generated / minified files
#   --exclude "*.min.js"      : skip minified bundles
#   Lizard also honors .gitignore automatically.
#
# Forgiving specific functions (in-source):
#   Place "# lizard forgives(cyclomatic_complexity)" inside the function body
#   to exempt it from CCN warnings while keeping the threshold active for others.
#
# Usage: drop into a project alongside pre_plugin_*.sh; precommit.sh auto-discovers it.

set -euo pipefail

PLUGIN_NAME="Lizard"
echo
echo "Running Plugin $PLUGIN_NAME..."

uvx lizard \
  -w \
  -C 15 \
  --exclude "./web/int/*" \
  --exclude "*.min.js" \
  .

lizard_status=$?

if [ $lizard_status -ne 0 ]; then
    echo "Plugin $PLUGIN_NAME failed with status $lizard_status" >&2
fi

exit $lizard_status