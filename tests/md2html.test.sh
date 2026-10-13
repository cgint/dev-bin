#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_PATH="$PROJECT_ROOT/md2html"
# Must match the reader passed to pandoc in md2html.
PANDOC_READER='markdown+lists_without_preceding_blankline-blank_before_blockquote'

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

setup_fixture_dir() {
  mktemp -d
}

cleanup_fixture_dir() {
  local tmp_dir="$1"
  rm -rf "$tmp_dir"
}

test_help_flag_short() {
  local output exit_status
  set +e
  output="$("$SCRIPT_PATH" -h 2>&1)"
  exit_status=$?
  set -e

  [[ "$exit_status" -eq 0 ]] || fail "expected zero exit status for -h, got $exit_status"
  assert_contains "$output" "Usage: md2html [options] <file.md>"
  assert_contains "$output" "beautifully styled HTML"
  assert_contains "$output" "-h, --help"
  assert_contains "$output" "GitHub-style lists and blockquotes directly after a text line"
  assert_contains "$output" "a line starting with \"- \" right after prose becomes a list item"
}

test_help_flag_long() {
  local output exit_status
  set +e
  output="$("$SCRIPT_PATH" --help 2>&1)"
  exit_status=$?
  set -e

  [[ "$exit_status" -eq 0 ]] || fail "expected zero exit status for --help, got $exit_status"
  assert_contains "$output" "Usage: md2html [options] <file.md>"
  assert_contains "$output" "beautifully styled HTML"
  assert_contains "$output" "-h, --help"
}

test_no_arguments() {
  local output exit_status
  set +e
  output="$("$SCRIPT_PATH" 2>&1)"
  exit_status=$?
  set -e

  [[ "$exit_status" -eq 1 ]] || fail "expected exit status 1 for no args, got $exit_status"
  assert_contains "$output" "Usage: md2html [options] <file.md>"
}

test_too_many_arguments() {
  local output exit_status
  set +e
  output="$("$SCRIPT_PATH" arg1 arg2 2>&1)"
  exit_status=$?
  set -e

  [[ "$exit_status" -eq 1 ]] || fail "expected exit status 1 for multiple args, got $exit_status"
  assert_contains "$output" "Usage: md2html [options] <file.md>"
}

test_successful_conversion() {
  local tmp_dir output exit_status
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN

  echo "# Test Title" > "$tmp_dir/test.md"
  echo "This is some test markdown." >> "$tmp_dir/test.md"

  set +e
  output="$("$SCRIPT_PATH" "$tmp_dir/test.md" 2>&1)"
  exit_status=$?
  set -e

  [[ "$exit_status" -eq 0 ]] || fail "expected successful conversion, got $exit_status"
  [[ -f "$tmp_dir/test.html" ]] || fail "expected output html file to be created"
  
  local html_content
  html_content="$(cat "$tmp_dir/test.html")"
  assert_contains "$html_content" "Test Title"
  assert_contains "$html_content" "This is some test markdown."
  assert_contains "$output" "→ $tmp_dir/test.html"
}

test_open_option() {
  local tmp_dir output exit_status
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN

  # Create a stub 'open' command that writes to a file when called
  mkdir -p "$tmp_dir/bin"
  cat >"$tmp_dir/bin/open" <<'EOF'
#!/bin/bash
echo "MOCKED_OPEN_CALLED: $1" > "$TEST_OPEN_CALL_LOG"
EOF
  chmod +x "$tmp_dir/bin/open"

  echo "# Test Title" > "$tmp_dir/test.md"
  
  export TEST_OPEN_CALL_LOG="$tmp_dir/open_call.log"
  set +e
  output="$(PATH="$tmp_dir/bin:$PATH" "$SCRIPT_PATH" --open "$tmp_dir/test.md" 2>&1)"
  exit_status=$?
  set -e

  [[ "$exit_status" -eq 0 ]] || fail "expected successful conversion with --open, got $exit_status"
  [[ -f "$tmp_dir/test.html" ]] || fail "expected output html file to be created"
  [[ -f "$tmp_dir/open_call.log" ]] || fail "expected mocked open command to be called"
  
  local open_log_content
  open_log_content="$(cat "$tmp_dir/open_call.log")"
  assert_contains "$open_log_content" "MOCKED_OPEN_CALLED: $tmp_dir/test.html"
}

