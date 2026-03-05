#!/bin/bash

# gopen.sh
#
# A quick-launcher for development projects. It searches for directories within 
# $HOME/dev* (e.g., dev, dev-archive, dev-external, dev/clients) and opens them in an editor.
#
# Usage: ./gopen.sh <search_query> [editor_command]
#        ./gopen.sh <search_query> --path
#        ./gopen.sh install
#
# Options:
#   install: Creates a 'gopen.command' in the home directory for Spotlight Search access.
#   <search_query>: Substring match for the project directory name.
#   [editor_command]: The command to open the directory (defaults to 'cursor').
#   --path: Output only the selected directory path on stdout (for use with gcd.sh).
#
# Features:
# - Lists available directories if only a partial match is found.
# - Sorts results by modification time (most recent first).
# - Special query 'bin' opens the script's own directory.

if [ "$1" = "install" ]; then
    echo "Installing gopen.command in home directory so you can open it with Spotlight Search"
    COMMAND_FILE="${HOME}/gopen.command"
    echo '#!/bin/bash' > "$COMMAND_FILE"
    echo '${HOME}/.local/bin/gopen.sh "$@"' >> "$COMMAND_FILE"
    chmod u+x "$COMMAND_FILE"
    echo "Done. You can now open gopen with Spotlight Search"
    exit 0
fi


SCRIPT_DIR=$(dirname "$0")

DEV_HOME_ALL="$HOME/dev*"

QUERY=$1
OPEN_WITH="cursor"
PATH_MODE=false
if [ ! -z "$2" ]; then
    if [ "$2" = "--path" ]; then
        PATH_MODE=true
        OPEN_WITH="--path"
    else
        OPEN_WITH="$2"
    fi
fi

# Print available directories
get_available_dev_dirs() {
    local dir="${1}"
    local min_depth="${2}"
    local max_depth="${3}"
    find "$dir" -type d -mindepth "$min_depth" -maxdepth "$max_depth" -not -path '*/\.*' 2>/dev/null | xargs stat -f '%m %N' 2>/dev/null | sort -rn | cut -d' ' -f2- | tail -r
}

AVAILABLE_DIRS_DEV=""
AVAILABLE_DIRS_CLIENT=""
for base in $DEV_HOME_ALL; do
    [ -d "$base" ] || continue
    dirs=$(get_available_dev_dirs "$base" 1 1)
    dirs=$(echo "$dirs" | while IFS= read -r d; do
        name=$(basename "$d"); [[ "$name" == clients || "$name" == external ]] || echo "$d"
    done)
    AVAILABLE_DIRS_DEV="${AVAILABLE_DIRS_DEV:+$AVAILABLE_DIRS_DEV$'\n'}$dirs"
    if [ -d "$base/clients" ]; then
        client_dirs=$(get_available_dev_dirs "$base/clients" 1 1)
        AVAILABLE_DIRS_CLIENT="${AVAILABLE_DIRS_CLIENT:+$AVAILABLE_DIRS_CLIENT$'\n'}$client_dirs"
    fi
done

if [ "$PATH_MODE" != true ]; then
    echo
    echo "Available directories in $DEV_HOME_ALL:"
    echo "$AVAILABLE_DIRS_DEV" | while IFS= read -r dir; do
        [ -n "$dir" ] && echo " $(basename "$dir")"
    done
    echo
    echo "Available directories in dev*/clients:"
    echo "$AVAILABLE_DIRS_CLIENT" | while IFS= read -r dir; do
        [ -n "$dir" ] && echo " $(basename "$dir")"
    done
    echo
fi

AVAILABLE_DIRS="$AVAILABLE_DIRS_DEV
$AVAILABLE_DIRS_CLIENT"

if [ -z "$QUERY" ]; then
    echo "Please provide a search query" >&2
    read QUERY
    if [ -z "$QUERY" ]; then
        echo "No query provided. Exiting." >&2
        exit 1
    fi
fi

# If query is 'bin', open the directory containing this script
if [ "$QUERY" = "bin" ]; then
    if [ "$PATH_MODE" = true ]; then
        echo "$SCRIPT_DIR"
        exit 0
    else
        echo "Opening bin directory: $SCRIPT_DIR"
        echo
        "$OPEN_WITH" "$SCRIPT_DIR"
        exit 1
    fi
fi


QUERY_LOWER=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')
matches=()
while IFS= read -r dir; do
    dir_name=$(basename "$dir" | tr '[:upper:]' '[:lower:]')
    
    # Calculate similarity score (case insensitive)
    # Direct match gets highest priority (100 points)
    if [ "$dir_name" = "$QUERY_LOWER" ]; then
        matches=("$dir")
        echo "Direct match found: $dir. Using only this match." >&2
        break
    fi
    
    # Contains as substring gets collected
    if [[ "$dir_name" == *"$QUERY_LOWER"* ]]; then
        matches+=("$dir")
        echo "Substring match found: $dir" >&2
    fi
done <<< "$AVAILABLE_DIRS"

if [ ${#matches[@]} -eq 0 ]; then
    echo "No matching directory found for '$QUERY'" >&2
    echo >&2
    exit 1
fi

selected_choices=()
if [ ${#matches[@]} -gt 1 ]; then
    
    echo >&2
    echo "Multiple matches found. Choose an option:" >&2
    echo "Press 'a' to open all matches" >&2
    for i in "${!matches[@]}"; do
        echo "$((i+1)): ${matches[$i]}" >&2
    done

    read -n 1 choice
    echo >&2
    if [ "$choice" = "a" ]; then
        if [ "$PATH_MODE" = true ]; then
            echo "Error: Cannot output multiple paths in --path mode" >&2
            exit 1
        fi
        selected_choices=("${matches[@]}")
    elif [ "$choice" = "" ] || ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        echo "You did not choose - exiting." >&2
        exit 1
    elif [ "$choice" -lt 1 ] || [ "$choice" -gt ${#matches[@]} ]; then
        echo "Invalid choice. Please enter a number between 1 and ${#matches[@]} or a for all" >&2
        exit 1
    else
        selected_choices=("${matches[$((choice-1))]}")
    fi
else
    selected_choices=("${matches[0]}")
fi

for choice in "${selected_choices[@]}"; do
    if [ "$PATH_MODE" = true ]; then
        echo "$choice"
        exit 0
    else
        echo "Opening: $choice with $OPEN_WITH"
        "$OPEN_WITH" "$choice"
    fi
done
