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
CLOSE_WAIT_SECONDS=5
FORCE_WAIT_SECONDS=3
POLL_INTERVAL_SECONDS=1
FINAL_SETTLE_SECONDS=2

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

collect_descendant_pids() {
  local root_pid="$1"
  local frontier="$root_pid"
  local seen=""
  local next_frontier=""
  local parent_pid
  local children
  local child_pid

  while [ -n "$frontier" ]; do
    next_frontier=""
    for parent_pid in $frontier; do
      children="$(pgrep -P "$parent_pid" 2>/dev/null || true)"
      for child_pid in $children; do
        case " $seen " in
          *" $child_pid "*) ;;
          *)
            seen="${seen:+$seen }$child_pid"
            next_frontier="${next_frontier:+$next_frontier }$child_pid"
            ;;
        esac
      done
    done
    frontier="$next_frontier"
  done

  if [ -n "$seen" ]; then
    printf '%s\n' $seen
  fi
}

extract_user_data_dir_from_command() {
  local command_line="$1"

  if [[ "$command_line" =~ --user-data-dir=([^[:space:]]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

get_session_user_data_dir() {
  local daemon_pid="$1"
  local process_pid
  local command_line
  local user_data_dir

  for process_pid in "$daemon_pid" $(collect_descendant_pids "$daemon_pid"); do
    [ -n "$process_pid" ] || continue
    command_line="$(ps -p "$process_pid" -o command= 2>/dev/null | awk '{$1=$1; print}' || true)"
    [ -n "$command_line" ] || continue
    user_data_dir="$(extract_user_data_dir_from_command "$command_line")"
    if [ -n "$user_data_dir" ]; then
      echo "$user_data_dir"
      return 0
    fi
  done

  return 1
}

list_processes_with_user_data_dir() {
  local user_data_dir="$1"
  local needle="--user-data-dir=${user_data_dir}"

  ps -axo pid=,command= | awk -v needle="$needle" '
    index($0, needle) {
      print $1
    }
  '
}

count_processes_with_user_data_dir() {
  local user_data_dir="$1"
  local matches

  matches="$(list_processes_with_user_data_dir "$user_data_dir" || true)"
  if [ -z "$matches" ]; then
    echo 0
  else
    printf '%s\n' "$matches" | wc -l | tr -d '[:space:]'
  fi
}

merge_pid_lists() {
  local merged=""
  local pid_list
  local pid

  for pid_list in "$@"; do
    for pid in $pid_list; do
      [ -n "$pid" ] || continue
      case " $merged " in
        *" $pid "*) ;;
        *) merged="${merged:+$merged }$pid" ;;
      esac
    done
  done

  echo "$merged"
}

alive_pids_from_list() {
  local pid_list="$1"
  local alive=""
  local pid

  for pid in $pid_list; do
    [ -n "$pid" ] || continue
    if ps -p "$pid" >/dev/null 2>&1; then
      alive="${alive:+$alive }$pid"
    fi
  done

  echo "$alive"
}

count_alive_pids_from_list() {
  local pid_list="$1"
  local alive

  alive="$(alive_pids_from_list "$pid_list")"
  if [ -z "$alive" ]; then
    echo 0
  else
    printf '%s\n' $alive | wc -l | tr -d '[:space:]'
  fi
}

count_session_browser_processes() {
  local daemon_pid="$1"
  local user_data_dir="${2:-}"
  local matches

  if [ -n "$user_data_dir" ]; then
    count_processes_with_user_data_dir "$user_data_dir"
    return 0
  fi

  matches="$(collect_descendant_pids "$daemon_pid" | while read -r child_pid; do
    [ -n "$child_pid" ] || continue
    ps -p "$child_pid" -o command= 2>/dev/null || true
  done | awk '
    /Google Chrome for Testing/ || /chrome-headless-shell/ {
      count += 1
    }
    END {
      print count + 0
    }
  ')"
  echo "${matches:-0}"
}

wait_for_session_shutdown() {
  local daemon_pid="$1"
  local known_related_pids="${2:-}"
  local user_data_dir="${3:-}"
  local timeout_seconds="$4"
  local elapsed=0
  local browser_process_count=0
  local known_alive_count=0

  while [ "$elapsed" -lt "$timeout_seconds" ]; do
    browser_process_count=0
    known_alive_count=0
    if [ -n "$user_data_dir" ]; then
      browser_process_count="$(count_processes_with_user_data_dir "$user_data_dir")"
    fi
    if [ -n "$known_related_pids" ]; then
      known_alive_count="$(count_alive_pids_from_list "$known_related_pids")"
    fi

    if ! ps -p "$daemon_pid" >/dev/null 2>&1 && [ "$known_alive_count" -eq 0 ] && [ "$browser_process_count" -eq 0 ]; then
      return 0
    fi

    sleep "$POLL_INTERVAL_SECONDS"
    elapsed=$((elapsed + POLL_INTERVAL_SECONDS))
  done

  browser_process_count=0
  known_alive_count=0
  if [ -n "$user_data_dir" ]; then
    browser_process_count="$(count_processes_with_user_data_dir "$user_data_dir")"
  fi
  if [ -n "$known_related_pids" ]; then
    known_alive_count="$(count_alive_pids_from_list "$known_related_pids")"
  fi

  if ! ps -p "$daemon_pid" >/dev/null 2>&1 && [ "$known_alive_count" -eq 0 ] && [ "$browser_process_count" -eq 0 ]; then
    return 0
  fi

  return 1
}

signal_process_list() {
  local signal_name="$1"
  local pid_list="$2"
  local pid

  for pid in $pid_list; do
    [ -n "$pid" ] || continue
    if [ -n "${AGENT_BROWSER_CLEANUP_KILL_HELPER:-}" ]; then
      if [ "$signal_name" = "KILL" ]; then
        "$AGENT_BROWSER_CLEANUP_KILL_HELPER" -9 "$pid" >/dev/null 2>&1 || true
      else
        "$AGENT_BROWSER_CLEANUP_KILL_HELPER" "$pid" >/dev/null 2>&1 || true
      fi
    elif [ "$signal_name" = "KILL" ]; then
      kill -9 "$pid" >/dev/null 2>&1 || true
    else
      kill "$pid" >/dev/null 2>&1 || true
    fi
  done
}

is_agent_browser_daemon_command() {
  local command_line="$1"

  if [[ "$command_line" == *"agent-browser"*"daemon.js"* ]]; then
    return 0
  fi

  if [[ "$command_line" == *"/agent-browser/bin/agent-browser-"* ]]; then
    return 0
  fi

  return 1
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

  if ! is_agent_browser_daemon_command "$command_line"; then
    log "SKIP  $session_name: pid $pid is not an agent-browser daemon"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  if [ "$age_seconds" -lt "$threshold_seconds" ]; then
    vlog "SKIP  $session_name: age ${age_minutes}m < threshold"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  session_user_data_dir="$(get_session_user_data_dir "$pid" || true)"
  session_descendant_pids="$(collect_descendant_pids "$pid" | tr '\n' ' ' | awk '{$1=$1; print}')"
  chrome_children="$(count_session_browser_processes "$pid" "$session_user_data_dir")"
  log "CLOSE $session_name: pid=$pid age=${age_minutes}m browser-processes=${chrome_children}"
  [ -n "$session_user_data_dir" ] && vlog "INFO  $session_name: user-data-dir=${session_user_data_dir}"

  if [ "$DRY_RUN" = true ]; then
    continue
  fi

  if agent-browser --session "$session_name" close >/dev/null 2>&1; then
    sleep "$SLEEP_AFTER_CLOSE"
  else
    log "WARN  $session_name: agent-browser close returned non-zero"
  fi

  if ! wait_for_session_shutdown "$pid" "$session_descendant_pids" "$session_user_data_dir" "$CLOSE_WAIT_SECONDS"; then
    if [ "$FORCE_KILL" = true ]; then
      if ps -p "$pid" >/dev/null 2>&1; then
        log "TERM  $session_name: sending SIGTERM to daemon pid $pid"
        signal_process_list "TERM" "$pid"
      fi

      related_pids=""
      if [ -n "$session_user_data_dir" ]; then
        related_pids="$(list_processes_with_user_data_dir "$session_user_data_dir" | tr '\n' ' ' | awk '{$1=$1; print}')"
      fi
      related_pids="$(merge_pid_lists "$session_descendant_pids" "$related_pids")"
      if [ -n "$related_pids" ]; then
        log "TERM  $session_name: sending SIGTERM to related browser pids ${related_pids}"
        signal_process_list "TERM" "$related_pids"
      fi

      if ! wait_for_session_shutdown "$pid" "$session_descendant_pids" "$session_user_data_dir" "$FORCE_WAIT_SECONDS"; then
        remaining_pids=""
        if ps -p "$pid" >/dev/null 2>&1; then
          remaining_pids="$pid"
        fi
        remaining_pids="$(merge_pid_lists "$remaining_pids" "$(alive_pids_from_list "$session_descendant_pids")")"
        if [ -n "$session_user_data_dir" ]; then
          marker_pids="$(list_processes_with_user_data_dir "$session_user_data_dir" | tr '\n' ' ' | awk '{$1=$1; print}')"
          if [ -n "$marker_pids" ]; then
            remaining_pids="$(merge_pid_lists "$remaining_pids" "$marker_pids")"
          fi
        fi

        if [ -n "$remaining_pids" ]; then
          log "KILL  $session_name: sending SIGKILL to remaining pids ${remaining_pids}"
          signal_process_list "KILL" "$remaining_pids"
          wait_for_session_shutdown "$pid" "$session_descendant_pids" "$session_user_data_dir" "$FORCE_WAIT_SECONDS" || true
        fi
      fi
    fi
  fi

  related_browser_count=0
  remaining_known_related_count=0
  if [ -n "$session_user_data_dir" ]; then
    related_browser_count="$(count_processes_with_user_data_dir "$session_user_data_dir")"
  fi
  if [ -n "$session_descendant_pids" ]; then
    remaining_known_related_count="$(count_alive_pids_from_list "$session_descendant_pids")"
  fi

  if ! ps -p "$pid" >/dev/null 2>&1 && [ "$remaining_known_related_count" -eq 0 ] && [ "$related_browser_count" -gt 0 ]; then
    sleep "$FINAL_SETTLE_SECONDS"
    related_browser_count=0
    remaining_known_related_count=0
    if [ -n "$session_user_data_dir" ]; then
      related_browser_count="$(count_processes_with_user_data_dir "$session_user_data_dir")"
    fi
    if [ -n "$session_descendant_pids" ]; then
      remaining_known_related_count="$(count_alive_pids_from_list "$session_descendant_pids")"
    fi
  fi

  if ps -p "$pid" >/dev/null 2>&1; then
    log "WARN  $session_name: pid $pid is still running"
  fi

  if [ "$remaining_known_related_count" -gt 0 ]; then
    log "WARN  $session_name: known related processes still running (${remaining_known_related_count})"
  fi

  if [ "$related_browser_count" -gt 0 ]; then
    log "WARN  $session_name: related browser processes still running (${related_browser_count})"
  fi

  if ! ps -p "$pid" >/dev/null 2>&1 && [ "$remaining_known_related_count" -eq 0 ] && [ "$related_browser_count" -eq 0 ]; then
    log "OK    $session_name closed"
    closed_count=$((closed_count + 1))
    if [ "$PRUNE_STALE_FILES" = true ]; then
      [ -e "$pid_file" ] && rm -f "$pid_file"
      [ -e "$sock_file" ] && rm -f "$sock_file"
    fi
  else
    failed_count=$((failed_count + 1))
  fi
done

if [ "$found_any" = false ]; then
  log "No agent-browser session pid files found in $SESSION_DIR"
  exit 0
fi

log
log "Summary: closed=$closed_count stale=$already_gone_count skipped=$skipped_count failed=$failed_count pruned=$stale_files_removed dry_run=$DRY_RUN"
