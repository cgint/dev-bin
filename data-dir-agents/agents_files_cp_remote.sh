#!/usr/bin/env bash
#
# agents_files_cp_remote.sh — ship per-host pi-agent bundles to homelab hosts.
#
# Host specs: definitions/hosts/<name>.toml — self-contained, no profile refs:
#
#   host        = "sparky"         # ssh hostname
#   target_dir  = "~/.pi/agent"    # remote deploy dir ('~' expanded on the host)
#   agents_file = "AGENTS_GPT52.md"# template in definitions/agents/
#   skills      = [...]            # whitelist from definitions/skills/
#   prompts     = [...]            # whitelist from definitions/prompts/
#   delete      = false            # per-host rsync --delete (DANGEROUS)
#   ssh_opts    = [...]            # extra ssh options
#
# Usage: agents_files_cp_remote.sh [--apply] [--delete] [--host HOST] [-h]
#   default = dry-run. --apply transfers for real. --delete enables rsync --delete.
#
# Per host: ssh unreachable -> [SKIP] (non-fatal); target dir missing -> [SKIP]
# (we never bootstrap an install); source missing -> [FAIL]; transfer or md5
# mismatch -> [FAIL]. Exit 0 if all attempted hosts OK, 1 if any [FAIL].

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTS_DIR="$SCRIPT_DIR/definitions/hosts"
DEF_SKILLS="$SCRIPT_DIR/definitions/skills"
DEF_PROMPTS="$SCRIPT_DIR/definitions/prompts"
DEF_AGENTS="$SCRIPT_DIR/definitions/agents"
STAGE="$SCRIPT_DIR/.stage"

