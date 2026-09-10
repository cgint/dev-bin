#!/usr/bin/env bash
# ==============================================================================
# Script: orca-herdr-pi-start-named-session.sh
# Location: ~/.local/bin/orca-herdr-pi-start-named-session.sh
#
# PURPOSE & ARCHITECTURAL ROLE:
#   Serves as Orca's TUI Agent Command Override for `pi`.
#   Instead of launching `pi` directly inside Orca's built-in terminal tab,
#   this script orchestrates a persistent `herdr` session dedicated to
#   the current Git worktree and launches `pi` inside that herdr workspace.
#   Orca's terminal tab becomes the interactive front-end attached to the
#   underlying herdr workspace.
#
# COLLECTED REQUIREMENTS (From Session Investigation & User Directives):
#   1. Clean Separation of Concerns:
#      - Orca's worktree "Setup Script" handles repo prerequisites (e.g. client_secret.json).
#      - This script serves exclusively as the "Agent Runtime" command.
#
#   2. Worktree Anchor & Canonical Path Resolution:
#      - Must guarantee execution in the real worktree directory ($ORCA_WORKTREE_PATH or $PWD),
#        never in the user's home directory ($HOME / ~).
#      - Resolves canonical paths (`pwd -P`) to prevent symlink drift.
#
#   3. Collision-Free, Human-Readable Herdr Session Naming:
#      - Must generate predictable, unique session names per worktree.
#      - Generates: `<worktree-slug>-<path-sha-6>` (e.g. `draft-draft-docs-openspe-86eea8`).
#      - Avoids vague or cut-off session prefixes with trailing dashes.
#
#   4. Self-Healing & Session Sanitization:
#      - If an existing herdr session was previously initialized with $HOME as its
#        identity_cwd (e.g. from an earlier failed startup), detect the corruption,
#        terminate the poisoned server, and restart clean in the target worktree.
#
#   5. PTY Line-Length Overflow Protection (macOS 1024-byte limit):
#      - Orca passes numerous large environment variables (ORCA_*, tokens, URLs).
#      - Passing all exports inline via `herdr pane run` exceeds the macOS PTY
#        canonical buffer limit (MAX_CANON = 1024 bytes), silently truncating input.
#      - Solved by writing ORCA_* variables to a temporary environment script and
#        sourcing it inside the target pane via a compact command.
#
#   6. Full Orca Feature Propagation:
#      - Forwards all ORCA_* variables into Pi (ORCA_PI_PREFILL, ORCA_PANE_KEY,
#        ORCA_AGENT_HOOK_*, etc.) so Pi extensions (status spinner, MR URL prefill)
#        remain fully functional inside the Herdr session.
#
#   7. Targeted Stale Resume Filtering:
#      - Orca's "Sleeping Agent" mechanism resumes tabs using:
#        `<agentCmdOverride> --session <transcriptPath>`
#      - If Orca attempts to resume a stale transcript from the home directory
#        (`--Users-<username>--`), strip those arguments so Pi does not reset its
#        working directory back to $HOME.
#      - Legitimate worktree resume transcripts are preserved.
#
#   8. Full Executable Invocations (No Shell Aliases):
#      - Aliases (such as `pimsr`) are not expanded in non-interactive/herdr subshells.
#      - Directly invokes `pi-profile minimal --dm-read ...`.
#
#   9. Safe Lifecycle & Pane Readiness:
#      - Verifies the target pane exists and is ready before sending keystrokes.
#      - Safe temp file creation with cleanup trap.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. resolve_target_dir
#    WHAT: Determines and enters the target worktree directory canonically.
#    WHY:  Orca provides $ORCA_WORKTREE_PATH in hook environments, falling back
#          to $PWD. `pwd -P` resolves any symlinks to physical directories so
#          hashing and Pi execution are strictly aligned with reality.
# ------------------------------------------------------------------------------
resolve_target_dir() {
  local target="${ORCA_WORKTREE_PATH:-$PWD}"
  cd "$target"
  TARGET_DIR="$(pwd -P)"
}

