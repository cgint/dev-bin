#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFINITIONS_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RUNTIME="$DEFINITIONS_DIR/runtime/pi-worker-runtime.sh"
CMUX_ADAPTER="$DEFINITIONS_DIR/skills/sub-agent-cmux-supervisor/scripts/cmux-worker.sh"
HERDR_ADAPTER="$SCRIPT_DIR/herdr-worker.sh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -r "$TMPDIR_TEST"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$TMPDIR_TEST/bin" "$TMPDIR_TEST/home/.pi/profiles/partner/agent/extensions"
: >"$TMPDIR_TEST/home/.pi/profiles/partner/agent/extensions/herdr-agent-state.ts"
cat >"$TMPDIR_TEST/bin/pi-profile" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2 $3 $4" == "partner auth check --provider" ]]; then
  printf 'ready\n'
  exit 0
fi
printf 'PI_WRITE_GUARD_DIRS=%s\n' "${PI_WRITE_GUARD_DIRS:-}" >"$PI_PROFILE_CAPTURE"
printf '%s\n' "$@" >>"$PI_PROFILE_CAPTURE"
EOF
chmod +x "$TMPDIR_TEST/bin/pi-profile"

compose_skill() {
  local name="$1"
  local adapter="$2"
  local package="$TMPDIR_TEST/$name/scripts"
  mkdir -p "$package"
  cp "$adapter" "$package/worker.sh"
  cp "$RUNTIME" "$package/pi-worker-runtime.sh"
  chmod +x "$package/worker.sh"
  printf '%s\n' "$package/worker.sh"
}

cmux_worker="$(compose_skill cmux "$CMUX_ADAPTER")"
herdr_worker="$(compose_skill herdr "$HERDR_ADAPTER")"

run_worker() {
  local worker="$1"
  local capture="$2"
  PATH="$TMPDIR_TEST/bin:$PATH" HOME="$TMPDIR_TEST/home" PI_PROFILE_CAPTURE="$capture" \
    "$worker" --mode readonly -- @/tmp/handoff.md 'Execute the bounded task.'
}

cmux_capture="$TMPDIR_TEST/cmux.txt"
run_worker "$cmux_worker" "$cmux_capture"
grep -qx 'PI_WRITE_GUARD_DIRS=\.' "$cmux_capture" || fail 'CMUX worker did not set the cwd write guard'
grep -qx -- '--tools' "$cmux_capture" || fail 'CMUX worker omitted read-only tool restriction'
grep -qx 'read,bash,grep,find,ls' "$cmux_capture" || fail 'CMUX worker omitted classified read-only tools'
grep -qx -- '--dm-read' "$cmux_capture" || fail 'CMUX worker omitted read-only mode'
if grep -q 'herdr-agent-state.ts' "$cmux_capture"; then
  fail 'CMUX worker loaded Herdr reporting behavior'
fi

herdr_capture="$TMPDIR_TEST/herdr.txt"
run_worker "$herdr_worker" "$herdr_capture"
grep -qx 'PI_WRITE_GUARD_DIRS=\.' "$herdr_capture" || fail 'Herdr worker did not set the cwd write guard'
grep -qx "$TMPDIR_TEST/home/.pi/profiles/partner/agent/extensions/herdr-agent-state.ts" "$herdr_capture" \
  || fail 'Herdr worker omitted its lifecycle reporter'

if override_output="$(PATH="$TMPDIR_TEST/bin:$PATH" HOME="$TMPDIR_TEST/home" PI_PROFILE_CAPTURE="$TMPDIR_TEST/override.txt" "$cmux_worker" --mode editable -- --model unsafe 2>&1)"; then
  fail 'CMUX worker accepted a caller model override'
fi
grep -q 'caller may not override launcher configuration: --model' <<<"$override_output" \
  || fail 'CMUX worker did not explain the rejected override'

printf 'PASS: self-contained CMUX and Herdr worker launcher contracts\n'
