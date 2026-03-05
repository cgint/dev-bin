#!/bin/bash

# grollout.sh
#
# A "rollout" tool to synchronize a specific file from a 'data-dir-gget' scenario 
# to all its occurrences across multiple projects on the local system.
#
# Usage: ./grollout.sh <scenario_name> <filename>
#        ./grollout.sh <path_to_scenario_file>
#
# Mechanism:
# 1. Identifies the source file within a 'data-dir-gget' scenario.
# 2. Uses 'dev_file_find.sh' to locate all files with the same name across the dev environment.
# 3. Prompts the user to overwrite all found occurrences with the source version.
#
# Use this to propagate global configuration changes (like updated .cursorrules) 
# to all relevant projects.

set -euo pipefail

SCRIPT_DIR=$(dirname "$0")
DIR_TARGET=$(pwd)
DATA_DIRNAME_GGET="data-dir-gget"
DATA_DIR_GGET="$SCRIPT_DIR/$DATA_DIRNAME_GGET"

# Function to list available scenarios
list_scenarios() {
    echo "Available scenarios:"
    for dir in "$DATA_DIR_GGET/"*/; do
        echo "  $(basename "$dir")"
    done
    echo
}

# Function to list files in a scenario
list_scenario_files() {
    local scenario="$1"
    local scenario_dir="$DATA_DIR_GGET/$scenario"
    
    if [ ! -d "$scenario_dir" ]; then
        echo "Error: Scenario '$scenario' does not exist."
        exit 1
    fi

    echo "Files in scenario '$scenario':"
    find "$scenario_dir" -type f | grep -v "README.md" | sed "s|$scenario_dir/||"
    echo
}

# Check number of parameters
if [ $# -eq 0 ]; then
    list_scenarios
    exit 0
fi

# First parameter could be a full path or scenario name
INPUT="$1"

# Check if input is a path containing data-dir-gget
if [[ "$INPUT" == *"$DATA_DIRNAME_GGET"* ]]; then
    # Handle both absolute and relative paths
    if [[ "$INPUT" == /* ]]; then
        # Absolute path
        FULL_PATH="$INPUT"
    else
        # Relative path (like data-dir-gget/scenario/file.md)
        FULL_PATH="$SCRIPT_DIR/$INPUT"
    fi
    
    # Extract scenario and filename from path
    if [[ "$INPUT" == *"$DATA_DIRNAME_GGET/"*"/"* ]]; then
        # Path contains both scenario and filename
        SCENARIO=$(echo "$INPUT" | sed -E "s|.*$DATA_DIRNAME_GGET/([^/]+)/.*|\1|")
        FILENAME=$(basename "$INPUT")
        SOURCE_FILE="$FULL_PATH"
    else
        # Path only contains data-dir-gget without scenario/filename
        echo "Error: Invalid path format. Expected format: data-dir-gget/scenario/filename"
        list_scenarios
        exit 1
    fi

    # Verify the scenario exists
    if [ ! -d "$DATA_DIR_GGET/$SCENARIO" ]; then
        echo "Error: Scenario '$SCENARIO' does not exist."
        list_scenarios
        exit 1
    fi

    # Verify the file exists
    if [ ! -f "$SOURCE_FILE" ]; then
        echo "Error: File '$FILENAME' does not exist in scenario '$SCENARIO'."
        list_scenario_files "$SCENARIO"
        exit 1
    fi
else
    # Use input as scenario
    SCENARIO="$INPUT"

    # Check if scenario exists
    if [ ! -d "$DATA_DIR_GGET/$SCENARIO" ]; then
        echo "Error: Scenario '$SCENARIO' does not exist."
        list_scenarios
        exit 1
    fi

    # If only scenario is provided, list its files
    if [ $# -eq 1 ]; then
        list_scenario_files "$SCENARIO"
        exit 0
    fi

    # Second parameter is the filename
    FILENAME="$2"
    SOURCE_FILE="$DATA_DIR_GGET/$SCENARIO/$FILENAME"

    # Check if the file exists
    if [ ! -f "$SOURCE_FILE" ]; then
        echo "Error: File '$FILENAME' does not exist."
        list_scenario_files "$SCENARIO"
        exit 1
    fi
fi

# Display source file information
SOURCE_FILE_INFO=$(stat -f "%Sm %z bytes" -t "%Y-%m-%d %H:%M:%S" "$SOURCE_FILE")
echo
echo "Source file:"
echo "$SOURCE_FILE_INFO | $SOURCE_FILE"
echo

# Use dev_file_find.sh to find matching files
echo "Searching for files matching '$FILENAME' from scenario '$SCENARIO'..."
echo
# Filter results to only include exact filename matches at the end of the path
MATCHING_FILES=$(~/.local/bin/dev_file_find.sh "$FILENAME" | grep -v "Searching for filenames" | grep "/${FILENAME}$" | sed '/^[[:space:]]*$/d' | xargs)

# Check if any files were found
if [ -z "$MATCHING_FILES" ]; then
    echo "No files found matching '$FILENAME'."
    exit 1
fi

# Display matching files with detailed information
echo "Found the following files:"
MATCHING_FILES_DETAILS=()
for file in $MATCHING_FILES; do
    # Verify file exists and is not an empty string
    if [[ -n "$file" ]] && [[ -f "$file" ]]; then
        # Get file details
        FILE_INFO=$(stat -f "%Sm %z bytes" -t "%Y-%m-%d %H:%M:%S" "$file")
        echo "$FILE_INFO | File: $file"
        
        # Store file for later processing
        MATCHING_FILES_DETAILS+=("$file")
    fi
done

# Check if any valid files were found
if [ ${#MATCHING_FILES_DETAILS[@]} -eq 0 ]; then
    echo "No valid files found matching '$FILENAME'."
    exit 1
fi

# Prompt user for confirmation
echo
read -p "Do you want to overwrite these files with $SCENARIO/$FILENAME ? (y/N): " response
response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
echo

if [[ $response != "y" ]]; then
    echo "Operation cancelled."
    echo
    exit 0
fi

# Overwrite files
echo "Overwriting files..."
for file in "${MATCHING_FILES_DETAILS[@]}"; do
    echo "Copying $SOURCE_FILE to $file"
    cp "$SOURCE_FILE" "$file"
done
echo
echo "Files successfully overwritten."
echo