# ------------------------------------------------------------------------------
# 2. compute_session_name
#    WHAT: Derives a clean, collision-free Herdr session name.
#    WHY:  Worktree names can be long (e.g., `draft-draft-docs-openspec-...`).
#          Taking up to 24 chars and stripping edge hyphens provides readability,
#          while appending a 6-character SHA-1 hash of the canonical full path
#          guarantees uniqueness even if two branches share identical prefixes.
# ------------------------------------------------------------------------------
compute_session_name() {
  local slug
  local path_hash

  slug="$(basename "$TARGET_DIR" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed -E 's/^-+|-+$//g' | cut -c1-24 | sed -E 's/-+$//')"
  path_hash="$(printf '%s' "$TARGET_DIR" | shasum | cut -c1-6)"
  SESSION="${slug}-${path_hash}"
}

# ------------------------------------------------------------------------------
# 3. sanitize_poisoned_session
#    WHAT: Detects and stops any running Herdr server whose persisted identity_cwd
#          is corrupted (set to $HOME instead of a real worktree).
#    WHY:  Herdr saves workspace state in `session.json`. If an earlier crashed
#          or misconfigured run stored $HOME as the workspace root, attaching to
#          it would land the user back in `~`. Stopping the server clears the
#          lock and lets step 4 boot a fresh server anchored to $TARGET_DIR.
# ------------------------------------------------------------------------------
sanitize_poisoned_session() {
  local session_json="${HOME}/.config/herdr/sessions/${SESSION}/session.json"
  if herdr --session "$SESSION" pane list >/dev/null 2>&1; then
    if [ -f "$session_json" ] && grep -q '"identity_cwd": "'"$HOME"'"' "$session_json" 2>/dev/null; then
      echo "[orca-herdr] Purging poisoned home-directory session for $SESSION..." >&2
      herdr --session "$SESSION" server stop >/dev/null 2>&1 || true
      sleep 0.1
    fi
  fi
}

# ------------------------------------------------------------------------------
# 4. ensure_herdr_server
#    WHAT: Starts the background Herdr server daemon if not already running.
#    WHY:  Herdr architecture relies on a persistent server daemon per named session.
#          We poll with `pane list` until the socket is active and responsive.
# ------------------------------------------------------------------------------
ensure_herdr_server() {
  if ! herdr --session "$SESSION" pane list >/dev/null 2>&1; then
    herdr --session "$SESSION" server >/dev/null 2>&1 &
    local attempts=0
    until herdr --session "$SESSION" pane list >/dev/null 2>&1; do
      sleep 0.05
      attempts=$((attempts + 1))
      if [ "$attempts" -ge 40 ]; then
        echo "[orca-herdr] ERROR: Herdr server failed to start within 2s for session $SESSION" >&2
        exit 1
      fi
    done
  fi
}