# Count literal occurrences of $2 in string $1 (0 when none).
count_of() {
  local n
  n="$(printf '%s' "$1" | grep -o -F -- "$2" | wc -l | tr -d ' ')" || true
  echo "${n:-0}"
}

# Pandoc baseline: same flags as md2html but the default markdown reader and no pre-pass.
# The -B style block is extracted from the script itself, so the comparison uses the real style.
baseline_html() {
  local src="$1" out="$2" style title
  style="$(dirname "$out")/baseline-style.html"
  awk "/cat <<'EOF'/{f=1; next} /^EOF\$/{f=0} f" "$SCRIPT_PATH" > "$style"
  [[ -s "$style" ]] || fail "could not extract style block from $SCRIPT_PATH"
  title="$(basename "$src" .md)"
  pandoc -s --metadata colorlinks=true --metadata title="$title" \
    --syntax-highlighting=tango -B "$style" "$src" -o "$out"
}

# Table after a text line with no blank line: one blank line is inserted, so a real table renders.
test_table_after_text_gets_blank_line() {
  local tmp_dir src original html baseline
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN

  src="$tmp_dir/case.md"
  cat >"$src" <<'MD'
# Plan

**Agenda (maps onto the invite):**
| Time | Item | Output |
|---|---|---|
| 0–5 | **Purpose** | shared purpose |
| 5–27 | **Round** | raw list |

After the table.
MD
  original="$(cat "$src")"

  set +e
  "$SCRIPT_PATH" "$src" >/dev/null 2>&1
  local exit_status=$?
  set -e
  [[ "$exit_status" -eq 0 ]] || fail "expected successful conversion, got $exit_status"
  html="$(cat "$tmp_dir/case.html")"

  [[ "$(count_of "$html" '<table')" -eq 1 ]] || fail "expected one <table> in output"
  [[ "$(count_of "$html" '<tr')" -eq 3 ]] || fail "expected 3 <tr> (header + 2 rows)"
  [[ "$(count_of "$html" '<p><strong>Agenda')" -eq 1 ]] || fail "expected the agenda line to stay its own paragraph"
  assert_contains "$html" "<td><strong>Purpose</strong></td>"
  [[ "$(count_of "$html" '| Time | Item')" -eq 0 ]] || fail "table header leaked into text"

  # Without the pre-pass the same text must not produce a table (proves the test is meaningful).
  baseline_html "$src" "$tmp_dir/baseline.html"
  [[ "$(count_of "$(cat "$tmp_dir/baseline.html")" '<table')" -eq 0 ]] || fail "baseline unexpectedly rendered a table"

  [[ "$(cat "$src")" == "$original" ]] || fail "source markdown was modified"
}

# Lists and tables inside backtick and tilde fences must pass through unchanged.
test_fenced_blocks_are_untouched() {
  local tmp_dir src
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN

  src="$tmp_dir/case.md"
  cat >"$src" <<'MD'
Intro line
```md
Lead text
| a | b |
|---|---|
| 1 | 2 |
- list-looking item
```
Some text

~~~
```
| c | d |
|---|---|
- item
~~~
````
```
| x | y |
|---|---|
````
Done.
MD

  set +e
  "$SCRIPT_PATH" "$src" >/dev/null 2>&1
  local exit_status=$?
  set -e
  [[ "$exit_status" -eq 0 ]] || fail "expected successful conversion, got $exit_status"

  baseline_html "$src" "$tmp_dir/baseline.html"
  [[ "$(cat "$tmp_dir/case.html")" == "$(cat "$tmp_dir/baseline.html")" ]] || fail "fenced content was changed by the pre-pass"
  [[ "$(count_of "$(cat "$tmp_dir/case.html")" '<table')" -eq 0 ]] || fail "fenced table-looking text rendered as a table"
}

