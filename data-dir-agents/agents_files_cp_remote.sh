#!/usr/bin/env bash
#
# agents_files_cp_remote.sh — Deploy pi-agent profile bundles to remote homelab hosts.
#
# Sibling to agents_files_cp.sh (local, apply-by-default).
# This script ships the generated bundle to remote hosts via rsync-over-ssh
# with post-sync md5 verification.
#
# Usage:
#   agents_files_cp_remote.sh [--apply] [--delete] [--host HOST] [-h]
#
#   (no flags)      dry-run all hosts in definitions/hosts/
#   --apply         actually transfer files (default is dry-run)
#   --delete        enable rsync --delete for ALL hosts (removes host files
#                   not in bundle — DANGEROUS)
#   --host HOST     restrict to a single host
#
# Per-host config: definitions/hosts/<name>.toml
#   host     = "sparky"
#   profile  = "default"
#   delete   = false
#   ssh_opts = ["-o", "ConnectTimeout=5", "-o", "BatchMode=yes"]
#   # target_dir is NOT set here: it is derived from
#   # generated/pi-agent-profiles/<profile>/.target (single source of truth).
#   # Optional explicit override: target_dir = "~/.pi/agent"
#
# Exit codes:
#   0  all attempted hosts OK (ssh-unreachable hosts are [SKIP], non-fatal)
#   1  at least one host had a transfer or verification failure
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTS_DIR="$SCRIPT_DIR/definitions/hosts"
GENERATED_DIR="$SCRIPT_DIR/generated"
PI_PROFILES_DIR="$GENERATED_DIR/pi-agent-profiles"

APPLY=false
CLI_DELETE=false
HOST_FILTER=""

usage() {
  cat <<'EOF'
Usage: agents_files_cp_remote.sh [--apply] [--delete] [--host HOST] [-h]

Deploy pi-agent profile bundles to remote homelab hosts.

Options:
  --apply       Actually transfer files (default is dry-run)
  --delete      Enable rsync --delete for all hosts (removes host files
                not in bundle — DANGEROUS)
  --host HOST   Only target this host (default: all hosts in definitions/hosts/)
  -h, --help    Show this help

Per-host config: definitions/hosts/<name>.toml
Exit: 0 if all attempted hosts OK, 1 if any host failed.
EOF
}

# ─── argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)   APPLY=true; shift ;;
    --delete)  CLI_DELETE=true; shift ;;
    --host)    HOST_FILTER="${2:?--host requires a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# ─── helpers ────────────────────────────────────────────────────────────────────

toml_get() {
  # toml_get <file> <key> — print value; lists are space-joined, missing key = empty
  python3 -c '
import tomllib, sys
with open(sys.argv[1], "rb") as f:
    d = tomllib.load(f)
v = d.get(sys.argv[2], "")
if isinstance(v, list):
    print(" ".join(v))
elif isinstance(v, bool):
    print(str(v).lower())
else:
    print(v)
' "$1" "$2"
}

resolve_target_dir() {
  # resolve_target_dir <toml> <profile>
  # Optional per-host target_dir override; otherwise the bundle .target (source of truth).
  local toml="$1" profile="$2"
  local override bundle
  override=$(toml_get "$toml" "target_dir")
  bundle="$PI_PROFILES_DIR/$profile"
  if [[ -n "$override" ]]; then
    printf '%s\n' "$override"
  else
    cat "$bundle/.target"
  fi
}

ssh_probe() {
  # ssh_probe <host> <ssh_opts...>
  local host="$1"; shift
  ssh "${@}" -o BatchMode=yes -o ConnectTimeout=5 "$host" true 2>/dev/null
}

