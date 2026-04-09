#!/bin/bash

# Update and upgrade npm global packages and Homebrew

ALL_MODE="false"
# Base npm packages
NPM_PACKAGES="@github/copilot @google/gemini-cli @fission-ai/openspec@latest @mariozechner/pi-coding-agent"
NPM_PACKAGES_ALL_ADDON="@openai/codex @googleworkspace/cli agent-browser"
# disabled from all_addon "@anthropic-ai/claude-code opencode-ai"

if [ "$1" == "all" ]; then
    ALL_MODE="true"
    # Add extra npm packages
    NPM_PACKAGES="$NPM_PACKAGES $NPM_PACKAGES_ALL_ADDON"
fi

echo
echo "Updating:"
echo " - brew"
echo " - npm packages ($NPM_PACKAGES)"
echo " - gcloud components"
echo " - cursor extensions"
echo " - vscode extensions"
echo

# Run consolidated npm install in a single background process to avoid lock contention
(
    echo "Starting consolidated npm install..."
    npm i -g $NPM_PACKAGES
    
    if [ "$ALL_MODE" == "true" ]; then
        echo "Running agent-browser post-install..."
        agent-browser install --with-deps
    fi
) &

cursor --update-extensions &

code --update-extensions &

(brew update; brew upgrade) &

(echo Yn | gcloud components update) &

if [ "$ALL_MODE" == "true" ]; then
    echo "ALL MODE: is enabled..."
fi

wait