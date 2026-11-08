#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_PATH="$PROJECT_ROOT/agents_files_cp_remote.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

TMP="$(mktemp -d)"
trap 'rm -r "$TMP"' EXIT
cp "$SCRIPT_PATH" "$TMP/agents_files_cp_remote.sh"
chmod +x "$TMP/agents_files_cp_remote.sh"

# --help works on any host: the guard sits after argument parsing.
HELP_OUT="$("$TMP/agents_files_cp_remote.sh" --help 2>&1)" \
  || fail '--help did not exit 0 on a non-Mac host'
case "$HELP_OUT" in
  *"Usage: agents_files_cp_remote.sh"*) ;;
  *) fail '--help output lost its usage header' ;;
esac

# Refusal on a non-Mac host: exit 2, warning names allowed + detected host,
# and fires before any pre-flight/staging (no host TOMLs are shipped with this copy).
set +e
AGENTS_FILES_CP_HOSTNAME=pluto "$TMP/agents_files_cp_remote.sh" >"$TMP/out" 2>"$TMP/err"
RC=$?
set -e
[ "$RC" -eq 2 ] || fail "host guard: expected exit 2 on a non-Mac host, got $RC"
grep -q 'the main Mac' "$TMP/err" || fail 'host guard: warning does not mention the main Mac'
grep -q 'MacBook-Pro' "$TMP/err" || fail 'host guard: warning does not name the allowed host'
grep -q 'Detected host: pluto' "$TMP/err" || fail 'host guard: warning does not name the detected host'
if grep -q 'no host TOMLs' "$TMP/out" "$TMP/err"; then
  fail 'host guard: refusal came after the host-TOML pre-flight'
fi

# Admission on the main Mac: guard passes and the script proceeds
# (here: straight into the missing-host-TOML pre-flight error).
set +e
AGENTS_FILES_CP_HOSTNAME=MacBook-Pro "$TMP/agents_files_cp_remote.sh" >"$TMP/out2" 2>"$TMP/err2"
RC2=$?
set -e
[ "$RC2" -eq 1 ] || fail "expected post-guard pre-flight failure (exit 1), got $RC2"
grep -q 'no host TOMLs' "$TMP/err2" || fail 'guard did not admit the main Mac hostname'

printf 'PASS: agents_files_cp_remote.sh main-Mac host guard\n'
