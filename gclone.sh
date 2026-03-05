#!/bin/bash
set -euo pipefail

# gclone.sh
#
# This script clones an existing project directory to a new one, performing a rename.
# It is specifically designed for Cloudflare Workers (wrangler.toml) and Node.js projects.
#
# Usage: ./gclone.sh <old_project_name> <new_project_name>
#
# Steps:
# 1. Validates the existence of the old project (checking for wrangler.toml or pyproject.toml).
# 2. Ensures the target directory doesn't already exist.
# 3. Copies files using rsync, excluding common build artifacts and metadata (.git, node_modules, etc.).
# 4. Updates occurrences of the old project name with the new one in wrangler.toml and package.json.

# Check if old and new project names are provided as parameters
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <old_project_name> <new_project_name>"
    exit 1
fi

OLD_NAME="$1"
NEW_NAME="$2"

if [ ! -f "$OLD_NAME/wrangler.toml" ] && [ ! -f "$OLD_NAME/pyproject.toml" ]; then
    echo "Error: The old project '$OLD_NAME' does not exist or does not contain a wrangler.toml file."
    exit 1
fi

if [ -d "$NEW_NAME" ]; then
    echo "Error: The new project '$NEW_NAME' already exists."
    exit 1
fi


# (1) Copy the project files using rsync, excluding the specified files and directories
echo "Copying the project files from $OLD_NAME to $NEW_NAME..."
rsync -a \
  --exclude '.git' \
  --exclude 'node_modules' \
  --exclude '.svelte-kit' \
  --exclude '.wrangler' \
  --exclude 'package-lock.json' \
  --exclude '.aider.*' \
  --exclude 'TASK*.md' \
  "$OLD_NAME/" "$NEW_NAME/"

# (2) Update the project name in wrangler.toml
echo "Updating wrangler.toml..."
sed -i '' "s/$OLD_NAME/$NEW_NAME/g" "$NEW_NAME/wrangler.toml"

# (3) Update the project name in package.json
echo "Updating package.json..."
sed -i '' "s/$OLD_NAME/$NEW_NAME/g" "$NEW_NAME/package.json"

echo "Project copied and renamed to '$NEW_NAME' successfully!"