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

# --- host guard: refuse to run off the main Mac (test injects a non-Mac hostname) ---
GUARD_HOME="$TMPDIR_TEST/guard-home"
mkdir -p "$GUARD_HOME"
set +e
AGENTS_FILES_CP_HOSTNAME=pluto HOME="$GUARD_HOME" "$TMPDIR_TEST/bin/agents_files_cp.sh" \
  >"$TMPDIR_TEST/guard.out" 2>"$TMPDIR_TEST/guard.err"
guard_rc=$?
set -e
[ "$guard_rc" -eq 2 ] || fail "host guard: expected exit 2 on a non-Mac host, got $guard_rc"
grep -q 'may only run on the main Mac (MacBook-Pro.local)' "$TMPDIR_TEST/guard.err" \
  || fail 'host guard: warning does not name the allowed host'
grep -q 'Detected host: pluto' "$TMPDIR_TEST/guard.err" \
  || fail 'host guard: warning does not name the detected host'
grep -q 'agents_files_cp_remote.sh' "$TMPDIR_TEST/guard.err" \
  || fail 'host guard: warning does not point to the remote deploy alternative'
if grep -q 'Generating artifacts' "$TMPDIR_TEST/guard.out" "$TMPDIR_TEST/guard.err"; then
  fail 'host guard: generator ran before the guard refused'
fi
[ ! -e "$GUARD_HOME/.pi" ] || fail 'host guard: created pi config dirs on a refused host'

# --- --help stays available on any host (guard sits after arg parsing) ---
"$TMPDIR_TEST/bin/agents_files_cp.sh" --help >"$TMPDIR_TEST/help.out" 2>&1 \
  || fail '--help did not exit 0 on a non-Mac host'
grep -q 'Usage: agents_files_cp.sh' "$TMPDIR_TEST/help.out" || fail '--help lost its usage header'

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

AGENTS_FILES_CP_HOSTNAME=MacBook-Pro HOME="$HOME" "$TMPDIR_TEST/bin/agents_files_cp.sh" >/dev/null

test -f "$SKILLS/unmanaged-skill/keep.txt" || fail 'ordinary rollout deleted an unmanaged sibling skill'
test -d "$SKILLS/retired-managed-skill" || fail 'ordinary rollout deleted a stale managed skill directory'
test ! -e "$SKILLS/sub-agent-herdr-supervisor/scripts/retired-helper.sh" \
  || fail 'ordinary rollout retained a stale file inside an active managed skill'
test -f "$SKILLS/sub-agent-herdr-supervisor/.data-dir-agents-managed" \
  || fail 'ordinary rollout did not deploy the Herdr ownership marker'

AGENTS_FILES_CP_HOSTNAME=MacBook-Pro HOME="$HOME" "$TMPDIR_TEST/bin/agents_files_cp.sh" --delete >/dev/null

test ! -e "$SKILLS/retired-managed-skill" || fail '--delete retained a stale managed skill directory'
test -f "$SKILLS/unmanaged-skill/keep.txt" || fail '--delete removed an unmanaged sibling skill'
test -d "$SKILLS/other-profile-skill" || fail '--delete removed a skill owned by another profile'

printf 'PASS: main-Mac host guard\n'
printf 'PASS: managed-skill deployment contract\n'
