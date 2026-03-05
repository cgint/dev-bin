#!/bin/bash

set -euo pipefail

usage() {
  echo "Usage: $0 [--delete]"
  echo
  echo "Options:"
  echo "  --delete    remove files in the target rsync dirs that are no longer in source"
  echo "  -h, --help  show this help"
}

DELETE_RSYNC=false
for arg in "$@"; do
  case "$arg" in
    --delete)
      DELETE_RSYNC=true
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

RSYNC_OPTS=(-avh)
if [ "$DELETE_RSYNC" = true ]; then
  RSYNC_OPTS+=(--delete)
fi

rsync_copy_dir() {
  local src_dir="$1"
  local dest_dir="$2"
  mkdir -p "$dest_dir"
  rsync "${RSYNC_OPTS[@]}" "$src_dir/" "$dest_dir/"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_SRC_DATA_DIR="$SCRIPT_DIR/data-dir-agents"
USER_HOME_DIR="$HOME"

GENERATED_DIR="$AGENTS_SRC_DATA_DIR/generated"

GEMINI_AGENTS_DIR="$USER_HOME_DIR/.gemini"
CODEX_AGENTS_DIR="$USER_HOME_DIR/.codex"
COPILOT_AGENTS_DIR="$USER_HOME_DIR/.copilot"

GEMINI_AGENTS_FILE="$GEMINI_AGENTS_DIR/GEMINI.md"
CODEX_AGENTS_FILE="$CODEX_AGENTS_DIR/AGENTS.md"
COPILOT_AGENTS_FILE="$COPILOT_AGENTS_DIR/copilot-instructions.md"

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
  # Gemini: copy GEMINI.md + commands + skills into ~/.gemini/
  if [ -d "$GEMINI_AGENTS_DIR" ] && [ -f "$GENERATED_DIR/gemini/GEMINI.md" ]; then
    mkdir -p "$GEMINI_AGENTS_DIR"
    cp -v "$GENERATED_DIR/gemini/GEMINI.md" "$GEMINI_AGENTS_FILE"
  fi
  if [ -d "$GEMINI_AGENTS_DIR" ] && [ -d "$GENERATED_DIR/gemini/commands" ]; then
    rsync_copy_dir "$GENERATED_DIR/gemini/commands" "$GEMINI_AGENTS_DIR/commands"
  fi
  if [ -d "$GEMINI_AGENTS_DIR" ] && [ -d "$GENERATED_DIR/gemini/skills" ]; then
    rsync_copy_dir "$GENERATED_DIR/gemini/skills" "$GEMINI_AGENTS_DIR/skills"
  fi

  # Codex: copy AGENTS.md into ~/.codex/AGENTS.md
  if [ -d "$CODEX_AGENTS_DIR" ] && [ -f "$GENERATED_DIR/codex/AGENTS.md" ]; then
    mkdir -p "$CODEX_AGENTS_DIR"
    cp -v "$GENERATED_DIR/codex/AGENTS.md" "$CODEX_AGENTS_FILE"
  fi

  # Copilot: copy combined file into ~/.copilot/ plus Agent Skills
  if [ -d "$COPILOT_AGENTS_DIR" ]; then
    mkdir -p "$COPILOT_AGENTS_DIR"
    if [ -f "$GENERATED_DIR/copilot/copilot-instructions.md" ]; then
      cp -v "$GENERATED_DIR/copilot/copilot-instructions.md" "$COPILOT_AGENTS_FILE"
    fi
    if [ -d "$GENERATED_DIR/copilot/skills" ]; then
      rsync_copy_dir "$GENERATED_DIR/copilot/skills" "$COPILOT_AGENTS_DIR/skills"
    fi
  fi

  # Cursor: copy Agent Skills into ~/.cursor/skills/
  CURSOR_SKILLS_DIR="$USER_HOME_DIR/.cursor/skills"
  if [ -d "$GENERATED_DIR/cursor/skills" ]; then
    rsync_copy_dir "$GENERATED_DIR/cursor/skills" "$CURSOR_SKILLS_DIR"
  fi

  # pi-agent profiles: deploy each generated profile to its configured target dir
  PI_PROFILES_GENERATED="$GENERATED_DIR/pi-agent-profiles"
  if [ -d "$PI_PROFILES_GENERATED" ]; then
    for profile_dir in "$PI_PROFILES_GENERATED"/*/; do
      profile_name=$(basename "$profile_dir")
      target_dir=$(cat "$profile_dir/.target" 2>/dev/null || true)
      target_dir="${target_dir/#\~/$HOME}"
      if [ -z "$target_dir" ]; then
        echo " -- Skipping pi-agent profile '$profile_name': target dir is empty"
        continue
      fi
      if [ ! -d "$target_dir" ]; then
        echo " -- Creating target dir for pi-agent profile '$profile_name': $target_dir"
        mkdir -p "$target_dir"
      fi
      echo " -- Deploying pi-agent profile '$profile_name' -> $target_dir ... (if no output then everything is up to date)"
      [ -f "$profile_dir/AGENTS.md" ] && cp -v "$profile_dir/AGENTS.md" "$target_dir/AGENTS.md"
      [ -d "$profile_dir/skills" ] && rsync_copy_dir "$profile_dir/skills" "$target_dir/skills"
      [ -d "$profile_dir/prompts" ] && rsync_copy_dir "$profile_dir/prompts" "$target_dir/prompts"
    done
  fi
else
  echo "No generated directory found at $GENERATED_DIR. Run the generator to produce generated artifacts first."
fi

# NOTE: pi-agent deployment is fully profile-driven via definitions/profiles/pi-agent/*.toml.
# Canonical sources live under $AGENTS_SRC_DATA_DIR/definitions and are deployed via generated artifacts.


# Rollout the openspec config.yaml
echo
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