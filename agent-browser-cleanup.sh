#!/bin/bash

set -euo pipefail

SESSION_DIR="${HOME}/.agent-browser"
MINUTES=60
DRY_RUN=false
INCLUDE_DEFAULT=false
PRUNE_STALE_FILES=false
FORCE_KILL=false
VERBOSE=false
SLEEP_AFTER_CLOSE=2

usage() {
  cat <<'EOF'
Usage: agent-browser-cleanup.sh [options]

Safely clean up stale agent-browser sessions and their headless Chromium children.

Default behavior:
- inspect ~/.agent-browser/*.pid
- close sessions whose daemon process age is >= 60 minutes
- skip the "default" session unless explicitly included
- do not force-kill processes unless requested
- do not remove stale pid/sock files unless requested

Options:
  --minutes <n>        Age threshold in minutes (default: 60)
  --dry-run            Show what would be closed, but make no changes
  --include-default    Include the "default" session in cleanup
  --prune-stale-files  Remove stale .pid/.sock files when the PID no longer exists
  --force-kill         If close does not stop the daemon, send SIGTERM to the daemon PID
  --verbose            Show extra details
  -h, --help           Show this help

Examples:
  agent-browser-cleanup.sh --dry-run
  agent-browser-cleanup.sh --minutes 60
  agent-browser-cleanup.sh --minutes 45 --prune-stale-files
  agent-browser-cleanup.sh --minutes 30 --force-kill
EOF
}

log() {
  echo "$*"
}

vlog() {
  if [ "$VERBOSE" = true ]; then
    echo "$*"
  fi
}

etime_to_seconds() {
  local etime="$1"
  local days=0
  local hours=0
  local minutes=0
  local seconds=0
  local rest

  if [[ "$etime" == *-* ]]; then
    days="${etime%%-*}"
    rest="${etime#*-}"
  else
    rest="$etime"
  fi

  IFS=':' read -r -a parts <<< "$rest"
  if [ "${#parts[@]}" -eq 3 ]; then
    hours="${parts[0]}"
    minutes="${parts[1]}"
    seconds="${parts[2]}"
  elif [ "${#parts[@]}" -eq 2 ]; then
    minutes="${parts[0]}"
    seconds="${parts[1]}"
  elif [ "${#parts[@]}" -eq 1 ]; then
    seconds="${parts[0]}"
  else
    return 1
  fi

  echo $((10#$days * 86400 + 10#$hours * 3600 + 10#$minutes * 60 + 10#$seconds))
}

count_child_processes() {
  local parent_pid="$1"
  local pattern="$2"
  local matches

  matches="$(pgrep -P "$parent_pid" -f "$pattern" 2>/dev/null || true)"
  if [ -z "$matches" ]; then
    echo 0
  else
    printf '%s\n' "$matches" | wc -l | tr -d '[:space:]'
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --minutes)
      MINUTES="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --include-default)
      INCLUDE_DEFAULT=true
      shift
      ;;
    --prune-stale-files)
      PRUNE_STALE_FILES=true
      shift
      ;;
    --force-kill)
      FORCE_KILL=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! [[ "$MINUTES" =~ ^[0-9]+$ ]]; then
  echo "--minutes must be a non-negative integer" >&2
  exit 2
fi

if [ ! -d "$SESSION_DIR" ]; then
  log "No agent-browser session dir found: $SESSION_DIR"
  exit 0
fi

if ! command -v agent-browser >/dev/null 2>&1; then
  echo "agent-browser is not installed or not on PATH" >&2
  exit 2
fi

threshold_seconds=$((MINUTES * 60))
found_any=false
closed_count=0
stale_files_removed=0
skipped_count=0
already_gone_count=0
failed_count=0

session_pid_files=("$SESSION_DIR"/*.pid)
if [ ! -e "${session_pid_files[0]}" ]; then
  log "No agent-browser session pid files found in $SESSION_DIR"
  exit 0
fi

log "Scanning agent-browser sessions older than ${MINUTES} minutes in $SESSION_DIR"

for pid_file in "${session_pid_files[@]}"; do
  [ -e "$pid_file" ] || continue
  found_any=true

  session_name="$(basename "$pid_file" .pid)"
  sock_file="$SESSION_DIR/${session_name}.sock"

  if [ "$session_name" = "default" ] && [ "$INCLUDE_DEFAULT" != true ]; then
    vlog "skip default session"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  pid_raw="$(tr -d '[:space:]' < "$pid_file" 2>/dev/null || true)"
  if ! [[ "$pid_raw" =~ ^[0-9]+$ ]]; then
    log "WARN  $session_name: invalid pid file content in $pid_file"
    failed_count=$((failed_count + 1))
    continue
  fi
  pid="$pid_raw"

  if ! ps -p "$pid" >/dev/null 2>&1; then
    log "STALE $session_name: pid $pid not running"
    already_gone_count=$((already_gone_count + 1))
    if [ "$PRUNE_STALE_FILES" = true ]; then
      if [ "$DRY_RUN" = true ]; then
        log "DRY   would remove $pid_file"
        [ -e "$sock_file" ] && log "DRY   would remove $sock_file"
      else
        rm -f "$pid_file"
        [ -e "$sock_file" ] && rm -f "$sock_file"
        stale_files_removed=$((stale_files_removed + 1))
        log "OK    removed stale files for $session_name"
      fi
    fi
    continue
  fi

  command_line="$(ps -p "$pid" -o command= | awk '{$1=$1; print}')"
  elapsed_raw="$(ps -p "$pid" -o etime= | tr -d '[:space:]')"
  if ! age_seconds="$(etime_to_seconds "$elapsed_raw")"; then
    log "WARN  $session_name: could not parse elapsed time '$elapsed_raw'"
    failed_count=$((failed_count + 1))
    continue
  fi
  age_minutes=$((age_seconds / 60))

  if [[ "$command_line" != *"agent-browser"*"daemon.js"* ]]; then
    log "SKIP  $session_name: pid $pid is not an agent-browser daemon"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  if [ "$age_seconds" -lt "$threshold_seconds" ]; then
    vlog "SKIP  $session_name: age ${age_minutes}m < threshold"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  chrome_children="$(count_child_processes "$pid" 'chrome-headless-shell')"
  log "CLOSE $session_name: pid=$pid age=${age_minutes}m chrome-children=${chrome_children}"

  if [ "$DRY_RUN" = true ]; then
    continue
  fi

  if agent-browser --session "$session_name" close >/dev/null 2>&1; then
    sleep "$SLEEP_AFTER_CLOSE"
  else
    log "WARN  $session_name: agent-browser close returned non-zero"
  fi

  if ps -p "$pid" >/dev/null 2>&1; then
    if [ "$FORCE_KILL" = true ]; then
      log "TERM  $session_name: close did not stop pid $pid, sending SIGTERM"
      kill "$pid" >/dev/null 2>&1 || true
      sleep 1
    fi
  fi

  if ps -p "$pid" >/dev/null 2>&1; then
    log "WARN  $session_name: pid $pid is still running"
    failed_count=$((failed_count + 1))
  else
    log "OK    $session_name closed"
    closed_count=$((closed_count + 1))
    if [ "$PRUNE_STALE_FILES" = true ]; then
      [ -e "$pid_file" ] && rm -f "$pid_file"
      [ -e "$sock_file" ] && rm -f "$sock_file"
    fi
  fi
done

if [ "$found_any" = false ]; then
  log "No agent-browser session pid files found in $SESSION_DIR"
  exit 0
fi

log
log "Summary: closed=$closed_count stale=$already_gone_count skipped=$skipped_count failed=$failed_count pruned=$stale_files_removed dry_run=$DRY_RUN"
