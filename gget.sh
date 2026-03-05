#!/bin/bash

# gget.sh
#
# A deployment tool for configuration "scenarios" (predefined sets of files like 
# .gitignore, .cursorrules, etc.) stored in the 'data-dir-gget' directory. 
# It allows interactive selection and copying of these files into the current directory.
#
# Usage: ./gget.sh [-f] <scenario_name> [specific_filename]
#
# Options:
#   -f: Force overwrite existing files without prompting.
#
# Features:
# - Lists available scenarios if no arguments are provided.
# - Supports partial scenario name matching and multiple selections.
# - Displays README.md for the selected scenario if available.
# - Handles file collisions with skip, overwrite, or rename options.
# - Can prepend repository-specific ignores from '.extra_repo_ignores'.

SCRIPT_DIR=$(dirname "$0")
DIR_TARGET=$(pwd)
DATA_DIRNAME_GGET="data-dir-gget"
DATA_DIR_GGET="$SCRIPT_DIR/$DATA_DIRNAME_GGET"

# This is the filename of the file that contains the ignores for the specific repo
# Only this should be adapted for repo specific ignores
# It will be prepended to the ignores file in the data-dir-gget/ignores directory
EXTRA_REPO_IGNORES_FILENAME=".extra_repo_ignores"

# Parse command line arguments for -f flag
FORCE_OVERWRITE=false
ARGS=("$@")
FILTERED_ARGS=()

for arg in "${ARGS[@]}"; do
    if [ "$arg" = "-f" ]; then
        FORCE_OVERWRITE=true
    else
        FILTERED_ARGS+=("$arg")
    fi
done

echo "Available scenarios:"
for dir in "$DATA_DIR_GGET/"*/; do
    echo "  $(basename "$dir")"
done
echo

