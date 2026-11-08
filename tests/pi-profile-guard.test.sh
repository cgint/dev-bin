#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_PATH="$PROJECT_ROOT/pi-profile"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

TMP="$(mktemp -d)"
trap 'rm -r "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home"
cp "$SCRIPT_PATH" "$TMP/bin/pi-profile"
chmod +x "$TMP/bin/pi-profile"

# pi shim: records every invocation instead of starting a real agent.
cat >"$TMP/bin/pi" <<'EOF'
#!/bin/bash
printf 'PI: PI_CODING_AGENT_DIR=%s args=%s\n' "${PI_CODING_AGENT_DIR:-}" "$*" >>"${PI_CAPTURE:-/dev/null}"
EOF
chmod +x "$TMP/bin/pi"
export PATH="$TMP/bin:$PATH"
export PI_CAPTURE="$TMP/captured"
: >"$PI_CAPTURE"

export HOME="$TMP/home"
PROFILES="$HOME/.pi/profiles"

# fixtures: deployed default + named profile, and a bare stub (mirrors the
# 2026-11-08 16:25 event: mkdir -p .../agent/extensions only, no AGENTS.md)
mkdir -p "$HOME/.pi/agent"
printf 'main\n' >"$HOME/.pi/agent/AGENTS.md"
mkdir -p "$PROFILES/deployed/agent"
printf 'x\n' >"$PROFILES/deployed/agent/AGENTS.md"
mkdir -p "$PROFILES/stub/agent/extensions"
printf 'x\n' >"$PROFILES/stub/agent/extensions/herdr-agent-state.ts"

# 1. nonexistent profile: refuse, and the start attempt must not create it
if "$TMP/bin/pi-profile" ghost --version 2>"$TMP/err"; then
  fail 'nonexistent profile was not refused'
fi
[ ! -e "$PROFILES/ghost" ] || fail 'starting an undeployed profile created its directory'
if grep -q '^PI:' "$PI_CAPTURE"; then fail 'nonexistent profile: pi was started'; fi

# 2. bare stub dir (no AGENTS.md): refuse, pi must not start, nothing initialized
if "$TMP/bin/pi-profile" stub --version 2>"$TMP/err2"; then
  fail 'stub profile (dir without AGENTS.md) was not refused'
fi
[ ! -e "$PROFILES/stub/agent/auth.json" ] || fail 'stub profile: pi initialized the data dir'
[ ! -e "$PROFILES/stub/agent/models-store.json" ] || fail 'stub profile: pi wrote models-store.json'
if grep -q '^PI:' "$PI_CAPTURE"; then fail 'stub profile: pi was started'; fi

# 3. deployed named profile: admitted, pi runs with the profile agent dir
"$TMP/bin/pi-profile" deployed --version
grep -q "PI_CODING_AGENT_DIR=$PROFILES/deployed/agent" "$PI_CAPTURE" \
  || fail 'deployed profile: pi did not run with the profile agent dir'

# 4. default profile: admitted, pi runs with the main agent dir
: >"$PI_CAPTURE"
"$TMP/bin/pi-profile" default --version
grep -q "PI_CODING_AGENT_DIR=$HOME/.pi/agent" "$PI_CAPTURE" \
  || fail 'default profile: pi did not run with the main agent dir'

# 5. --list shows only deployed profiles (no stub)
if "$TMP/bin/pi-profile" --list | grep -q 'stub'; then
  fail '--list advertised an undeployed stub profile'
fi
"$TMP/bin/pi-profile" --list | grep -q 'deployed' || fail '--list lost the deployed profile'

# 6. --update-all touches only deployed profiles (default + deployed, never the stub)
: >"$PI_CAPTURE"
"$TMP/bin/pi-profile" --update-all >/dev/null
grep -Eq "PI_CODING_AGENT_DIR=$PROFILES/stub/+agent" "$PI_CAPTURE" \
  && fail '--update-all updated an undeployed stub profile'
grep -Eq "PI_CODING_AGENT_DIR=$PROFILES/deployed/+agent" "$PI_CAPTURE" \
  || fail '--update-all skipped the deployed profile'
grep -q "PI_CODING_AGENT_DIR=$HOME/.pi/agent" "$PI_CAPTURE" \
  || fail '--update-all skipped the default profile'

printf 'PASS: pi-profile refuses undeployed profiles; starting never creates them\n'
