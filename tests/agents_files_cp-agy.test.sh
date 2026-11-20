#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -r -- "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/bin" "$TEST_DIR/data-dir-agents/definitions/hosts"
cp "$ROOT/agents_files_cp.sh" "$ROOT/agents_files_cp_remote.sh" "$TEST_DIR/"
cp "$ROOT/data-dir-agents/agy-skills.sh" "$TEST_DIR/data-dir-agents/"
cat >"$TEST_DIR/data-dir-agents/definitions/hosts/testhost.toml" <<'EOF'
host = "testhost"
target_dir = "~/.pi/agent"
EOF
cat >"$TEST_DIR/bin/ssh" <<'EOF'
#!/bin/bash
set -euo pipefail
while [ "$1" = -o ]; do shift 2; done
[ "$1" = testhost ]
shift
cd "$AGY_TEST_REMOTE_HOME"
exec env HOME="$AGY_TEST_REMOTE_HOME" bash -c "$*"
EOF
chmod +x "$TEST_DIR/bin/ssh"

export AGENTS_FILES_CP_HOSTNAME=MacBook-Pro
export AGY_TEST_REMOTE_HOME="$TEST_DIR/remote"
export PATH="$TEST_DIR/bin:$PATH"
LOCAL_TEST_HOME="$TEST_DIR/local"

write_marker() {
  printf 'owner=data-dir-agents\ndeployment=gemini\nskill=%s\nschema=1\n' "$2" \
    >"$1/.data-dir-agents-managed"
}

source_skills="$TEST_DIR/data-dir-agents/generated/gemini/skills"
mkdir -p "$source_skills/test-skill"
printf 'current content\n' >"$source_skills/test-skill/SKILL.md"
write_marker "$source_skills/test-skill" test-skill

for test_home in "$LOCAL_TEST_HOME" "$AGY_TEST_REMOTE_HOME"; do
  skills="$test_home/.gemini/config/skills"
  mkdir -p "$test_home/.gemini/antigravity-cli" "$skills/personal" "$skills/retired"
  printf 'personal content\n' >"$skills/personal/SKILL.md"
  write_marker "$skills/retired" retired
done

local_deploy=(env HOME="$LOCAL_TEST_HOME" "$TEST_DIR/agents_files_cp.sh" --agy-only)
remote_deploy=("$TEST_DIR/agents_files_cp_remote.sh" --host testhost --agy-only)
local_skills="$LOCAL_TEST_HOME/.gemini/config/skills"
remote_skills="$AGY_TEST_REMOTE_HOME/.gemini/config/skills"

"${local_deploy[@]}" >/dev/null
"${remote_deploy[@]}" --delete >/dev/null
[ ! -e "$remote_skills/test-skill" ]
[ -d "$remote_skills/retired" ]
"${remote_deploy[@]}" --apply >/dev/null

for skills in "$local_skills" "$remote_skills"; do
  cmp "$source_skills/test-skill/SKILL.md" "$skills/test-skill/SKILL.md"
  [ -d "$skills/retired" ]
  printf 'stale helper\n' >"$skills/test-skill/stale"
done
"${local_deploy[@]}" --delete >/dev/null
"${remote_deploy[@]}" --apply --delete >/dev/null
for skills in "$local_skills" "$remote_skills"; do
  [ ! -e "$skills/retired" ]
  [ ! -e "$skills/test-skill/stale" ]
  [ "$(cat "$skills/personal/SKILL.md")" = 'personal content' ]
done

# The regular Mac rollout keeps both global locations on the same bundle.
printf '#!/bin/bash\nexit 0\n' >"$TEST_DIR/data-dir-agents/propagate_definitions.py"
chmod +x "$TEST_DIR/data-dir-agents/propagate_definitions.py"
printf 'updated content\n' >"$source_skills/test-skill/SKILL.md"
env HOME="$LOCAL_TEST_HOME" "$TEST_DIR/agents_files_cp.sh" >/dev/null
cmp "$source_skills/test-skill/SKILL.md" "$local_skills/test-skill/SKILL.md"
cmp "$source_skills/test-skill/SKILL.md" "$LOCAL_TEST_HOME/.gemini/skills/test-skill/SKILL.md"

mkdir -p "$source_skills/personal"
printf 'repo content\n' >"$source_skills/personal/SKILL.md"
write_marker "$source_skills/personal" personal
if "${local_deploy[@]}" >"$TEST_DIR/local-error" 2>&1; then
  echo 'FAIL: local deploy accepted an unmanaged collision' >&2
  exit 1
fi
if "${remote_deploy[@]}" --apply >"$TEST_DIR/remote-error" 2>&1; then
  echo 'FAIL: remote deploy accepted an unmanaged collision' >&2
  exit 1
fi
for error in "$TEST_DIR/local-error" "$TEST_DIR/remote-error"; do
  grep -q 'unmanaged agy skill' "$error"
done
for skills in "$local_skills" "$remote_skills"; do
  [ "$(cat "$skills/personal/SKILL.md")" = 'personal content' ]
done
[ ! -e "$AGY_TEST_REMOTE_HOME/.pi" ]
printf 'PASS: local and remote agy deployment\n'
