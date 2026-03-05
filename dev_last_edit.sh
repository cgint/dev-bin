#!/bin/bash
set -euo pipefail

# =============================================================================
# dev_last_edit.sh - List recently modified files with optional filters
#
# Usage:
#   ./dev_last_edit.sh [OPTIONS]
#
# Options:
#   -d DIR        Base directory to search (default: current directory)
#   -e EXT        Comma-separated file extensions (e.g., py,js,ts)
#   -t DATE       Date filter string (e.g., 2026-01-10, 2026-01)
#   -n NUM        Maximum number of results (default: 40)
#   --today       Filter to files modified today
#   --yesterday   Filter to files modified yesterday
#   -h, --help    Show this help message
#
# Environment variables:
#   BASE_DIR      Default base directory
#   MAX_RESULTS   Default max results (default: 40)
#   DATE_FILTER   Default date filter pattern
#
# Example output:
#   LAST_MODIFIED        FILE_PATH
#   -------------------  ---------
#   2026-01-10 12:34:07 bench_agents/online_replay_agent.py
#   2026-01-10 12:33:04 online_replay_loop.py
# =============================================================================

show_help() {
  sed -n '3,28p' "$0" | sed 's/^# //' | sed 's/^#//'
  exit 0
}

# -----------------------------------------------------------------------------
# 1. Parse command-line arguments
# -----------------------------------------------------------------------------

# Show help if no arguments provided
[[ $# -eq 0 ]] && show_help

DATE_SHORTCUT=""
BASE_DIR_ARG=""
EXTENSIONS_ARG=""
DATE_ARG=""
MAX_RESULTS_ARG=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -d)
      [[ -z "${2:-}" ]] && { echo "Error: -d requires a directory argument" >&2; exit 1; }
      BASE_DIR_ARG="$2"; shift 2 ;;
    -e)
      [[ -z "${2:-}" ]] && { echo "Error: -e requires an extensions argument" >&2; exit 1; }
      EXTENSIONS_ARG="$2"; shift 2 ;;
    -t)
      [[ -z "${2:-}" ]] && { echo "Error: -t requires a date argument" >&2; exit 1; }
      DATE_ARG="$2"; shift 2 ;;
    -n)
      [[ -z "${2:-}" ]] && { echo "Error: -n requires a number argument" >&2; exit 1; }
      MAX_RESULTS_ARG="$2"; shift 2 ;;
    --today)     DATE_SHORTCUT="today";     shift ;;
    --yesterday) DATE_SHORTCUT="yesterday"; shift ;;
    -h|--help)   show_help ;;
    *)           echo "Unknown option: $1" >&2; echo "Use -h for help" >&2; exit 1 ;;
  esac
done

# -----------------------------------------------------------------------------
# 2. Build configuration (args > env vars > defaults)
# -----------------------------------------------------------------------------
BASE_DIR="${BASE_DIR_ARG:-${BASE_DIR:-.}}"
MAX_RESULTS="${MAX_RESULTS_ARG:-${MAX_RESULTS:-40}}"

# Build ripgrep arguments for file type filtering
RG_ARGS=("--files" "--null")
if [ -n "${EXTENSIONS_ARG}" ]; then
  # Convert comma-separated extensions to ripgrep glob: py,js,ts -> *.{py,js,ts}
  RG_ARGS+=("-g" "*.{${EXTENSIONS_ARG}}")
fi
RG_ARGS+=("${BASE_DIR}")

# Build date filter (shortcuts take precedence over -t and env var)
if [ "${DATE_SHORTCUT}" = "today" ]; then
  DATE_FILTER="$(date +"%Y-%m-%d")"
elif [ "${DATE_SHORTCUT}" = "yesterday" ]; then
  DATE_FILTER="$(date -v-1d +"%Y-%m-%d")"
elif [ -n "${DATE_ARG}" ]; then
  DATE_FILTER="${DATE_ARG}"
else
  DATE_FILTER="${DATE_FILTER:-}"
fi

if [ -n "${DATE_FILTER}" ]; then
  DATE_FILTER_CMD="grep '${DATE_FILTER}' || true"
else
  DATE_FILTER_CMD="cat"
fi

# -----------------------------------------------------------------------------
# 3. Execute pipeline
# -----------------------------------------------------------------------------
set +o pipefail
rg "${RG_ARGS[@]}" \
  | xargs -0 stat -f "%Sm %N" -t "%Y-%m-%d %H:%M:%S" \
  | sort -r \
  | eval "${DATE_FILTER_CMD}" \
  | head -n "${MAX_RESULTS}" \
  | awk 'BEGIN {
      print ""
      print "The top '${MAX_RESULTS}' files are:"
      print ""
      print "LAST_MODIFIED        FILE_PATH"
      print "-------------------  ---------"
    }
    { print $0 }'
set -o pipefail