# Reader extensions: a list directly after text (lists_without_preceding_blankline) and a
# blockquote directly after text (blank_before_blockquote removed) must both be recognized.
test_reader_extensions_list_and_quote_after_text() {
  local tmp_dir src html
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN

  src="$tmp_dir/case.md"
  printf 'Intro sentence:\n- first item\n- second item\n\nQuote follows:\n> quoted line\n' > "$src"

  set +e
  "$SCRIPT_PATH" "$src" >/dev/null 2>&1
  local exit_status=$?
  set -e
  [[ "$exit_status" -eq 0 ]] || fail "expected successful conversion, got $exit_status"
  html="$(cat "$tmp_dir/case.html")"
  [[ "$(count_of "$html" '<li')" -eq 2 ]] || fail "expected 2 <li> from list after text"
  [[ "$(count_of "$html" '<blockquote')" -eq 1 ]] || fail "expected 1 <blockquote> from quote after text"
}

# Mixed file: fenced text stays literal while an unfenced table after text is still fixed.
test_fenced_table_untouched_but_real_table_fixed() {
  local tmp_dir src html
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN

  src="$tmp_dir/case.md"
  cat >"$src" <<'MD'
Example:
```
not a table:
| a | b |
|---|---|
- list-like
```

Tilde example:

~~~
| c | d |
|---|---|
1. ordered-like
~~~
Real result:
| p | q |
|---|---|
| 1 | 2 |

- real item
MD

  set +e
  "$SCRIPT_PATH" "$src" >/dev/null 2>&1
  local exit_status=$?
  set -e
  [[ "$exit_status" -eq 0 ]] || fail "expected successful conversion, got $exit_status"
  html="$(cat "$tmp_dir/case.html")"

  # Fenced content must be literal code: exact <pre><code> blocks with the source lines verbatim.
  local backtick_block=$'<pre><code>not a table:\n| a | b |\n|---|---|\n- list-like</code></pre>'
  local tilde_block=$'<pre><code>| c | d |\n|---|---|\n1. ordered-like</code></pre>'
  assert_contains "$html" "$backtick_block"
  assert_contains "$html" "$tilde_block"

  # The fenced table/list-looking text must not become a table or list element.
  [[ "$(count_of "$html" '<th>a</th>')" -eq 0 ]] || fail "backtick-fenced text rendered as a table header"
  [[ "$(count_of "$html" '<td>c</td>')" -eq 0 ]] || fail "tilde-fenced text rendered as a table cell"
  [[ "$(count_of "$html" '<ol')" -eq 0 ]] || fail "tilde-fenced list-looking text rendered as an ordered list"

  # Real output, asserted separately: exactly one table (fixed by the pre-pass) and one bullet list.
  [[ "$(count_of "$html" '<table')" -eq 1 ]] || fail "expected exactly one real <table>"
  assert_contains "$html" "<th>p</th>"
  assert_contains "$html" "<td>1</td>"
  local real_list=$'<ul>\n<li>real item</li>\n</ul>'
  assert_contains "$html" "$real_list"
  [[ "$(count_of "$html" '<li')" -eq 1 ]] || fail "expected exactly one <li> (the real item)"
}

# Already-blank, non-outer-pipe, and column-mismatch tables must not be touched.
test_strict_rule_leaves_other_input_unchanged() {
  local tmp_dir src
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN

  src="$tmp_dir/case.md"
  cat >"$src" <<'MD'
Already blank:

| a | b |
|---|---|
| 1 | 2 |

No outer pipes:
a | b
--- | ---
1 | 2

Column mismatch:
| a | b | c |
|---|---|
| 1 | 2 | 3 |
Header without outer pipes:
a | b |
|---|
| 1 | 2 |
MD

  set +e
  "$SCRIPT_PATH" "$src" >/dev/null 2>&1
  local exit_status=$?
  set -e
  [[ "$exit_status" -eq 0 ]] || fail "expected successful conversion, got $exit_status"

  baseline_html "$src" "$tmp_dir/baseline.html"
  [[ "$(cat "$tmp_dir/case.html")" == "$(cat "$tmp_dir/baseline.html")" ]] || fail "non-matching input was changed by the pre-pass"
}

