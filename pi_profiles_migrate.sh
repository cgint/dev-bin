#!/bin/bash
# Retire ~/.pi/profiles: merge all profile sessions into ~/.pi/agent/sessions
# (fork links remapped), keep ~/.pi/agent config as is. Moves only; never deletes.
# See MIGRATION-remove-pi-profiles.md.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: pi_profiles_migrate.sh [--apply]
Without --apply: preflight only, prints what would happen.
With --apply: merge sessions, archive ~/.pi/profiles + retired skills into
~/.pi-rollback-YYYYMMDD, rewrite the pi-acp session map, drop pi-profile
aliases from ~/.zshrc, snapshot deploy targets. Stop every pi process first.
EOF
}

APPLY=false
case "${1:-}" in
  "") ;;
  --apply) APPLY=true ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI="$HOME/.pi"
ROLLBACK="$HOME/.pi-rollback-$(date +%Y%m%d)"
# Skills deployed by the old default profile that generated/pi-agent no longer ships.
RETIRED_SKILLS=(cmux-usage colgrep firstmate grill-with-docs ntfy-phone python-uv-discipline
  skill-architect sub-agent-cmux-supervisor sub-agent-herdr-supervisor)
ALIAS_RE="^alias [A-Za-z0-9_]+=[\"']pi-profile "

die() { echo "ABORT: $*" >&2; exit 1; }
# PI_MIGRATE_PGREP: test seam (a command that succeeds when pi is running).
pi_running() { ${PI_MIGRATE_PGREP:-pgrep -x pi} >/dev/null 2>&1; }
nopi() { ! pi_running || die "pi is running; stop it (pgrep -x pi, hc ls / hc kill <t>)"; }

nopi
[ -d "$PI/profiles" ] || die "$PI/profiles not found (already migrated?)"
[ -d "$PI/agent/sessions" ] || die "$PI/agent/sessions not found"
[ ! -e "$ROLLBACK" ] || die "$ROLLBACK already exists"

if [ "$APPLY" != true ]; then
  echo "Preflight OK. --apply would:"
  echo "  merge sessions of $PI/agent and: $(cd "$PI/profiles" && echo *)"
  echo "  archive into $ROLLBACK: agent sessions, profiles, retired skills, session map, .zshrc"
  echo "  pi-profile aliases in ~/.zshrc: $(grep -cE "$ALIAS_RE" "$HOME/.zshrc" 2>/dev/null || true)"
  exit 0
fi

STAGE="$(mktemp -d "$HOME/.pi-cutover.XXXXXX")"
chmod 700 "$STAGE"
"$SCRIPT_DIR/merge_pi_history.py" "$PI" "$STAGE/sessions" | tee "$STAGE/merge_result.json"

nopi
mkdir -m 700 "$ROLLBACK"
mv "$STAGE/merge_result.json" "$ROLLBACK/"
undo() {
  echo "ERROR during swap; restoring" >&2
  if [ -d "$ROLLBACK/agent-sessions" ]; then
    [ -d "$PI/agent/sessions" ] && mv "$PI/agent/sessions" "$STAGE/sessions.failed"
    mv "$ROLLBACK/agent-sessions" "$PI/agent/sessions"
  fi
  [ -d "$ROLLBACK/profiles" ] && [ ! -e "$PI/profiles" ] && mv "$ROLLBACK/profiles" "$PI/profiles"
  exit 1
}
trap undo ERR
mv "$PI/agent/sessions" "$ROLLBACK/agent-sessions"
mv "$STAGE/sessions" "$PI/agent/sessions"
mv "$PI/profiles" "$ROLLBACK/profiles"
trap - ERR
rmdir "$STAGE"
echo "Sessions merged; profiles archived."

src="$ROLLBACK/profiles/minimal/agent/pi-agents/sessions"
if [ -d "$src" ]; then
  mkdir -p "$PI/agent/pi-agents/sessions"
  for d in "$src"/*; do
    [ -e "$d" ] || continue
    name="$(basename "$d")"
    if [ -e "$PI/agent/pi-agents/sessions/$name" ]; then
      echo "skip existing pi-agents/sessions/$name"
    else
      cp -Rp "$d" "$PI/agent/pi-agents/sessions/$name"
    fi
  done
fi

mkdir -p "$ROLLBACK/skills"
for skill in "${RETIRED_SKILLS[@]}"; do
  if [ -d "$PI/agent/skills/$skill" ]; then
    mv "$PI/agent/skills/$skill" "$ROLLBACK/skills/$skill"
    echo "retired skill $skill"
  fi
done

MAP="$PI/pi-acp/session-map.json"
if [ -f "$MAP" ]; then
  cp -p "$MAP" "$ROLLBACK/session-map.json"
  /usr/bin/python3 - "$MAP" "$PI" <<'PY'
import json, re, sys
path, pi = sys.argv[1], sys.argv[2]
raw = open(path).read()
pattern = re.compile(re.escape(pi + "/profiles/") + r"[^/\"]+/agent/sessions/")
new, count = pattern.subn(pi + "/agent/sessions/", raw)
json.loads(new)
open(path, "w").write(new)
print(f"session map: rewrote {count} path(s)")
PY
fi

if [ -f "$HOME/.zshrc" ]; then
  cp -p "$HOME/.zshrc" "$ROLLBACK/zshrc.bak"
  grep -vE "$ALIAS_RE" "$ROLLBACK/zshrc.bak" >"$HOME/.zshrc" || true
  zsh -n "$HOME/.zshrc"
  echo ".zshrc: removed $(grep -cE "$ALIAS_RE" "$ROLLBACK/zshrc.bak" || true) pi-profile alias(es)"
fi

# Snapshot what the follow-up agents_files_cp.sh --delete will overwrite.
DEPLOY_TARGETS=(.claude/CLAUDE.md .claude/commands .claude/skills .gemini/GEMINI.md .gemini/commands
  .gemini/skills .copilot/copilot-instructions.md .copilot/skills .copilot/profiles .cursor/skills
  .codex/AGENTS.md .codex/dev-bin .pi/agent/AGENTS.md .pi/agent/skills .pi/agent/prompts)
existing=()
for target in "${DEPLOY_TARGETS[@]}"; do
  [ -e "$HOME/$target" ] && existing+=("$target")
done
if [ "${#existing[@]}" -gt 0 ]; then
  tar -czf "$ROLLBACK/deploy-targets.tgz" -C "$HOME" "${existing[@]}"
  chmod 600 "$ROLLBACK/deploy-targets.tgz"
  echo "deploy targets backed up: $ROLLBACK/deploy-targets.tgz"
fi

echo "Done. Rollback archive: $ROLLBACK"
echo "Next: agents_files_cp.sh --delete, then the verification checklist in MIGRATION-remove-pi-profiles.md"