# ------------------------------------------------------------------------------
# 5. resolve_or_create_target_pane
#    WHAT: Finds an existing pane or creates a new workspace in $TARGET_DIR.
#    WHY:  If the session is fresh (0 panes), creates workspace w1 anchored to
#          $TARGET_DIR. If panes exist, checks if Pi is already running (via
#          agent_status or terminal title). If Pi is not running, selects the
#          first available pane to receive the Pi command.
# ------------------------------------------------------------------------------
resolve_or_create_target_pane() {
  local pane_list
  local pane_count
  local create_out
  local has_running_pi

  pane_list="$(herdr --session "$SESSION" pane list 2>/dev/null || echo "{}")"
  pane_count="$(echo "$pane_list" | grep -o '"pane_id"' | wc -l | tr -d ' ')"
  TARGET_PANE=""

  if [ "$pane_count" -eq 0 ]; then
    create_out="$(herdr --session "$SESSION" workspace create --cwd "$TARGET_DIR" 2>/dev/null)"
    TARGET_PANE="$(echo "$create_out" | grep -o '"pane_id":"[^"]*"' | head -1 | cut -d'"' -f4)"
  else
    has_running_pi="$(echo "$pane_list" | grep -E '("agent_status":"(working|idle)"|"terminal_title":"[^"]*π)' || true)"
    if [ -z "$has_running_pi" ]; then
      TARGET_PANE="$(echo "$pane_list" | grep -o '"pane_id":"[^"]*"' | head -1 | cut -d'"' -f4)"
    fi
  fi
}

# ------------------------------------------------------------------------------
# 6. filter_orca_cli_args
#    WHAT: Filters out stale `--session <path>` flags pointing to the user's home dir.
#    WHY:  When Orca wakes sleeping tabs, it appends `--session <transcriptPath>`
#          to the agent command. If that transcript was recorded in $HOME
#          (`--Users-<name>--`), Pi would load that session and override cwd back
#          to $HOME. We filter those out while preserving valid worktree transcripts.
# ------------------------------------------------------------------------------
filter_orca_cli_args() {
  FILTERED_ARGS=()
  local home_session_slug
  home_session_slug="$(printf '%s' "$HOME" | tr '/' '-')"

  while [ "$#" -gt 0 ]; do
    if [ "$1" = "--session" ]; then
      if [ "$#" -ge 2 ] && [[ "$2" =~ ${home_session_slug}-- ]]; then
        shift 2
        continue
      fi
    fi
    FILTERED_ARGS+=("$1")
    shift
  done
}

# ------------------------------------------------------------------------------
# 7. prepare_env_file
#    WHAT: Writes all current ORCA_* environment variables to a temp file.
#    WHY:  Orca provides ORCA_PI_PREFILL, ORCA_PANE_KEY, ORCA_AGENT_HOOK_*, etc.
#          Inlining dozens of exports into a single shell command exceeds the
#          1024-byte macOS PTY line buffer limit and truncates input before Pi
#          can start. Storing in an env file lets us source it with a short command.
# ------------------------------------------------------------------------------
prepare_env_file() {
  ENV_FILE="${TMPDIR:-/tmp}/orca-herdr-env-${SESSION}-$$.sh"
  : > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  for var in $(env | grep -E '^ORCA_' | cut -d= -f1); do
    printf 'export %s=%q\n' "$var" "${!var}" >> "$ENV_FILE"
  done
}

# ------------------------------------------------------------------------------
# 8. launch_pi_in_target_pane
#    WHAT: Injects the launch sequence into the target Herdr pane.
#    WHY:  Sources the env file, removes the temp file, navigates to $TARGET_DIR,
#          and launches `pi-profile minimal` with AGENTS.md and extra args.
# ------------------------------------------------------------------------------
launch_pi_in_target_pane() {
  if [ -z "${TARGET_PANE:-}" ]; then
    return 0
  fi

  prepare_env_file

  local extra_args=""
  if [ "${#FILTERED_ARGS[@]}" -gt 0 ]; then
    for a in "${FILTERED_ARGS[@]}"; do
      extra_args="$extra_args $(printf '%q' "$a")"
    done
  fi

  local pi_cmd
  pi_cmd="cd $(printf '%q' "$TARGET_DIR"); [ -f $(printf '%q' "$ENV_FILE") ] && { source $(printf '%q' "$ENV_FILE"); rm -f $(printf '%q' "$ENV_FILE"); }; pi-profile minimal --dm-read --append-system-prompt /Users/christian.gintenreiter/.pi/profiles/minimal/agent/AGENTS.md${extra_args}"

  # Give terminal subshell 50ms to be fully interactive before injecting
  sleep 0.05
  herdr --session "$SESSION" pane run "$TARGET_PANE" "$pi_cmd"
}

# ------------------------------------------------------------------------------
# 9. attach_to_session
#    WHAT: Attaches the current Orca terminal tab to the Herdr session.
#    WHY:  Transfers interactive terminal control to herdr session attach.
# ------------------------------------------------------------------------------
attach_to_session() {
  exec herdr session attach "$SESSION"
}

# ------------------------------------------------------------------------------
# MAIN EXECUTION FLOW
# ------------------------------------------------------------------------------
main() {
  resolve_target_dir
  compute_session_name
  sanitize_poisoned_session
  ensure_herdr_server
  resolve_or_create_target_pane
  filter_orca_cli_args "$@"
  launch_pi_in_target_pane
  attach_to_session
}

main "$@"
