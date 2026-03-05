#!/usr/bin/env bash

set -euo pipefail

# pi-setup.sh
#
# Bootstrap @mariozechner/pi-coding-agent ("pi") on macOS using Homebrew and
# deploy the company pi agent configuration (AGENTS/skills/prompts/profiles)
# from devsupport-solution/workspace-tools.
#
# Policy (company-safe):
#   - Only install Node if node is missing.
#   - If Node exists but is < 20: warn only (do not auto-upgrade).

log()  { printf "%s\n" "$*"; }
warn() { printf "WARNING: %s\n" "$*" >&2; }
die()  { printf "ERROR: %s\n" "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  pi-setup.sh [--dry-run]

Options:
  --dry-run   Print what would be executed, but do not change the system
  -h,--help   Show this help

Notes:
  - Installs Node via Homebrew only if 'node' is missing.
  - Installs pi via: npm install -g @mariozechner/pi-coding-agent
  - Generates agent artifacts via propagate_definitions.py --apply
  - Deploys pi-agent profiles (generated/pi-agent-profiles/*) if available.
    Otherwise falls back to generated/pi-agent -> ~/.pi/agent.
EOF
}

DRY_RUN=0
while [ ${#} -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1 (use --help)" ;;
  esac
done

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    log "+ $*"
    return 0
  fi
  "$@"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

# --- Locate workspace-tools ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If this script is located in .../workspace-tools/bin, this resolves correctly.
WORKSPACE_TOOLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Otherwise (e.g. you run a copy from ~/.local/bin), try SMEC_PRODUCTS_HOME.
if [ ! -d "$WORKSPACE_TOOLS_DIR/agentic-coding/data-dir-agents" ]; then
  if [ -n "${SMEC_PRODUCTS_HOME:-}" ] && [ -d "${SMEC_PRODUCTS_HOME}/devsupport-solution/workspace-tools" ]; then
    WORKSPACE_TOOLS_DIR="${SMEC_PRODUCTS_HOME}/devsupport-solution/workspace-tools"
  fi
fi

[ -d "$WORKSPACE_TOOLS_DIR" ] || die "workspace-tools directory not found"
[ -d "$WORKSPACE_TOOLS_DIR/agentic-coding/data-dir-agents" ] || die "Expected agentic-coding/data-dir-agents under: $WORKSPACE_TOOLS_DIR"

DATA_DIR="$WORKSPACE_TOOLS_DIR/agentic-coding/data-dir-agents"
GENERATOR="$DATA_DIR/propagate_definitions.py"
GENERATED_DIR="$DATA_DIR/generated"

log
log "Using workspace-tools: $WORKSPACE_TOOLS_DIR"
log "Using data-dir-agents: $DATA_DIR"
[ "$DRY_RUN" -eq 1 ] && log "Mode: DRY-RUN"
log

# --- Prerequisites ---
need_cmd brew

if ! command -v node >/dev/null 2>&1; then
  log "Node.js not found. Installing via Homebrew..."
  run brew install node
else
  NODE_VERSION_RAW="$(node -v 2>/dev/null || true)"
  NODE_VERSION="${NODE_VERSION_RAW#v}"
  NODE_MAJOR="${NODE_VERSION%%.*}"
  if [[ "$NODE_MAJOR" =~ ^[0-9]+$ ]] && [ "$NODE_MAJOR" -lt 20 ]; then
    warn "Detected node $NODE_VERSION_RAW (< 20). pi requires Node >= 20. We will not upgrade automatically."
  fi
fi

need_cmd npm

# Python is needed for the generator.
if ! command -v python3 >/dev/null 2>&1; then
  log "python3 not found. Installing via Homebrew..."
  run brew install python
fi

need_cmd rsync

# --- Install pi ---
log
log "Installing pi (npm global): @mariozechner/pi-coding-agent"
log "(This may update an existing installation.)"
log
run npm install -g @mariozechner/pi-coding-agent

if [ "$DRY_RUN" -eq 0 ]; then
  if command -v pi >/dev/null 2>&1; then
    log
    pi --version || true
  else
    PREFIX="$(npm prefix -g 2>/dev/null || true)"
    warn "'pi' command not found on PATH after npm install."
    if [ -n "$PREFIX" ]; then
      warn "Try adding this to your shell PATH: $PREFIX/bin"
    fi
    die "pi installation did not result in a usable 'pi' command"
  fi
fi

# --- Generate artifacts ---
log
log "Generating agent artifacts..."
[ -f "$GENERATOR" ] || die "Generator not found: $GENERATOR"
run python3 "$GENERATOR" --apply

# --- Deploy company pi-agent configuration ---
log
log "Deploying pi agent configuration..."
run mkdir -p "$HOME/.pi/agent"

expand_tilde() {
  local p="$1"
  printf "%s" "${p/#\~/$HOME}"
}

deploy_profile_dir() {
  local profile_dir="$1"
  local profile_name
  profile_name="$(basename "$profile_dir")"

  local target_dir
  target_dir="$(cat "$profile_dir/.target" 2>/dev/null || true)"
  target_dir="$(expand_tilde "$target_dir")"

  if [ -z "$target_dir" ]; then
    warn "Skipping profile '$profile_name': empty target dir"
    return 0
  fi

  run mkdir -p "$target_dir"

  log "- profile '$profile_name' -> $target_dir"
  [ -f "$profile_dir/AGENTS.md" ] && run cp -v "$profile_dir/AGENTS.md" "$target_dir/AGENTS.md"
  [ -d "$profile_dir/skills" ] && run rsync -avh "$profile_dir/skills/" "$target_dir/skills/"
  [ -d "$profile_dir/prompts" ] && run rsync -avh "$profile_dir/prompts/" "$target_dir/prompts/"
}

PI_PROFILES_GENERATED="$GENERATED_DIR/pi-agent-profiles"

if [ -d "$PI_PROFILES_GENERATED" ]; then
  shopt -s nullglob
  profile_dirs=("$PI_PROFILES_GENERATED"/*)
  shopt -u nullglob

  if [ ${#profile_dirs[@]} -eq 0 ]; then
    warn "No profiles found in $PI_PROFILES_GENERATED."
  else
    for d in "${profile_dirs[@]}"; do
      [ -d "$d" ] || continue
      deploy_profile_dir "$d"
    done
  fi
else
  warn "No generated pi-agent profiles found ($PI_PROFILES_GENERATED missing). Falling back to generated/pi-agent -> ~/.pi/agent"

  PI_AGENT_GENERATED="$GENERATED_DIR/pi-agent"
  [ -d "$PI_AGENT_GENERATED" ] || die "Expected generated pi-agent directory not found: $PI_AGENT_GENERATED"

  [ -f "$PI_AGENT_GENERATED/AGENTS.md" ] && run cp -v "$PI_AGENT_GENERATED/AGENTS.md" "$HOME/.pi/agent/AGENTS.md"
  [ -d "$PI_AGENT_GENERATED/skills" ] && run rsync -avh "$PI_AGENT_GENERATED/skills/" "$HOME/.pi/agent/skills/"
  [ -d "$PI_AGENT_GENERATED/prompts" ] && run rsync -avh "$PI_AGENT_GENERATED/prompts/" "$HOME/.pi/agent/prompts/"
fi

log
log "Done. Next steps (company standard: GitHub Copilot):"
log "  1) Start pi:"
log "       pi"
log "  2) In pi, login and select GitHub Copilot:"
log "       /login"
log "       (then choose: GitHub Copilot)"
log "  3) Domain: press Enter for github.com (or enter your GitHub Enterprise domain)"
log "  4) Complete the browser/device login flow"
log ""
log "Notes:"
log "  - Credentials are stored in: ~/.pi/agent/auth.json (auto-refreshes)"
log "  - If you see 'model not supported': enable the model in VS Code"
log "    (Copilot Chat -> model selector -> select model -> Enable)"
log
