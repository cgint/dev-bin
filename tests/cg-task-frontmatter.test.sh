#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CG_TASK_SRC="$PROJECT_ROOT/cg-task.sh"
TASK_DEFAULTS_SRC="$PROJECT_ROOT/cg-task/defaults"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "expected output to contain: $needle"$'\n'"actual output:"$'\n'"$haystack"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    fail "expected output to NOT contain: $needle"$'\n'"actual output:"$'\n'"$haystack"
  fi
}

setup_fixture_dir() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  mkdir -p "$tmp_dir/bin/cg-task/defaults" "$tmp_dir/state" "$tmp_dir/work"
  cp "$CG_TASK_SRC" "$tmp_dir/bin/cg-task.sh"
  chmod +x "$tmp_dir/bin/cg-task.sh"
  cp "$TASK_DEFAULTS_SRC"/*.txt "$tmp_dir/bin/cg-task/defaults/"
  echo "$tmp_dir"
}

make_codegiant_stub() {
  local tmp_dir="$1"

  cat >"$tmp_dir/bin/codegiant.py" <<'EOF'
#!/bin/bash
set -euo pipefail

STATE_DIR="${TEST_STATE_DIR:?}"

printf '%s\n' "$@" >"$STATE_DIR/args.log"

out_file=""
prompt_file=""
diff_file=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      out_file="$2"
      shift 2
      ;;
    -f)
      prompt_file="$2"
      shift 2
      ;;
    -a)
      if [ "$(basename "$2")" = ".__cg_should_not_match" ]; then
        :
      fi
      if [ "$(basename "$2")" = "._cg_tmp_diff.txt" ]; then
        diff_file="$2"
      fi
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ -n "$prompt_file" ]; then
  cat "$prompt_file" >"$STATE_DIR/prompt.log"
fi

if [ -n "$diff_file" ]; then
  cat "$diff_file" >"$STATE_DIR/diff.log"
fi

if [ -n "$out_file" ]; then
  printf 'stub output\n' >"$out_file"
fi
EOF
  chmod +x "$tmp_dir/bin/codegiant.py"
}

run_task() {
  local tmp_dir="$1"
  shift

  (
    cd "$tmp_dir/work"
    PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" TEST_STATE_DIR="$tmp_dir/state" "$tmp_dir/bin/cg-task.sh" "$@"
  )
}

test_frontmatter_context_task_strips_header_and_maps_scope_flags() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'rm -rf "$tmp_dir"' RETURN

  make_codegiant_stub "$tmp_dir"

  local output
  output="$(run_task "$tmp_dir" explore-prep "focus on task format")"

  assert_contains "$output" "Written to: cg-task-result-explore-prep.md"

  local args_log
  args_log="$(cat "$tmp_dir/state/args.log")"
  assert_contains "$args_log" "-d"
  assert_contains "$args_log" "src"
  assert_contains "$args_log" "tests"
  assert_contains "$args_log" "docs"
  assert_contains "$args_log" "openspec"
  assert_contains "$args_log" "-x"
  assert_contains "$args_log" "archive"
  assert_contains "$args_log" "screenshots"
  assert_contains "$args_log" "AGENTS.md"
  assert_contains "$args_log" ".env.example"

  local prompt_log
  prompt_log="$(cat "$tmp_dir/state/prompt.log")"
  assert_contains "$prompt_log" "Prepare a structured exploration brief"
  assert_contains "$prompt_log" "**Additional focus:** focus on task format"
  assert_not_contains "$prompt_log" "---"
  assert_not_contains "$prompt_log" "scan-dirs:"
  assert_not_contains "$prompt_log" "ignore-dirs:"
}

test_frontmatter_body_can_contain_horizontal_rule_after_frontmatter() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'rm -rf "$tmp_dir"' RETURN

  make_codegiant_stub "$tmp_dir"
  mkdir -p "$tmp_dir/work/codegiant-tasks"
  cat >"$tmp_dir/work/codegiant-tasks/rule-body.txt" <<'EOF'
---
mode: context
scan-dirs: "src"
---
First paragraph.
---
Second paragraph.
EOF

  local output
  output="$(run_task "$tmp_dir" rule-body)"

  assert_contains "$output" "Written to: cg-task-result-rule-body.md"

  local prompt_log
  prompt_log="$(cat "$tmp_dir/state/prompt.log")"
  assert_contains "$prompt_log" "First paragraph."
  assert_contains "$prompt_log" "---"
  assert_contains "$prompt_log" "Second paragraph."
  assert_not_contains "$prompt_log" "mode: context"
}

test_legacy_header_task_is_not_discovered() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'rm -rf "$tmp_dir"' RETURN

  make_codegiant_stub "$tmp_dir"
  mkdir -p "$tmp_dir/work/codegiant-tasks"
  cat >"$tmp_dir/work/codegiant-tasks/legacy-only.txt" <<'EOF'
# codegiant: mode=context
Legacy body.
EOF
  cat >"$tmp_dir/work/codegiant-tasks/valid-local.txt" <<'EOF'
---
mode: context
---
Valid local body.
EOF

  local output
  output="$(run_task "$tmp_dir" 2>&1 || true)"
  assert_contains "$output" "valid-local"
  assert_not_contains "$output" "legacy-only"

  local legacy_output
  legacy_output="$(run_task "$tmp_dir" legacy-only 2>&1 || true)"
  assert_contains "$legacy_output" "Unknown task: legacy-only"
}

test_unterminated_frontmatter_task_is_not_discovered() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'rm -rf "$tmp_dir"' RETURN

  make_codegiant_stub "$tmp_dir"
  mkdir -p "$tmp_dir/work/codegiant-tasks"
  cat >"$tmp_dir/work/codegiant-tasks/broken.txt" <<'EOF'
---
mode: context
Broken body without closing marker.
EOF
  cat >"$tmp_dir/work/codegiant-tasks/valid-local.txt" <<'EOF'
---
mode: context
---
Valid local body.
EOF

  local output
  output="$(run_task "$tmp_dir" 2>&1 || true)"
  assert_contains "$output" "valid-local"
  assert_not_contains "$output" "broken"

  local broken_output
  broken_output="$(run_task "$tmp_dir" broken 2>&1 || true)"
  assert_contains "$broken_output" "Unknown task: broken"
}

test_legacy_frontmatter_keys_are_not_discovered() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'rm -rf "$tmp_dir"' RETURN

  make_codegiant_stub "$tmp_dir"
  mkdir -p "$tmp_dir/work/codegiant-tasks"
  cat >"$tmp_dir/work/codegiant-tasks/oldkeys.txt" <<'EOF'
---
mode: context
dirs: "src tests"
xdirs: "archive"
---
Body.
EOF
  cat >"$tmp_dir/work/codegiant-tasks/valid-local.txt" <<'EOF'
---
mode: context
---
Valid local body.
EOF

  local output
  output="$(run_task "$tmp_dir" 2>&1 || true)"
  assert_contains "$output" "valid-local"
  assert_not_contains "$output" "oldkeys"

  local oldkeys_output
  oldkeys_output="$(run_task "$tmp_dir" oldkeys 2>&1 || true)"
  assert_contains "$oldkeys_output" "Unknown task: oldkeys"
}

test_frontmatter_without_mode_is_not_discovered() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'rm -rf "$tmp_dir"' RETURN

  make_codegiant_stub "$tmp_dir"
  mkdir -p "$tmp_dir/work/codegiant-tasks"
  cat >"$tmp_dir/work/codegiant-tasks/nomode.txt" <<'EOF'
---
scan-dirs: "src"
---
Body.
EOF
  cat >"$tmp_dir/work/codegiant-tasks/valid-local.txt" <<'EOF'
---
mode: context
---
Valid local body.
EOF

  local output
  output="$(run_task "$tmp_dir" 2>&1 || true)"
  assert_contains "$output" "valid-local"
  assert_not_contains "$output" "nomode"

  local nomode_output
  nomode_output="$(run_task "$tmp_dir" nomode 2>&1 || true)"
  assert_contains "$nomode_output" "Unknown task: nomode"
}

test_frontmatter_diff_context_task_attaches_diff_and_strips_header() {
  local tmp_dir
  tmp_dir="$(setup_fixture_dir)"
  trap 'rm -rf "$tmp_dir"' RETURN

  make_codegiant_stub "$tmp_dir"

  (
    cd "$tmp_dir/work"
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    printf 'old line\n' >tracked.txt
    git add tracked.txt
    git commit -qm "init"
    printf 'new line\n' >tracked.txt
  )

  local output
  output="$(run_task "$tmp_dir" document-review)"

  assert_contains "$output" "Written to: cg-task-result-document-review.md"

  local args_log
  args_log="$(cat "$tmp_dir/state/args.log")"
  assert_contains "$args_log" "-a"
  assert_contains "$args_log" "./cg-task-result-document-review.md"

  local diff_log
  diff_log="$(cat "$tmp_dir/state/diff.log")"
  assert_contains "$diff_log" "diff --git"
  assert_contains "$diff_log" "+new line"

  local prompt_log
  prompt_log="$(cat "$tmp_dir/state/prompt.log")"
  assert_contains "$prompt_log" "Review the document changes"
  assert_not_contains "$prompt_log" "check_ut: yes"
  assert_not_contains "$prompt_log" "ext:"
  assert_not_contains "$prompt_log" "---"
}

test_frontmatter_context_task_strips_header_and_maps_scope_flags
test_frontmatter_body_can_contain_horizontal_rule_after_frontmatter
test_legacy_header_task_is_not_discovered
test_unterminated_frontmatter_task_is_not_discovered
test_legacy_frontmatter_keys_are_not_discovered
test_frontmatter_without_mode_is_not_discovered
test_frontmatter_diff_context_task_attaches_diff_and_strips_header

echo "PASS: cg-task-frontmatter"
