#!/bin/bash

# Default to 0.14.3-rc3 if no version is provided
# Note: GitHub tags for pre-releases often include -rcX
VERSION=${1:-"0.14.3-rc3"}

# Ensure version starts with 'v' for the URL
TAG=$VERSION
[[ $TAG != v* ]] && TAG="v$TAG"

URL="https://github.com/ollama/ollama/releases/download/$TAG/Ollama-darwin.zip"
TEMP_DIR=$(mktemp -d)

echo "--- Ollama macOS Installer ---"
echo "Target Tag: $TAG"
echo "Download URL: $URL"

# 1. Download
echo "Downloading..."
curl -L --fail "$URL" -o "$TEMP_DIR/Ollama-darwin.zip"

if [ $? -ne 0 ]; then
    echo "Error: Download failed. The tag '$TAG' might not exist or the URL is invalid."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Check file size (should be > 1MB)
FILE_SIZE=$(stat -f%z "$TEMP_DIR/Ollama-darwin.zip")
if [ "$FILE_SIZE" -lt 1000000 ]; then
    echo "Error: Downloaded file is too small ($FILE_SIZE bytes). It is likely an error page."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 2. Unzip
echo "Extracting..."
unzip -q "$TEMP_DIR/Ollama-darwin.zip" -d "$TEMP_DIR"

if [ ! -d "$TEMP_DIR/Ollama.app" ]; then
    echo "Error: Ollama.app not found in the extracted files."
    # Check if it's nested or has a different name
    ls -R "$TEMP_DIR"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 3. Install
echo "Installing to /Applications (requires sudo)..."
# Kill Ollama if it's running
pkill Ollama 2>/dev/null

if [ -d "/Applications/Ollama.app" ]; then
    sudo rm -rf "/Applications/Ollama.app"
fi

sudo mv "$TEMP_DIR/Ollama.app" /Applications/

# 4. Cleanup
echo "Cleaning up..."
rm -rf "$TEMP_DIR"

echo "Success! Ollama $TAG is now in your Applications folder."
echo "You can launch it via Spotlight or by running: open /Applications/Ollama.app"