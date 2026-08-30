#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -r "$TMPDIR_TEST"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$TMPDIR_TEST/bin"
cp "$ROOT/agents_files_cp.sh" "$TMPDIR_TEST/bin/agents_files_cp.sh"
cp -R "$ROOT/data-dir-agents" "$TMPDIR_TEST/bin/data-dir-agents"
chmod +x "$TMPDIR_TEST/bin/agents_files_cp.sh"

HOME="$TMPDIR_TEST/home"
TARGET="$HOME/.pi/profiles/partner/agent"
SKILLS="$TARGET/skills"
mkdir -p "$SKILLS/sub-agent-herdr-supervisor/scripts" "$SKILLS/unmanaged-skill"
printf 'old helper\n' >"$SKILLS/sub-agent-herdr-supervisor/scripts/retired-helper.sh"
printf 'do not delete\n' >"$SKILLS/unmanaged-skill/keep.txt"

mkdir -p "$SKILLS/retired-managed-skill" "$SKILLS/other-profile-skill"
cat >"$SKILLS/retired-managed-skill/.data-dir-agents-managed" <<'EOF'
owner=data-dir-agents
deployment=pi-agent-profiles/partner
skill=retired-managed-skill
schema=1
EOF
cat >"$SKILLS/other-profile-skill/.data-dir-agents-managed" <<'EOF'
owner=data-dir-agents
deployment=pi-agent-profiles/default
skill=other-profile-skill
schema=1
EOF

HOME="$HOME" "$TMPDIR_TEST/bin/agents_files_cp.sh" >/dev/null

test -f "$SKILLS/unmanaged-skill/keep.txt" || fail 'ordinary rollout deleted an unmanaged sibling skill'
test -d "$SKILLS/retired-managed-skill" || fail 'ordinary rollout deleted a stale managed skill directory'
test ! -e "$SKILLS/sub-agent-herdr-supervisor/scripts/retired-helper.sh" \
  || fail 'ordinary rollout retained a stale file inside an active managed skill'
test -f "$SKILLS/sub-agent-herdr-supervisor/.data-dir-agents-managed" \
  || fail 'ordinary rollout did not deploy the Herdr ownership marker'

HOME="$HOME" "$TMPDIR_TEST/bin/agents_files_cp.sh" --delete >/dev/null

test ! -e "$SKILLS/retired-managed-skill" || fail '--delete retained a stale managed skill directory'
test -f "$SKILLS/unmanaged-skill/keep.txt" || fail '--delete removed an unmanaged sibling skill'
test -d "$SKILLS/other-profile-skill" || fail '--delete removed a skill owned by another profile'

printf 'PASS: managed-skill deployment contract\n'
