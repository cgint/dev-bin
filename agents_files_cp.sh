#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: agents_files_cp.sh [--delete] [--openspec-config | --agy-only]
Deploy generated agent definitions to local agent config dirs.
Local deployment is allowed on MacBook-Pro and christian.gintenreiter-smec;
homelab hosts are served by agents_files_cp_remote.sh from the main Mac.
  --delete           also remove retired files/dirs from synced targets (skill dirs,
                       Pi prompts, gemini/claude commands); active contents always mirror source
  --openspec-config  also roll out openspec/config.yaml to existing OpenSpec directories
  --agy-only        deploy existing generated skills to ~/.gemini/config/skills only
  -h, --help         show this help
EOF
}

DELETE_RSYNC=false
ROLLOUT_OPENSPEC_CONFIG=false
AGY_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --delete)
      DELETE_RSYNC=true
      ;;
    --openspec-config)
      ROLLOUT_OPENSPEC_CONFIG=true
      ;;
    --agy-only)
      AGY_ONLY=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo >&2
      usage >&2
      exit 2
      ;;
  esac
done

# Only these Macs may deploy locally. Homelab hosts receive bundles remotely.
# AGENTS_FILES_CP_HOSTNAME is test injection, not a supported bypass.
ALLOWED_HOSTS=(MacBook-Pro christian.gintenreiter-smec)
CURRENT_HOST="${AGENTS_FILES_CP_HOSTNAME:-$(hostname)}"
HOST_ALLOWED=false
for allowed_host in "${ALLOWED_HOSTS[@]}"; do
  if [ "$CURRENT_HOST" = "$allowed_host" ] || [ "${CURRENT_HOST%%.*}" = "$allowed_host" ]; then
    HOST_ALLOWED=true
    break
  fi
done
if [ "$HOST_ALLOWED" = false ]; then
  echo "ERROR: local deployment is restricted; allowed hosts: MacBook-Pro, christian.gintenreiter-smec." >&2
  echo "  Detected host: $CURRENT_HOST" >&2
  echo "  Homelab hosts are deployed from the main Mac via: agents_files_cp_remote.sh --host <host> --apply" >&2
  exit 2
fi

RSYNC_OPTS=(-avh)
readonly MANAGED_SKILL_MARKER=".data-dir-agents-managed"

rsync_copy_dir() {
  local src_dir="$1"
  local dest_dir="$2"
  mkdir -p "$dest_dir"
  if [ "$DELETE_RSYNC" = true ]; then
    rsync "${RSYNC_OPTS[@]}" --delete "$src_dir/" "$dest_dir/"
  else
    rsync "${RSYNC_OPTS[@]}" "$src_dir/" "$dest_dir/"
  fi
}

managed_skill_matches() {
  local skill_dir="$1"
  local deployment="$2"
  local skill_name
  local marker="$skill_dir/$MANAGED_SKILL_MARKER"
  skill_name="$(basename "$skill_dir")"
  [ -f "$marker" ] \
    && grep -qx 'owner=data-dir-agents' "$marker" \
    && grep -Fqx "deployment=$deployment" "$marker" \
    && grep -Fqx "skill=$skill_name" "$marker" \
    && grep -qx 'schema=1' "$marker"
}

