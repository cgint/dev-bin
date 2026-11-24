#!/bin/bash
# Fake-HOME test for pi_profiles_migrate.sh (sessions-only profile removal).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PROJECT_ROOT/pi_profiles_migrate.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -r "$TMP"' EXIT
H="$TMP/home"
P="$H/.pi"

mkdir -p "$P/agent/sessions/--a--" "$P/profiles/minimal/agent/sessions/--b--" \
  "$P/profiles/minimal/agent/pi-agents/sessions/x1" "$P/agent/pi-agents/sessions/y1" \
  "$P/agent/skills/colgrep" "$P/agent/skills/web-search" "$P/pi-acp"
echo '{"type":"session","id":"p1"}' >"$P/profiles/minimal/agent/sessions/--b--/p.jsonl"
echo "{\"type\":\"session\",\"id\":\"c1\",\"parentSession\":\"$P/profiles/minimal/agent/sessions/--b--/p.jsonl\"}" \
  >"$P/profiles/minimal/agent/sessions/--b--/c.jsonl"
echo '{"type":"session","id":"d1"}' >"$P/agent/sessions/--a--/d.jsonl"
echo '{"theme":"keep"}' >"$P/agent/settings.json"
echo "{\"version\":1,\"sessions\":{\"k\":{\"sessionFile\":\"$P/profiles/minimal/agent/sessions/--b--/p.jsonl\"}}}" \
  >"$P/pi-acp/session-map.json"
printf '%s\n' 'export X=1' 'alias pim="pi-profile minimal"' "alias pims='pi-profile minimal --x'" "alias pir='pi --dm-read'" >"$H/.zshrc"

run() { HOME="$H" PI_MIGRATE_PGREP="$1" "$SCRIPT" "${@:2}"; }

# Dry run (default) changes nothing.
before="$(cd "$H" && find . | sort)"
run false >"$TMP/dry.out" 2>&1 || fail "dry run failed: $(cat "$TMP/dry.out")"
[ "$(cd "$H" && find . | sort)" = "$before" ] || fail 'dry run changed files'

# Abort while pi is running.
if run true --apply >"$TMP/busy.out" 2>&1; then fail 'apply ran while pi was running'; fi
[ -d "$P/profiles" ] || fail 'abort still moved profiles'

# Apply.
run false --apply >"$TMP/apply.out" 2>&1 || fail "apply failed: $(cat "$TMP/apply.out")"
R="$(ls -d "$H"/.pi-rollback-*)"
[ ! -e "$P/profiles" ] || fail 'profiles not archived'
[ -d "$R/profiles/minimal" ] || fail 'profiles missing from rollback'
[ -f "$R/agent-sessions/--a--/d.jsonl" ] || fail 'old sessions missing from rollback'
for f in --a--/d.jsonl --b--/p.jsonl --b--/c.jsonl; do
  [ -f "$P/agent/sessions/$f" ] || fail "merged session missing: $f"
done
# merge_pi_history.py resolves the Pi home (macOS: /var -> /private/var).
P_REAL="$(cd "$P" && pwd -P)"
grep -Fq "\"parentSession\":\"$P_REAL/agent/sessions/--b--/p.jsonl\"" "$P/agent/sessions/--b--/c.jsonl" \
  || fail 'fork parent not remapped'
[ -d "$P/agent/pi-agents/sessions/x1" ] && [ -d "$P/agent/pi-agents/sessions/y1" ] || fail 'pi-agents sessions not merged'
[ -d "$R/skills/colgrep" ] && [ ! -e "$P/agent/skills/colgrep" ] || fail 'retired skill not moved'
[ -d "$P/agent/skills/web-search" ] || fail 'active skill touched'
[ "$(cat "$P/agent/settings.json")" = '{"theme":"keep"}' ] || fail 'settings changed'
grep -Fq "$P/agent/sessions/--b--/p.jsonl" "$P/pi-acp/session-map.json" || fail 'session map not rewritten'
[ -f "$R/session-map.json" ] || fail 'session map not backed up'
tar -tzf "$R/deploy-targets.tgz" | grep -q '^\.pi/agent/skills/web-search' || fail 'deploy targets not backed up'
grep -q pi-profile "$H/.zshrc" && fail 'pi-profile aliases left in .zshrc'
grep -q "alias pir=" "$H/.zshrc" || fail 'unrelated alias removed'
cmp -s "$R/zshrc.bak" <(printf '%s\n' 'export X=1' 'alias pim="pi-profile minimal"' "alias pims='pi-profile minimal --x'" "alias pir='pi --dm-read'") \
  || fail 'zshrc backup differs from original'

# Second apply refuses: profiles are gone.
if run false --apply >"$TMP/again.out" 2>&1; then fail 'second apply did not refuse'; fi

echo "PASS: pi_profiles_migrate"