usage() {
  cat <<'EOF'
Usage: agents_files_cp_remote.sh [--apply] [--delete] [--host HOST] [-h]
Deploy pi-agent bundles to hosts in definitions/hosts/*.toml.
  --apply   transfer for real (default is dry-run)
  --delete  enable rsync --delete for all hosts (DANGEROUS)
  --host H  only this host
EOF
}

APPLY=false; DELETE=false; HOST_FILTER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply)  APPLY=true; shift ;;
    --delete) DELETE=true; shift ;;
    --host)   HOST_FILTER="${2:?--host needs a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

toml_get() {
  # toml_get <file> <key> — print value; lists print one item per line
  python3 -c '
import tomllib, sys
with open(sys.argv[1], "rb") as f:
    d = tomllib.load(f)
v = d.get(sys.argv[2], "")
if isinstance(v, list):
    for item in v: print(item)
elif isinstance(v, bool):
    print(str(v).lower())
else:
    print(v)
' "$1" "$2"
}

# ── pre-flight ─────────────────────────────────────────────────────────────────
if ! ls "$HOSTS_DIR"/*.toml >/dev/null 2>&1; then
  echo "ERROR: no host TOMLs in $HOSTS_DIR" >&2
  exit 1
fi

echo "agents_files_cp_remote.sh — $({ $APPLY && echo APPLY; } || echo DRY-RUN)"

exit_code=0; ok=0; skip=0; fail=0

for toml in "$HOSTS_DIR"/*.toml; do
  host=$(toml_get "$toml" host)
  target=$(toml_get "$toml" target_dir)
  agents_file=$(toml_get "$toml" agents_file)
  host_delete=$(toml_get "$toml" delete)
  ssh_opts=$(toml_get "$toml" ssh_opts | tr '\n' ' ')

  if [ -n "$HOST_FILTER" ] && [ "$host" != "$HOST_FILTER" ]; then
    continue
  fi

  # target_dir must be plain (no whitespace) — it is interpolated unquoted on the remote
  case "$target" in
    *" "*) echo "  [FAIL] $host: target_dir contains whitespace"; fail=$((fail+1)); exit_code=1; continue ;;
  esac

  echo "== $host -> $target =="

  # 1. reachability (skip, non-fatal)
  if ! ssh $ssh_opts -o BatchMode=yes -o ConnectTimeout=5 "$host" true 2>/dev/null; then
    echo "  [SKIP] $host: ssh unreachable"; skip=$((skip+1)); echo; continue
  fi

  # 2. target dir must already exist (we never bootstrap an install)
  if ! ssh $ssh_opts "$host" "[ -d $target ]" 2>/dev/null; then
    echo "  [SKIP] $host: $target does not exist"; skip=$((skip+1)); echo; continue
  fi

  # 3. stage the bundle: AGENTS.md + skills/ + prompts/
  stage="$STAGE/$host"
  find "$stage" -depth -delete 2>/dev/null || true
  mkdir -p "$stage/skills" "$stage/prompts"

  if ! python3 - "$SCRIPT_DIR" "$agents_file" "$stage/AGENTS.md" <<'PY'
import sys, pathlib
sys.path.insert(0, sys.argv[1])
from propagate_definitions import resolve_placeholders
agents_dir = pathlib.Path(sys.argv[1]) / "definitions" / "agents"
template = agents_dir / sys.argv[2]
if not template.exists():
    sys.exit("agents template not found: %s" % template)
pathlib.Path(sys.argv[3]).write_text(
    resolve_placeholders(template.read_text(encoding="utf-8"),
                         agents_dir / "blocks"),
    encoding="utf-8")
PY
  then
    echo "  [FAIL] $host: cannot render AGENTS.md from $agents_file"
    fail=$((fail+1)); exit_code=1; echo; continue
  fi

  missing=""
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    if [ -d "$DEF_SKILLS/$s" ]; then
      cp -R "$DEF_SKILLS/$s" "$stage/skills/"
    else
      missing="$missing $s"
    fi
  done < <(toml_get "$toml" skills)

  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ -f "$DEF_PROMPTS/$p" ]; then
      cp "$DEF_PROMPTS/$p" "$stage/prompts/"
    else
      missing="$missing $p"
    fi
  done < <(toml_get "$toml" prompts)

  if [ -n "$missing" ]; then
    echo "  [FAIL] $host: missing in definitions:$missing"
    fail=$((fail+1)); exit_code=1; echo; continue
  fi

  # 4. transfer
  rsync_flags="-avh"
  if [ "$APPLY" = false ]; then rsync_flags="$rsync_flags -n"; fi
  if [ "$DELETE" = true ] || [ "$host_delete" = true ]; then rsync_flags="$rsync_flags --delete"; fi

  if ! rsync $rsync_flags -e "ssh $ssh_opts" "$stage/" "$host:$target/"; then
    echo "  [FAIL] $host: rsync failed"; fail=$((fail+1)); exit_code=1; echo; continue
  fi

  # 5. verify (apply only)
  if [ "$APPLY" = true ]; then
    manifest=$(cd "$stage" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
    local_m=$(cd "$stage" && while IFS= read -r f; do
      printf '%s  %s\n' "$(md5 -q "$f")" "$f"
    done <<< "$manifest")
    if ! remote_m=$(printf '%s\n' "$manifest" | \
      ssh $ssh_opts "$host" "cd $target && while IFS= read -r f; do md5sum -- \"\$f\"; done" 2>/dev/null); then
      echo "  [FAIL] $host: md5 check could not run"; fail=$((fail+1)); exit_code=1; echo; continue
    fi
    if [ "$local_m" != "$remote_m" ]; then
      echo "  [FAIL] $host: md5 mismatch:"
      diff <(printf '%s\n' "$local_m") <(printf '%s\n' "$remote_m") | head -20 || true
      fail=$((fail+1)); exit_code=1; echo; continue
    fi
    echo "  [OK] $host: $(printf '%s\n' "$manifest" | wc -l | tr -d ' ') files transferred + verified"
  else
    echo "  [DRY-RUN] $host: plan above; run with --apply to transfer"
  fi
  ok=$((ok+1))
  echo
done

echo "summary: $ok ok, $skip skipped, $fail failed"
exit "$exit_code"