deploy_host() {
  # deploy_host <host> <target_dir> <profile> <do_delete> <ssh_opts...>
  # Returns 0 on success (dry-run or applied+verified), 1 on failure.
  local host="$1" target_dir="$2" profile="$3" do_delete="$4"
  shift 4
  local -a ssh_opts=("$@")

  local bundle="$PI_PROFILES_DIR/$profile"
  [[ -d "$bundle" ]] || { echo "  [FAIL] bundle not found: $bundle"; return 1; }

  local ssh_exe="ssh"
  if [[ ${#ssh_opts[@]} -gt 0 ]]; then
    ssh_exe="ssh ${ssh_opts[*]}"
  fi

  local -a rsync_flags=(-avh --exclude='.target')
  $APPLY || rsync_flags+=(-n)
  $do_delete && rsync_flags+=(--delete)

  if $APPLY; then
    rsync "${rsync_flags[@]}" -e "$ssh_exe" "$bundle/" "$host:$target_dir/"
    echo "  rsync: transfer complete"

    # Post-sync md5 verification: verify exactly the bundle's file set.
    # Host-local extras (e.g. start-self-organising.md) are expected to remain,
    # so we hash the bundle's files on both sides, not the whole remote dir.
    local local_manifest remote_manifest bundle_files
    bundle_files=$(cd "$bundle" && find AGENTS.md skills prompts -type f | LC_ALL=C sort)
    local_manifest=$(
      cd "$bundle" && while IFS= read -r f; do
        printf '%s  %s\n' "$(md5 -q "$f")" "$f"
      done <<< "$bundle_files"
    )
    remote_manifest=$(
      printf '%s\n' "$bundle_files" | \
      ssh "${ssh_opts[@]}" "$host" \
        "cd $target_dir && while IFS= read -r f; do md5sum -- \"\$f\"; done" 2>/dev/null
    )
    if [[ "$local_manifest" != "$remote_manifest" ]]; then
      echo "  [FAIL] md5 mismatch on $host ($profile):"
      diff <(printf '%s\n' "$local_manifest") <(printf '%s\n' "$remote_manifest") | head -20 || true
      return 1
    fi
    local count
    count=$(printf '%s\n' "$local_manifest" | wc -l | tr -d ' ')
    echo "  md5 OK: $count files match"
  else
    rsync "${rsync_flags[@]}" -e "$ssh_exe" "$bundle/" "$host:$target_dir/"
    echo "  [DRY-RUN] would deploy $profile -> $host:$target_dir"
  fi
  return 0
}

# ─── pre-flight checks ──────────────────────────────────────────────────────────

if [[ ! -d "$PI_PROFILES_DIR" ]]; then
  echo "ERROR: $PI_PROFILES_DIR not found. Run propagate_definitions.py --apply first." >&2
  exit 1
fi

shopt -s nullglob
toml_files=("$HOSTS_DIR"/*.toml)
shopt -u nullglob

if [[ ${#toml_files[@]} -eq 0 ]]; then
  echo "ERROR: No host TOML files found in $HOSTS_DIR" >&2
  exit 1
fi

# Staleness hint (advisory only): generation-source dirs newer than generated/README.md.
# Only the generator's actual input dirs are checked (agents, skills, prompts, profiles).
# definitions/hosts/ (this script's own deploy config) and other non-source files are
# intentionally excluded so they don't trigger a false staleness warning.
if [[ -f "$GENERATED_DIR/README.md" ]]; then
  newest_def=$(find "$SCRIPT_DIR/definitions/agents" "$SCRIPT_DIR/definitions/skills" \
    "$SCRIPT_DIR/definitions/prompts" "$SCRIPT_DIR/definitions/profiles" \
    -type f -newer "$GENERATED_DIR/README.md" 2>/dev/null | head -1)
  if [[ -n "$newest_def" ]]; then
    echo "WARNING: definitions/ has files newer than generated/ output."
    echo "         Newest: ${newest_def#"$SCRIPT_DIR"/}"
    echo "         Consider: $SCRIPT_DIR/propagate_definitions.py --apply"
    echo
  fi
fi

echo "agents_files_cp_remote.sh — mode: $({ $APPLY && echo APPLY; } || echo DRY-RUN)"
echo "Hosts: $HOSTS_DIR"
echo

exit_code=0
hosts_ok=0
hosts_skip=0
hosts_fail=0

# ─── main loop ──────────────────────────────────────────────────────────────────

for toml in "${toml_files[@]}"; do
  host_name=$(toml_get "$toml" "host")
  profile=$(toml_get "$toml" "profile")
  host_delete=$(toml_get "$toml" "delete")
  ssh_opts_str=$(toml_get "$toml" "ssh_opts")
  read -ra SSH_OPTS <<< "$ssh_opts_str"
  target_dir=$(resolve_target_dir "$toml" "$profile")

  if [[ -z "$target_dir" ]]; then
    echo "  [FAIL] $host_name: no target_dir (missing .target in bundle '$profile' and no TOML override)"
    hosts_fail=$((hosts_fail + 1))
    exit_code=1
    continue
  fi
  if [[ "$target_dir" == *" "* ]]; then
    echo "  [FAIL] $host_name: target_dir contains whitespace; refusing to build remote shell command"
    hosts_fail=$((hosts_fail + 1))
    exit_code=1
    continue
  fi

  if [[ -n "$HOST_FILTER" && "$host_name" != "$HOST_FILTER" ]]; then
    continue
  fi

  # Per-host delete: CLI flag OR this host's TOML setting.
  do_delete=false
  $CLI_DELETE && do_delete=true
  [[ "$host_delete" == "true" ]] && do_delete=true

  echo "── $host_name (profile: $profile, target: $target_dir$($do_delete && echo ", delete: yes")) ──"

  # 1. Reachability probe (non-fatal: skip on failure)
  if ! ssh_probe "$host_name" "${SSH_OPTS[@]}"; then
    echo "  [SKIP] $host_name: ssh unreachable"
    hosts_skip=$((hosts_skip + 1))
    echo
    continue
  fi

  # 2. Verify target dir exists — if not, this host is not a pi-agent host.
  #    We never bootstrap an install; we only deploy to existing installs.
  if ! ssh "${SSH_OPTS[@]}" "$host_name" "[ -d $target_dir ]" 2>/dev/null; then
    echo "  [SKIP] $host_name: $target_dir does not exist on host (not a pi-agent host?)"
    hosts_skip=$((hosts_skip + 1))
    echo
    continue
  fi

  # 3. Deploy (+ verify when applying)
  if deploy_host "$host_name" "$target_dir" "$profile" "$do_delete" "${SSH_OPTS[@]}"; then
    echo "  [OK] $host_name"
    hosts_ok=$((hosts_ok + 1))
  else
    hosts_fail=$((hosts_fail + 1))
    exit_code=1
  fi
  echo
done

# ─── summary ────────────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary: $hosts_ok OK, $hosts_skip skipped, $hosts_fail failed"

exit "$exit_code"