# Well-formed input: output must be byte-identical to direct pandoc with the default reader.
test_well_formed_input_byte_identical() {
  local tmp_dir src
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN

  src="$tmp_dir/case.md"
  cat >"$src" <<'MD'
# Title

A paragraph with *emphasis* and `code`.

- first
- second

1. one
2. two

> quoted text

| a | b |
|---|---|
| 1 | 2 |

```python
print("hi")
```

End.
MD

  set +e
  "$SCRIPT_PATH" "$src" >/dev/null 2>&1
  local exit_status=$?
  set -e
  [[ "$exit_status" -eq 0 ]] || fail "expected successful conversion, got $exit_status"

  baseline_html "$src" "$tmp_dir/baseline.html"
  cmp -s "$tmp_dir/case.html" "$tmp_dir/baseline.html" || fail "well-formed output differs from direct pandoc baseline"
}

# The intermediate pre-pass file must be removed after a normal conversion (changed and unchanged input).
test_temp_input_cleaned_on_normal_conversion() {
  local tmp_dir tmp_tmp leftovers
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN
  tmp_tmp="$tmp_dir/tmpdir"
  mkdir -p "$tmp_tmp"

  printf 'Text\n| a | b |\n|---|---|\n| 1 | 2 |\n' > "$tmp_dir/changed.md"
  printf '# Plain\n\nNo tables here.\n' > "$tmp_dir/unchanged.md"

  local f
  for f in changed unchanged; do
    set +e
    TMPDIR="$tmp_tmp" "$SCRIPT_PATH" "$tmp_dir/$f.md" >/dev/null 2>&1
    local exit_status=$?
    set -e
    [[ "$exit_status" -eq 0 ]] || fail "expected successful conversion of $f.md, got $exit_status"
  done

  leftovers="$(ls -A "$tmp_tmp")"
  [[ -z "$leftovers" ]] || fail "temp files left behind: $leftovers"
}

# --view: HTML opens through the PATH stub, stays on disk, and only the input intermediate is cleaned.
test_view_option_opens_and_keeps_html() {
  local tmp_dir tmp_tmp output exit_status
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN
  tmp_tmp="$tmp_dir/tmpdir"
  mkdir -p "$tmp_tmp" "$tmp_dir/bin"
  cat >"$tmp_dir/bin/open" <<'EOF'
#!/bin/bash
echo "$1" > "$TEST_OPEN_CALL_LOG"
EOF
  chmod +x "$tmp_dir/bin/open"

  printf 'Text\n| a | b |\n|---|---|\n| 1 | 2 |\n' > "$tmp_dir/case.md"

  export TEST_OPEN_CALL_LOG="$tmp_dir/open_call.log"
  set +e
  output="$(PATH="$tmp_dir/bin:$PATH" TMPDIR="$tmp_tmp" "$SCRIPT_PATH" --view "$tmp_dir/case.md" 2>&1)"
  exit_status=$?
  set -e
  [[ "$exit_status" -eq 0 ]] || fail "expected successful --view conversion, got $exit_status"
  assert_contains "$output" "(temp)"

  [[ -f "$tmp_dir/open_call.log" ]] || fail "expected mocked open to be called"
  local opened
  opened="$(cat "$tmp_dir/open_call.log")"
  [[ "$opened" == "$tmp_tmp"/case.*.html ]] || fail "open was called with unexpected path: $opened"
  [[ -s "$opened" ]] || fail "--view HTML was removed or empty: $opened"
  assert_contains "$(cat "$opened")" "<table"

  # Only the rendered HTML may remain in the temp dir; the pre-pass input must be gone.
  local leftovers
  leftovers="$(ls -A "$tmp_tmp")"
  [[ "$leftovers" == "$(basename "$opened")" ]] || fail "unexpected temp files: $leftovers"
}

# Valid fences in the contexts where Pandoc opens them stay literal: output must equal the
# direct-pandoc baseline (no pre-pass change) and the table-looking lines must stay in code.
test_valid_fences_in_pandoc_contexts_stay_literal() {
  local tmp_dir src
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN

  src="$tmp_dir/case.md"
  cat >"$src" <<'MD'
Text before backtick fence
```
| a | b |
|---|---|
```

# Heading
~~~
| c | d |
|---|---|
~~~

- item
~~~
| e | f |
|---|---|
~~~

> quote

~~~~
~~~
| g | h |
|---|---|
~~~~
End.
MD

  set +e
  "$SCRIPT_PATH" "$src" >/dev/null 2>&1
  local exit_status=$?
  set -e
  [[ "$exit_status" -eq 0 ]] || fail "expected successful conversion, got $exit_status"

  baseline_html "$src" "$tmp_dir/baseline.html"
  [[ "$(cat "$tmp_dir/case.html")" == "$(cat "$tmp_dir/baseline.html")" ]] || fail "valid fenced content was changed by the pre-pass"
  [[ "$(count_of "$(cat "$tmp_dir/case.html")" '<table')" -eq 0 ]] || fail "fenced table-looking text rendered as a table"
}

