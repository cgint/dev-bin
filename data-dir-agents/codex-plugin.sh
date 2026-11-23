# Deploy the generated dev-bin marketplace with Codex's native installer.

codex_check_target() {
  local executable="$1" expected_rules="$2"
  local codex_dir="$HOME/.codex"
  local bundle="$codex_dir/dev-bin"
  local rules="$codex_dir/AGENTS.md"
  local stamp="$bundle/deployed-agents.sha256"
  local current_rules

  if [ "${CODEX_HOME:-$codex_dir}" != "$codex_dir" ] || [ ! -d "$codex_dir" ] || [ -L "$codex_dir" ] || [ ! -x "$executable" ]; then
    echo "ERROR: Codex must be installed at $executable and use $codex_dir" >&2
    return 1
  fi
  if [ -e "$codex_dir/AGENTS.override.md" ] || [ -L "$codex_dir/AGENTS.override.md" ]; then
    echo "ERROR: $codex_dir/AGENTS.override.md would shadow deployed instructions" >&2
    return 1
  fi
  if [ -e "$bundle" ] || [ -L "$bundle" ]; then
    local marker="$bundle/.data-dir-agents-managed"
    if [ ! -d "$bundle" ] || [ -L "$bundle" ] || [ -L "$marker" ] \
      || ! printf 'owner=data-dir-agents\ndeployment=codex\nschema=1\n' | cmp -s - "$marker"; then
      echo "ERROR: refusing to overwrite unmanaged Codex bundle: $bundle" >&2
      return 1
    fi
  fi
  if [ -e "$rules" ] || [ -L "$rules" ]; then
    if [ -L "$rules" ] || [ ! -f "$rules" ]; then
      echo "ERROR: expected a regular file at $rules" >&2
      return 1
    fi
    current_rules=$(shasum -a 256 <"$rules") || return 1
    current_rules="${current_rules%% *}"
    if [ "$current_rules" != "$expected_rules" ] && {
      [ -L "$stamp" ] || [ ! -f "$stamp" ] || ! grep -Fxq "$current_rules" "$stamp"
    }; then
      echo "ERROR: refusing to overwrite unmanaged Codex instructions: $rules" >&2
      return 1
    fi
  fi
  if [ -L "$stamp" ] || { [ -e "$stamp" ] && [ ! -f "$stamp" ]; }; then
    echo "ERROR: expected a regular file at $stamp" >&2
    return 1
  fi
}

codex_install_bundle() {
  local executable="$1" expected_rules="$2" version="$3"
  local codex_dir="$HOME/.codex"
  local bundle="$codex_dir/dev-bin"
  local rules="$codex_dir/AGENTS.md"
  local installed="$codex_dir/plugins/cache/dev-bin-local/dev-bin/$version"
  local result temporary_rules

  codex_check_target "$executable" "$expected_rules" || return 1
  "$executable" plugin marketplace add "$bundle/marketplace" --json >/dev/null || return 1
  result=$("$executable" plugin add dev-bin@dev-bin-local --json) || return 1
  if ! jq -e --arg version "$version" --arg path "$installed" \
    '.pluginId == "dev-bin@dev-bin-local" and .version == $version and .installedPath == $path' \
    <<<"$result" >/dev/null; then
    echo 'ERROR: Codex installed an unexpected dev-bin plugin' >&2
    return 1
  fi
  diff -r "$bundle/marketplace/plugins/dev-bin" "$installed" || return 1
  if ! cmp -s "$bundle/AGENTS.md" "$rules"; then
    temporary_rules=$(mktemp "$codex_dir/.dev-bin-AGENTS.XXXXXXXX") || return 1
    if ! cp -- "$bundle/AGENTS.md" "$temporary_rules" || ! mv -f -- "$temporary_rules" "$rules"; then
      rm -f -- "$temporary_rules"
      return 1
    fi
  fi
  printf '%s\n' "$expected_rules" >"$bundle/deployed-agents.sha256" || return 1
  printf 'Verified Codex dev-bin plugin %s and global instructions\n' "$version"
}

deploy_codex_bundle() {
  local data_dir="$1" executable="$2" apply="$3" host="${4:-}" ssh_opts="${5:-}"
  local source="$data_dir/generated/codex"
  local target="$HOME/.codex/dev-bin/"
  local version expected_rules changes
  local -a transport=(-a --checksum --exclude=/deployed-agents.sha256)

  uv run python -B - "$data_dir" <<'PY' || return 1
from pathlib import Path
import sys

data = Path(sys.argv[1])
sys.path.insert(0, str(data))
from propagate_definitions import verify_codex_bundle

try:
    verify_codex_bundle(data / "definitions", data / "generated")
except (OSError, ValueError) as error:
    sys.exit(f"{error}. Regenerate the bundle on the main Mac before deploying.")
PY

  version=$(jq -er '.version | select(test("^1\\.0\\.0\\+[0-9a-f]{12}$"))' \
    "$source/marketplace/plugins/dev-bin/.codex-plugin/plugin.json") || return 1
  expected_rules=$(shasum -a 256 <"$source/AGENTS.md") || return 1
  expected_rules="${expected_rules%% *}"

  if [ -n "$host" ]; then
    if [[ ! "$executable" =~ ^[a-zA-Z0-9_.-]+(/[a-zA-Z0-9_.-]+)*$ ]]; then
      echo "ERROR: Codex executable must be relative to the host's home: $executable" >&2
      return 1
    fi
    target="$host:.codex/dev-bin/"
    transport+=(-e "ssh $ssh_opts")
    {
      declare -f codex_check_target
      printf 'codex_check_target "$HOME/$1" "$2"\n'
    } | ssh $ssh_opts "$host" bash -s -- "$executable" "$expected_rules" || return 1
  else
    codex_check_target "$executable" "$expected_rules" || return 1
  fi

  if [ "$apply" = false ]; then
    rsync "${transport[@]}" -ni --delete "$source/" "$target" || return 1
    printf 'Would install Codex dev-bin plugin %s and global instructions\n' "$version"
    return 0
  fi

  rsync "${transport[@]}" --delete-delay "$source/" "$target" || return 1
  changes=$(rsync "${transport[@]}" -ni --delete "$source/" "$target") || return 1
  if [ -n "$changes" ]; then
    printf 'ERROR: Codex bundle verification failed for %s\n%s\n' "$target" "$changes" >&2
    return 1
  fi

  if [ -n "$host" ]; then
    {
      declare -f codex_check_target codex_install_bundle
      printf 'codex_install_bundle "$HOME/$1" "$2" "$3"\n'
    } | ssh $ssh_opts "$host" bash -s -- "$executable" "$expected_rules" "$version"
  else
    codex_install_bundle "$executable" "$expected_rules" "$version"
  fi
}