sync_managed_skills() {
  local source_skills="$1"
  local target_skills="$2"
  local deployment="$3"
  local source_skill target_skill skill_name

  [ -d "$source_skills" ] || return 0
  mkdir -p "$target_skills"

  for source_skill in "$source_skills"/*/; do
    [ -d "$source_skill" ] || continue
    skill_name="$(basename "$source_skill")"
    managed_skill_matches "$source_skill" "$deployment" \
      || { echo "ERROR: invalid generated skill marker: $source_skill" >&2; return 2; }
    target_skill="$target_skills/$skill_name"
    echo "    Syncing managed skill $skill_name ..."
    # Inner sync always mirrors an active skill exactly; DELETE_RSYNC controls only
    # the outer stale-directory cleanup below. An unmarked same-name target is not
    # collision-guarded here, so do not share an active generated skill name.
    rsync -avh --delete --delete-delay "$source_skill" "$target_skill/"
  done

  [ "$DELETE_RSYNC" = true ] || return 0
  for target_skill in "$target_skills"/*/; do
    [ -d "$target_skill" ] || continue
    managed_skill_matches "$target_skill" "$deployment" || continue
    skill_name="$(basename "$target_skill")"
    [ -d "$source_skills/$skill_name" ] && continue
    echo "    Removing stale managed skill $skill_name ..."
    rm -r -- "$target_skill"
  done
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_SRC_DATA_DIR="$SCRIPT_DIR/data-dir-agents"
USER_HOME_DIR="$HOME"

GENERATED_DIR="$AGENTS_SRC_DATA_DIR/generated"
GEMINI_SKILLS_SOURCE="$GENERATED_DIR/gemini/skills"

GEMINI_AGENTS_DIR="$USER_HOME_DIR/.gemini"
CLAUDE_AGENTS_DIR="$USER_HOME_DIR/.claude"
CODEX_AGENTS_DIR="$USER_HOME_DIR/.codex"
COPILOT_AGENTS_DIR="$USER_HOME_DIR/.copilot"

GEMINI_AGENTS_FILE="$GEMINI_AGENTS_DIR/GEMINI.md"
CLAUDE_AGENTS_FILE="$CLAUDE_AGENTS_DIR/CLAUDE.md"
COPILOT_AGENTS_FILE="$COPILOT_AGENTS_DIR/copilot-instructions.md"

if [ "$AGY_ONLY" = true ]; then
  if [ "$ROLLOUT_OPENSPEC_CONFIG" = true ]; then
    echo 'ERROR: --agy-only cannot be combined with --openspec-config' >&2
    exit 2
  fi
  source "$AGENTS_SRC_DATA_DIR/agy-skills.sh"
  deploy_agy_skills "$GEMINI_SKILLS_SOURCE" true "$DELETE_RSYNC"
  exit 0
fi

echo
echo "Deploying agents files to the config directories that exist..."
echo

# Ensure generated artifacts exist (built within the repo)
if [ -x "$AGENTS_SRC_DATA_DIR/propagate_definitions.py" ]; then
  echo "Generating artifacts via $AGENTS_SRC_DATA_DIR/propagate_definitions.py --apply ..."
  "$AGENTS_SRC_DATA_DIR/propagate_definitions.py" --apply
  echo
else
  echo "ERROR: generator not found or not executable: $AGENTS_SRC_DATA_DIR/propagate_definitions.py"
  exit 2
fi

# Copy generated artifacts if available
if [ -d "$GENERATED_DIR" ]; then
  echo "Copying generated agent artifacts from $GENERATED_DIR ..."
  if [ -d "$CODEX_AGENTS_DIR" ]; then
    source "$AGENTS_SRC_DATA_DIR/codex-plugin.sh"
    CODEX_BIN=$(command -v codex) || { echo 'ERROR: Codex is missing from PATH' >&2; exit 1; }
    deploy_codex_bundle "$AGENTS_SRC_DATA_DIR" "$CODEX_BIN" true
  fi

  # Gemini: copy GEMINI.md + commands + skills into ~/.gemini/
  if [ -d "$GEMINI_AGENTS_DIR" ] && [ -f "$GENERATED_DIR/gemini/GEMINI.md" ]; then
    mkdir -p "$GEMINI_AGENTS_DIR"
    cp -v "$GENERATED_DIR/gemini/GEMINI.md" "$GEMINI_AGENTS_FILE"
  fi
  if [ -d "$GEMINI_AGENTS_DIR" ] && [ -d "$GENERATED_DIR/gemini/commands" ]; then
    rsync_copy_dir "$GENERATED_DIR/gemini/commands" "$GEMINI_AGENTS_DIR/commands"
  fi
  if [ -d "$GEMINI_AGENTS_DIR" ] && [ -d "$GEMINI_SKILLS_SOURCE" ]; then
    sync_managed_skills "$GEMINI_SKILLS_SOURCE" "$GEMINI_AGENTS_DIR/skills" "gemini"
  fi

  # An initialized Antigravity CLI uses the global Antigravity config root.
  if [ -d "$GEMINI_AGENTS_DIR/antigravity-cli" ] && [ -d "$GEMINI_AGENTS_DIR/config" ]; then
    source "$AGENTS_SRC_DATA_DIR/agy-skills.sh"
    deploy_agy_skills "$GEMINI_SKILLS_SOURCE" true "$DELETE_RSYNC"
  fi

  # Claude Code: copy CLAUDE.md + commands + skills into ~/.claude/
  if [ -d "$CLAUDE_AGENTS_DIR" ] && [ -f "$GENERATED_DIR/claude/CLAUDE.md" ]; then
    mkdir -p "$CLAUDE_AGENTS_DIR"
    cp -v "$GENERATED_DIR/claude/CLAUDE.md" "$CLAUDE_AGENTS_FILE"
  fi
  if [ -d "$CLAUDE_AGENTS_DIR" ] && [ -d "$GENERATED_DIR/claude/commands" ]; then
    rsync_copy_dir "$GENERATED_DIR/claude/commands" "$CLAUDE_AGENTS_DIR/commands"
  fi
  if [ -d "$CLAUDE_AGENTS_DIR" ] && [ -d "$GENERATED_DIR/claude/skills" ]; then
    sync_managed_skills "$GENERATED_DIR/claude/skills" "$CLAUDE_AGENTS_DIR/skills" "claude"
  fi

  # Copilot: copy combined file into ~/.copilot/ plus Agent Skills
  if [ -d "$COPILOT_AGENTS_DIR" ]; then
    mkdir -p "$COPILOT_AGENTS_DIR"
    if [ -f "$GENERATED_DIR/copilot/copilot-instructions.md" ]; then
      cp -v "$GENERATED_DIR/copilot/copilot-instructions.md" "$COPILOT_AGENTS_FILE"
    fi
    if [ -d "$GENERATED_DIR/copilot/skills" ]; then
      sync_managed_skills "$GENERATED_DIR/copilot/skills" "$COPILOT_AGENTS_DIR/skills" "copilot"
    fi
  fi

  # Copilot profiles: deploy each generated profile to its configured target dir
  COPILOT_PROFILES_GENERATED="$GENERATED_DIR/copilot-profiles"
  if [ -d "$COPILOT_PROFILES_GENERATED" ]; then
    for profile_dir in "$COPILOT_PROFILES_GENERATED"/*/; do
      profile_name=$(basename "$profile_dir")
      target_dir=$(cat "$profile_dir/.target" 2>/dev/null || true)
      target_dir="${target_dir/#\~/$HOME}"
      if [ -z "$target_dir" ]; then
        echo " -- Skipping Copilot profile '$profile_name': target dir is empty"
        continue
      fi
      if [ ! -d "$target_dir" ]; then
        echo " -- Creating target dir for Copilot profile '$profile_name': $target_dir"
        mkdir -p "$target_dir"
      fi
      echo " -- Deploying Copilot profile '$profile_name' -> $target_dir ... (if no output then everything is up to date)"
      [ -f "$profile_dir/copilot-instructions.md" ] && cp -v "$profile_dir/copilot-instructions.md" "$target_dir/copilot-instructions.md"
      [ -d "$profile_dir/skills" ] && sync_managed_skills "$profile_dir/skills" "$target_dir/skills" "copilot-profiles/$profile_name"
      [ -f "$profile_dir/config.json" ] && cp -v "$profile_dir/config.json" "$target_dir/config.json"
      [ -f "$profile_dir/mcp-config.json" ] && cp -v "$profile_dir/mcp-config.json" "$target_dir/mcp-config.json"
    done
  fi

  # Cursor: copy Agent Skills into ~/.cursor/skills/
  CURSOR_SKILLS_DIR="$USER_HOME_DIR/.cursor/skills"
  if [ -d "$GENERATED_DIR/cursor/skills" ]; then
    sync_managed_skills "$GENERATED_DIR/cursor/skills" "$CURSOR_SKILLS_DIR" "cursor"
  fi

  # Pi uses its native default configuration directory.
  PI_SOURCE="$GENERATED_DIR/pi-agent"
  PI_TARGET="$USER_HOME_DIR/.pi/agent"
  if [ -f "$PI_SOURCE/AGENTS.md" ]; then
    mkdir -p "$PI_TARGET"
    cp -v "$PI_SOURCE/AGENTS.md" "$PI_TARGET/AGENTS.md"
    sync_managed_skills "$PI_SOURCE/skills" "$PI_TARGET/skills" pi-agent
    if [ -d "$PI_SOURCE/prompts" ]; then
      rsync_copy_dir "$PI_SOURCE/prompts" "$PI_TARGET/prompts"
    fi
  fi
else
  echo "No generated directory found at $GENERATED_DIR. Run the generator to produce generated artifacts first."
fi


# Rollout the openspec config.yaml only when explicitly requested.
echo
if [ "$ROLLOUT_OPENSPEC_CONFIG" != true ]; then
  echo "Skipping openspec config.yaml rollout. Pass --openspec-config to enable it."
  echo
  exit 0
fi

DEV_HOME_ALL="$USER_HOME_DIR/dev*"
SEARCH_ROOTS=()
if [ -n "${SMEC_PRODUCTS_HOME:-}" ] && [ -d "${SMEC_PRODUCTS_HOME}" ]; then
  SEARCH_ROOTS+=("${SMEC_PRODUCTS_HOME}")
fi

shopt -s nullglob
for dev_dir in "$USER_HOME_DIR"/dev*; do
  [ -d "$dev_dir" ] && SEARCH_ROOTS+=("$dev_dir")
done
shopt -u nullglob

if [ ${#SEARCH_ROOTS[@]} -gt 0 ]; then
  echo "Searching for existing openspec config.yaml files to update in: ${SEARCH_ROOTS[*]} ..."
  OPENSPEC_DIRS=$(find "${SEARCH_ROOTS[@]}" -type d -name "openspec" 2>/dev/null || true)
else
  echo "No search roots found (SMEC_PRODUCTS_HOME and $DEV_HOME_ALL). Skipping openspec rollout."
  OPENSPEC_DIRS=""
fi

FOUND_ANY=false
while IFS= read -r openspec_dir; do
  [ -z "$openspec_dir" ] && continue
  config_file="$openspec_dir/config.yaml"
  if [ -f "$config_file" ]; then
    if [ "$FOUND_ANY" = false ]; then
      echo "Updating existing openspec config.yaml files..."
      FOUND_ANY=true
    fi
    echo "  Copying to $config_file"
    cp "$AGENTS_SRC_DATA_DIR/openspec/config.yaml" "$config_file"
  fi
done <<< "$OPENSPEC_DIRS"
if [ "$FOUND_ANY" = false ]; then
  echo "No existing openspec config.yaml found. Skipping update."
fi
echo
