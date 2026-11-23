#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -r -- "$FIXTURE"' EXIT
export CODEX_TEST_HOME="$FIXTURE/remote"
export CODEX_TEST_OTHER_HOME="$FIXTURE/other"
export AGENTS_FILES_CP_HOSTNAME=MacBook-Pro
local_home="$FIXTURE/mac"
host_specs="$FIXTURE/data-dir-agents/definitions/hosts"
generated="$FIXTURE/data-dir-agents/generated"
codex_executable=$(command -v codex)

mkdir -p "$FIXTURE/bin" "$host_specs" "$generated" "$local_home/.codex" \
  "$CODEX_TEST_HOME/.codex" "$CODEX_TEST_HOME/.npm-global/bin" "$CODEX_TEST_OTHER_HOME/.codex"
cp "$ROOT/agents_files_cp.sh" "$ROOT/agents_files_cp_remote.sh" "$FIXTURE/"
cp "$ROOT/data-dir-agents/codex-plugin.sh" "$FIXTURE/data-dir-agents/"
cp -R "$ROOT/data-dir-agents/generated/codex" "$generated/codex"
cp "$ROOT/data-dir-agents/propagate_definitions.py" "$FIXTURE/data-dir-agents/"
for source_dir in agents runtime skills; do
  cp -R "$ROOT/data-dir-agents/definitions/$source_dir" "$FIXTURE/data-dir-agents/definitions/"
done
ln -s "$codex_executable" "$CODEX_TEST_HOME/.npm-global/bin/codex"

cat >"$host_specs/testhost.toml" <<'EOF'
host = "testhost"
target_dir = "~/.pi/agent"
codex_bin = ".npm-global/bin/codex"
EOF
cat >"$host_specs/otherhost.toml" <<'EOF'
host = "otherhost"
target_dir = "~/.pi/agent"
EOF
cat >"$FIXTURE/bin/ssh" <<'EOF'
#!/bin/bash
set -euo pipefail
while [ "$1" = -o ]; do shift 2; done
case "$1" in
  testhost) target_home="$CODEX_TEST_HOME" ;;
  otherhost) target_home="$CODEX_TEST_OTHER_HOME" ;;
  *) exit 2 ;;
esac
shift
cd "$target_home"
exec env -u CODEX_HOME HOME="$target_home" bash -c "$*"
EOF
chmod +x "$FIXTURE/bin/ssh"
export PATH="$FIXTURE/bin:$PATH"

printf '# Existing user config\n' >"$local_home/.codex/config.toml"
cp "$generated/codex/AGENTS.md" "$local_home/.codex/AGENTS.md"
env -u CODEX_HOME HOME="$local_home" "$FIXTURE/agents_files_cp.sh"
grep -Fxq '# Existing user config' "$local_home/.codex/config.toml"
cp "$local_home/.codex/config.toml" "$FIXTURE/config.after-install"
env -u CODEX_HOME HOME="$local_home" "$FIXTURE/agents_files_cp.sh"
cmp "$FIXTURE/config.after-install" "$local_home/.codex/config.toml"

"$FIXTURE/agents_files_cp_remote.sh" --host testhost >"$FIXTURE/dry-run"
grep -q 'Would install Codex' "$FIXTURE/dry-run"
[ ! -e "$CODEX_TEST_HOME/.codex/dev-bin" ]
[ ! -e "$CODEX_TEST_HOME/.codex/config.toml" ]
"$FIXTURE/agents_files_cp_remote.sh" --host testhost --apply
"$FIXTURE/agents_files_cp_remote.sh" --host otherhost --apply
[ ! -e "$CODEX_TEST_OTHER_HOME/.codex/dev-bin" ]

package="$generated/codex/marketplace/plugins/dev-bin"
version=$(jq -er .version "$package/.codex-plugin/plugin.json")
for target_home in "$local_home" "$CODEX_TEST_HOME"; do
  cmp "$generated/codex/AGENTS.md" "$target_home/.codex/AGENTS.md"
  diff -r "$package" "$target_home/.codex/plugins/cache/dev-bin-local/dev-bin/$version"
  [ ! -e "$target_home/.agents" ]
done

printf 'personal instructions\n' >"$CODEX_TEST_HOME/.codex/AGENTS.md"
if "$FIXTURE/agents_files_cp_remote.sh" --host testhost --apply >"$FIXTURE/collision" 2>&1; then
  echo 'FAIL: remote overwrite of unmanaged instructions was accepted' >&2
  exit 1
fi
grep -q 'refusing to overwrite unmanaged Codex instructions' "$FIXTURE/collision"
grep -Fxq 'personal instructions' "$CODEX_TEST_HOME/.codex/AGENTS.md"

cp "$generated/codex/AGENTS.md" "$CODEX_TEST_HOME/.codex/AGENTS.md"
printf '\nEdited skill source.\n' >>"$FIXTURE/data-dir-agents/definitions/skills/concept-wayfinder/SKILL.md"
if "$FIXTURE/agents_files_cp_remote.sh" --host testhost >"$FIXTURE/stale" 2>&1; then
  echo 'FAIL: remote dry-run accepted stale Codex artifacts' >&2
  exit 1
fi
grep -q 'Codex bundle is stale' "$FIXTURE/stale"

cp "$ROOT/data-dir-agents/definitions/skills/concept-wayfinder/SKILL.md" \
  "$FIXTURE/data-dir-agents/definitions/skills/concept-wayfinder/SKILL.md"
printf '\nModified generated skill.\n' >>"$package/skills/concept-wayfinder/SKILL.md"
if "$FIXTURE/agents_files_cp_remote.sh" --host testhost >"$FIXTURE/modified-package" 2>&1; then
  echo 'FAIL: remote dry-run accepted a modified Codex package' >&2
  exit 1
fi
grep -q 'generated skill contents differ from the manifest' "$FIXTURE/modified-package"
printf 'PASS: Codex deployment and ownership checks\n'
