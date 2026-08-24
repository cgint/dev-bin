#!/bin/bash

# gopen.sh — quick-launcher for dev projects
# Discovers repos at these locations:
#   dev/*/.git              (depth 1)
#   dev-external/*/.git     (depth 1)
#   dev/concepts/*/.git     (depth 1 from dev/concepts)
#   dev-private/**/.git     (depth <= 3)
# Matches on root-qualified labels.
#
# Usage: gopen.sh <query> [--path] [<editor>]
#        gopen.sh install

if [ "$1" = "install" ]; then
    echo "Installing gopen.command in home directory so you can open it with Spotlight Search"
    COMMAND_FILE="${HOME}/gopen.command"
    printf '#!/bin/bash\n%s/.local/bin/gopen.sh "$@"\n' "$HOME" > "$COMMAND_FILE"
    chmod u+x "$COMMAND_FILE"
    echo "Done. You can now open gopen with Spotlight Search"
    exit 0
fi

SCRIPT_DIR=$(dirname "$0")
QUERY=$1
OPEN_WITH="code"
PATH_MODE=false
if [ $# -ge 2 ]; then
    if [ "$2" = "--path" ]; then
        PATH_MODE=true
        OPEN_WITH="--path"
    else
        OPEN_WITH="$2"
    fi
fi

# --- Temp files (in allowed directory) ---
_G_OPEN_TMP="${HOME}/.local/bin/.gopen_tmp"
mkdir -p "$_G_OPEN_TMP"
ENTRIES_F="$_G_OPEN_TMP/e_$$.txt"
SORTED_F="$_G_OPEN_TMP/s_$$.txt"
MATCH_F="$_G_OPEN_TMP/m_$$.txt"
CANDIDATES_F="$_G_OPEN_TMP/c_$$.txt"
trap 'rm -f "$ENTRIES_F" "$SORTED_F" "$MATCH_F" "$CANDIDATES_F"' EXIT

# --- Phase 1: collect all candidate paths (no stat yet) ---
# Discovery model (explicit, per-root depths):
#   dev/*/.git              (depth 1)
#   dev-external/*/.git     (depth 1)
#   dev/concepts/*/.git     (depth 1 from dev/concepts)
#   dev-private/**/.git     (depth <= 3)
# No walk into repo interiors; .git must be a directory (git worktree
# pointers are files and are excluded). VCS-less dirs are not indexed.
: > "$CANDIDATES_F"

for base in "$HOME/dev" "$HOME/dev-external" "$HOME/dev/concepts"; do
    [ -d "$base" ] || continue
    for child in "$base"/*/; do
        [ -d "$child" ] || continue
        child="${child%/}"
        [ -d "$child/.git" ] && echo "$child" >> "$CANDIDATES_F"
    done
done

[ -d "$HOME/dev-private" ] && \
    find "$HOME/dev-private" -maxdepth 3 -type d -name '.git' 2>/dev/null | \
    while IFS= read -r g; do echo "$(dirname "$g")"; done >> "$CANDIDATES_F"

# --- Phase 2: batch stat all candidates at once ---
# stat -f '%m %N' outputs: mtime space path (one per line)
# We join this with the label computed from the path
: > "$ENTRIES_F"
if [ -s "$CANDIDATES_F" ]; then
    # Batch stat all paths (handles spaces via careful parsing)
    xargs stat -f '%m %N' < "$CANDIDATES_F" 2>/dev/null | \
    while IFS= read -r line; do
        mtime="${line%% *}"
        path="${line#* }"
        # Derive label from path: strip $HOME/ prefix
        label="${path#${HOME}/}"
        # Ensure root is the first component (dev, dev-archive, etc.)
        printf '%s\t%s\t%s\n' "$mtime" "$path" "$label"
    done >> "$ENTRIES_F"
fi

# Sort by mtime desc, dedup by label (field 3), output path<TAB>label
sort -rn -t"$(printf '\t')" -k1,1 "$ENTRIES_F" | \
awk -F'\t' '!seen[$3]++ {print $2"\t"$3}' > "$SORTED_F"

TOTAL=$(wc -l < "$SORTED_F" | tr -d ' ')

# Print listing (unless --path)
if [ "$PATH_MODE" != true ]; then
    echo
    echo "Available directories ($TOTAL entries):"
    awk -F'\t' '{print "  "$3}' "$SORTED_F"
    echo
fi

# Require query
if [ -z "$QUERY" ]; then
    echo "Please provide a search query" >&2
    read QUERY
    if [ -z "$QUERY" ]; then
        echo "No query provided. Exiting." >&2
        exit 1
    fi
fi

# Special: bin
if [ "$QUERY" = "bin" ]; then
    if [ "$PATH_MODE" = true ]; then
        echo "$SCRIPT_DIR"
    else
        echo "Opening bin directory: $SCRIPT_DIR"
        echo
        "$OPEN_WITH" "$SCRIPT_DIR"
    fi
    exit 0
fi

# --- Match: exact > component > substring ---
# Priority: 1=exact, 2=component, 3=substring
# Output: path<TAB>label<TAB>priority
QUERY_LOWER=$(printf '%s' "$QUERY" | tr '[:upper:]' '[:lower:]')
awk -F'\t' -v q="$QUERY_LOWER" '
{
    path = $1
    label = $2
    ll = tolower(label)

    # Exact match
    if (ll == q) {
        printf "%s\t%s\t1\n", path, label
        next
    }

    # Component match: split label on /
    n = split(ll, parts, "/")
    for (i = 1; i <= n; i++) {
        if (parts[i] == q) {
            printf "%s\t%s\t2\n", path, label
            next
        }
    }

    # Substring match
    if (index(ll, q) > 0) {
        printf "%s\t%s\t3\n", path, label
    }
}' "$SORTED_F" | sort -t"$(printf '\t')" -k3,3n | cut -f1,2 > "$MATCH_F"

# No matches
if [ ! -s "$MATCH_F" ]; then
    echo "No matching directory found for '$QUERY'" >&2
    exit 1
fi

MATCH_COUNT=$(wc -l < "$MATCH_F" | tr -d ' ')

# Single match — open directly
if [ "$MATCH_COUNT" -eq 1 ]; then
    IFS="$(printf '\t')" read -r path label < "$MATCH_F"
    if [ "$PATH_MODE" = true ]; then
        echo "$path"
    else
        echo "Opening: $label ($path) with $OPEN_WITH"
        "$OPEN_WITH" "$path"
    fi
    exit 0
fi

# Multiple matches — chooser
echo >&2
echo "Multiple matches found. Choose an option:" >&2
echo "Press 'a' to open all matches" >&2

choice_num=0
while IFS="$(printf '\t')" read -r path label; do
    choice_num=$((choice_num + 1))
    echo "  $choice_num: $label" >&2
done < "$MATCH_F"

if [ "$choice_num" -le 9 ]; then
    # Keep the fast one-key UX when every option is single-digit.
    IFS= read -r -n 1 choice
    echo >&2
else
    # Preserve access to multi-digit options when there are 10+ matches.
    read -r choice
fi
if [ "$choice" = "a" ]; then
    if [ "$PATH_MODE" = true ]; then
        echo "Error: Cannot output multiple paths in --path mode" >&2
        exit 1
    fi
    while IFS="$(printf '\t')" read -r path label; do
        echo "Opening: $label ($path) with $OPEN_WITH"
        "$OPEN_WITH" "$path"
    done < "$MATCH_F"
elif [ -z "$choice" ] || ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    echo "You did not choose - exiting." >&2
    exit 1
elif [ "$choice" -lt 1 ] || [ "$choice" -gt "$choice_num" ]; then
    echo "Invalid choice. Please enter a number between 1 and $choice_num or a for all" >&2
    exit 1
else
    sel=$(sed -n "${choice}p" "$MATCH_F")
    path=$(printf '%s' "$sel" | cut -f1)
    label=$(printf '%s' "$sel" | cut -f2)
    if [ "$PATH_MODE" = true ]; then
        echo "$path"
    else
        echo "Opening: $label ($path) with $OPEN_WITH"
        "$OPEN_WITH" "$path"
    fi
fi