# Check if parameter is provided
if [ ${#FILTERED_ARGS[@]} -eq 0 ]; then
    echo "Usage: $0 [-f] <scenario> [filename]"
    echo "  -f: Force overwrite existing files without prompting"
    echo
    exit 1
fi

SCENARIO="${FILTERED_ARGS[0]}"

# Get all available scenarios
AVAILABLE_SCENARIOS=$(ls -d "$DATA_DIR_GGET/"*/ | xargs -n 1 basename)

# First try exact match
MATCHING_SCENARIOS=$(echo "$AVAILABLE_SCENARIOS" | grep -Fx "$SCENARIO" || true)

# If no exact match, try substring match
if [ -z "$MATCHING_SCENARIOS" ]; then
    MATCHING_SCENARIOS=$(echo "$AVAILABLE_SCENARIOS" | grep -F "$SCENARIO" || true)
fi

# If still no matches, exit
if [ -z "$MATCHING_SCENARIOS" ]; then
    echo "Unknown scenario: $SCENARIO"
    echo
    exit 1
fi

# Convert matching scenarios to array (compatible way)
IFS=$'\n' read -d '' -r -a matches <<< "$MATCHING_SCENARIOS"

# If only one match, use it directly
if [ ${#matches[@]} -eq 1 ]; then
    selected_scenarios=("${matches[0]}")
else
    echo "Multiple matches found. Choose an option:"
    echo "Press 'a' to process all matches. Use comma separated numbers to select specific matches."
    for i in "${!matches[@]}"; do
        echo "$((i+1)): ${matches[$i]}"
    done

    read -r choice
    echo
    if [ "$choice" = "a" ]; then
        selected_scenarios=("${matches[@]}")
    elif [ "$choice" = "" ]; then
        echo "You did not choose - exiting."
        exit 1
    else
        # Handle comma-separated numbers
        IFS=',' read -ra choices <<< "$choice"
        selected_scenarios=()
        for c in "${choices[@]}"; do
            # Trim whitespace
            c=$(echo "$c" | tr -d '[:space:]')
            if ! [[ "$c" =~ ^[0-9]+$ ]]; then
                echo "Invalid choice '$c'. Please enter numbers between 1 and ${#matches[@]}, separated by commas, or 'a' for all"
                exit 1
            fi
            if [ "$c" -lt 1 ] || [ "$c" -gt ${#matches[@]} ]; then
                echo "Invalid choice '$c'. Please enter numbers between 1 and ${#matches[@]}, separated by commas, or 'a' for all"
                exit 1
            fi
            selected_scenarios+=("${matches[$((c-1))]}")
        done
    fi
fi

for SCENARIO in "${selected_scenarios[@]}"; do
    SCENARIO_DIR="$DATA_DIR_GGET/$SCENARIO"
    echo "Processing scenario: $SCENARIO"
    echo

    README_FILE="README.md"
    if [ -f "$SCENARIO_DIR/$README_FILE" ]; then
        echo
        echo "===================================="
        echo "== README for scenario '$SCENARIO' =="
        echo "===================================="
        # Process markdown with sed to convert basic markdown to terminal formatting
        # Using ANSI escape codes for bold and italic text
        cat "$SCENARIO_DIR/$README_FILE" | \
            sed 's/\*\*\([^*]*\)\*\*/\x1b[1m\1\x1b[0m/g' | \
            sed 's/\*\([^*]*\)\*/\x1b[3m\1\x1b[0m/g' | \
            sed 's/^# \(.*\)/\x1b[1m\1\x1b[0m/g'
        echo
        echo "================================"
        echo
    fi

    # Get list of files in scenario directory
    SCENARIO_FILES=$(cd "$SCENARIO_DIR" && find . -type f | grep -vE "$README_FILE" | sed 's|^./||')
    echo "Scenario '$SCENARIO' exists - attempting to copy files to the current directory"
    echo
    # Process each file in the scenario
    for cur_filename in $SCENARIO_FILES; do
        cur_source_file="$SCENARIO_DIR/$cur_filename"
        cur_filename_for_target=$(echo "$cur_filename" | sed 's/_r3pl_//')
        cur_target_file="$DIR_TARGET/$cur_filename_for_target"
        
        if [ ${#FILTERED_ARGS[@]} -gt 1 ] && [ "$cur_filename" != "${FILTERED_ARGS[1]}" ]; then
            echo "  Skipping $cur_filename (not matching requested filename '${FILTERED_ARGS[1]}')"
            continue
        fi

        # Create target directory structure if needed
        target_dir=$(dirname "$cur_target_file")
        if [ "$target_dir" != "$DIR_TARGET" ] && [ ! -d "$target_dir" ]; then
            echo "  Creating directory structure: $(echo "$target_dir" | sed "s|^$DIR_TARGET/||")"
            mkdir -p "$target_dir"
        fi

        do_copy=false
        if [ -f "$cur_target_file" ]; then
            if [ "$FORCE_OVERWRITE" = true ]; then
                echo "  Force overwriting: $cur_filename_for_target"
                do_copy=true
            else
                echo
                echo "  The file === $cur_filename_for_target === is to be copied to target directory where it already exists."
                echo
                echo "Choose an option:"
                echo "  1: Skip"
                echo "  2: Overwrite existing file"
                echo "  3: Copy with numerical suffix"
                read -n 1 choice
                echo
                
                case $choice in
                    1)
                        echo "  Skipping $cur_filename"
                        do_copy=false
                        continue
                        ;;
                    2)
                        echo "  Overwriting: $cur_filename"
                        do_copy=true
                        ;;
                    3)
                        echo "  Copying with numerical suffix"
                        counter=1
                        base_name=$(basename "$cur_filename_for_target")
                        base_dir=$(dirname "$cur_filename_for_target")
                        new_name="$base_name"
                        while [ -f "$DIR_TARGET/$base_dir/$new_name" ]; do
                            new_name="$(echo "$base_name" | sed 's/\.[^.]*$/_'"$counter"'&/')"
                            counter=$((counter + 1))
                        done
                        echo "  -> New name: $base_dir/$new_name"
                        cur_target_file="$DIR_TARGET/$base_dir/$new_name"
                        do_copy=true
                        ;;
                    *)
                        echo "  Invalid choice. Skipping $cur_filename"
                        continue
                        ;;
                esac
            fi
        else
            echo "  File $cur_filename_for_target does not exist in target directory. Copying..."
            do_copy=true
        fi

        if [ "$do_copy" = true ]; then
            echo
            if [ "$SCENARIO" = "ignores" ] && [ -f "$DIR_TARGET/$EXTRA_REPO_IGNORES_FILENAME" ]; then
                echo "  Copying file $cur_filename to $cur_target_file prepending with contents of $EXTRA_REPO_IGNORES_FILENAME"
                combined_content=$(cat "$DIR_TARGET/$EXTRA_REPO_IGNORES_FILENAME")
                combined_content+=$'\n\n'
                combined_content+=$(cat "$cur_source_file")
                echo "$combined_content" > "$cur_target_file"
            else
                echo "  Copying file $cur_filename to $cur_target_file"
                cp "$cur_source_file" "$cur_target_file"
            fi
        fi
    done
    echo
    echo "  ================"
    echo "  ===   Done   ==="
    echo "  ================"
    echo
done