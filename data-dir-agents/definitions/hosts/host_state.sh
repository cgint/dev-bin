#!/usr/bin/env bash
# host_state.sh — gather full pi state from one host (skills, prompts, extensions, model, pi version).
# Companion to definitions/hosts/EXTENSIONS.md (recon section).
#
# Usage: host_state.sh <host>
#   <host>  ssh alias: sparkz | sparky | twins | pluto
#
# Prints a timestamped state block. Stdout only; read-only; exits 0 even if parts fail.
set -u

HOST="${1:-}"
if [ -z "$HOST" ]; then
  echo "usage: $0 <host: sparkz|sparky|twins|pluto>" >&2
  exit 2
fi

SSH_OPTS="-o ConnectTimeout=10 -o BatchMode=yes"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "===== host state: $HOST ====="
echo "observed: $TS"

# Per-host pi invocation (as of 2026-07-09 — re-verify if PATH layouts change)
case "$HOST" in
  sparkz|sparky)
    PI_CMD='export PATH=$HOME/.nvm/versions/node/v22.22.2/bin:$PATH; pi'
    ;;
  twins)
    PI_CMD='export PATH=$HOME/.local/share/pi-node/current/bin:$HOME/.local/share/pi-node/node-v22.22.2-linux-x64/bin:$PATH; $HOME/.local/share/pi-node/current/bin/pi'
    ;;
  pluto)
    PI_CMD='/home/cgint/.local/bin/pi'
    ;;
  *)
    echo "[error] unknown host: $HOST (add its pi invocation to this script)"
    exit 2
    ;;
esac

echo
echo "--- pi version ---"
ssh $SSH_OPTS "$HOST" "$PI_CMD --version 2>&1" || echo "[UNREACHABLE or pi missing]"

echo
echo "--- skills (dirs under ~/.pi/agent/skills/) ---"
ssh $SSH_OPTS "$HOST" 'ls ~/.pi/agent/skills/ 2>/dev/null | sort' || echo "[UNREACHABLE]"

echo
echo "--- prompts (files under ~/.pi/agent/prompts/) ---"
ssh $SSH_OPTS "$HOST" 'ls ~/.pi/agent/prompts/ 2>/dev/null | sort' || echo "[UNREACHABLE]"

echo
echo "--- extensions: pi list ---"
ssh $SSH_OPTS "$HOST" "$PI_CMD list 2>&1" || echo "[UNREACHABLE]"

echo
echo "--- extensions: live registry (packages array in settings.json) ---"
ssh $SSH_OPTS "$HOST" "python3 -c \"import json;print(json.dumps(json.load(open('/home/cgint/.pi/agent/settings.json')).get('packages',[]),indent=1))\" 2>&1" || echo "[UNREACHABLE or no python3/settings.json]"

echo
echo "--- model config (provider/model/thinking) ---"
ssh $SSH_OPTS "$HOST" "grep -E 'defaultProvider|defaultModel|thinking' /home/cgint/.pi/agent/settings.json 2>/dev/null || echo '(none set)'" || echo "[UNREACHABLE]"

echo
echo "--- loose extensions (~/.pi/agent/extensions/, untracked) ---"
ssh $SSH_OPTS "$HOST" 'ls ~/.pi/agent/extensions/ 2>/dev/null || echo "(none)"' || echo "[UNREACHABLE]"

echo
echo "===== end $HOST ====="
