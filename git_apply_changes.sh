#!/bin/bash

# git_apply_changes.sh
#
# Applies uncommitted git changes (the output of 'git diff HEAD') from a source 
# directory to a target directory. This is useful for porting experimental changes 
# between related projects.
#
# Usage: ./git_apply_changes.sh <source_directory> <target_directory>
#
# Requirements:
# - The target directory must be a git repository and must not have uncommitted changes.

# Check if source and target directories are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: git_apply_changes.sh <source-dir> <target-dir>"
    exit 1
fi

SOURCE_DIR=$(realpath "$1")
TARGET_DIR=$(realpath "$2")

echo "Applying changes from $SOURCE_DIR to $TARGET_DIR"

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' does not exist."
    exit 1
fi

# Check if target directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Target directory '$TARGET_DIR' does not exist."
    exit 1
fi

# Check if there are uncommitted changes in the target directory
cd "$TARGET_DIR" || exit
if [[ $(git status --porcelain) ]]; then
    echo "Error: Target directory '$TARGET_DIR' has uncommitted changes. Please commit or stash them before applying changes."
    exit 1
fi

# Apply the diff from the source directory to the target directory
(cd "$SOURCE_DIR" && git diff HEAD) | git apply -

if [ $? -eq 0 ]; then
    echo "Patch from '$SOURCE_DIR' applied successfully to '$TARGET_DIR'."
else
    echo "Error: Failed to apply patch from '$SOURCE_DIR' to '$TARGET_DIR'."
fi