# Regression: a fence inside a list item indented 4+ spaces must still protect its code. The
# pre-pass used to miss it and inserted a blank before a table header inside the literal code.
test_indented_list_item_fence_literal_kept() {
  local tmp_dir src html
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN

  src="$tmp_dir/case.md"
  cat >"$src" <<'MD'
- item

    ```
  | a | b |
  |---|---|
  | 1 | 2 |
    ```

After.
MD

  set +e
  "$SCRIPT_PATH" "$src" >/dev/null 2>&1
  local exit_status=$?
  set -e
  [[ "$exit_status" -eq 0 ]] || fail "expected successful conversion, got $exit_status"
  html="$(cat "$tmp_dir/case.html")"

  local literal_block=$'<pre><code>| a | b |\n|---|---|\n| 1 | 2 |</code></pre>'
  assert_contains "$html" "$literal_block"
  [[ "$(count_of "$html" '<table')" -eq 0 ]] || fail "indented fenced table-looking text rendered as a table"

  # Same output as direct pandoc on the untouched source: the pre-pass changed nothing.
  baseline_html "$src" "$tmp_dir/baseline.html"
  [[ "$html" == "$(cat "$tmp_dir/baseline.html")" ]] || fail "indented fenced content was changed by the pre-pass"
}

# Regression: an indented backtick marker inside a column-zero fence must not close it. Without the
# closing-indent rule the pre-pass treated the marker as a close and inserted a blank before the
# table-looking lines inside the literal code.
test_indented_marker_does_not_close_column_zero_fence() {
  local tmp_dir src html
  tmp_dir="$(setup_fixture_dir)"
  trap 'cleanup_fixture_dir "$tmp_dir"' RETURN

  src="$tmp_dir/case.md"
  printf '```\n    ```\n| a | b |\n|---|---|\n| 1 | 2 |\n```\n\nAfter.\n' > "$src"

  set +e
  "$SCRIPT_PATH" "$src" >/dev/null 2>&1
  local exit_status=$?
  set -e
  [[ "$exit_status" -eq 0 ]] || fail "expected successful conversion, got $exit_status"
  html="$(cat "$tmp_dir/case.html")"

  local literal_block=$'<pre><code>    ```\n| a | b |\n|---|---|\n| 1 | 2 |</code></pre>'
  assert_contains "$html" "$literal_block"
  [[ "$(count_of "$html" '<table')" -eq 0 ]] || fail "table-looking text after an indented marker rendered as a table"

  baseline_html "$src" "$tmp_dir/baseline.html"
  [[ "$html" == "$(cat "$tmp_dir/baseline.html")" ]] || fail "fenced content was changed by the pre-pass"
}

test_help_documents_input_handling() {
  local output
  output="$("$SCRIPT_PATH" --help 2>&1)"
  assert_contains "$output" "Input handling:"
  assert_contains "$output" "Fenced code blocks are left untouched"
  assert_contains "$output" "never modified"
}

test_help_flag_short
test_help_flag_long
test_no_arguments
test_too_many_arguments
test_successful_conversion
test_open_option
test_table_after_text_gets_blank_line
test_fenced_blocks_are_untouched
test_fenced_table_untouched_but_real_table_fixed
test_reader_extensions_list_and_quote_after_text
test_valid_fences_in_pandoc_contexts_stay_literal
test_indented_list_item_fence_literal_kept
test_indented_marker_does_not_close_column_zero_fence
test_strict_rule_leaves_other_input_unchanged
test_well_formed_input_byte_identical
test_temp_input_cleaned_on_normal_conversion
test_view_option_opens_and_keeps_html
test_help_documents_input_handling

echo "PASS: md2html"
