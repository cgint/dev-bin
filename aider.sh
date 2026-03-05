#!/bin/bash
SOURCE_DIR="$HOME/dev/AI/aider-runtime"

enter_venv() {
    echo "Entering aider-pip-environment under $SOURCE_DIR/.venv/..."
    source "$SOURCE_DIR/.venv/bin/activate"
}

exit_venv() {
    echo "Exiting aider-pip-environment under $SOURCE_DIR/.venv/..."
    deactivate
}

enter_venv

export AIDER_AUTO_COMMITS=false
export AIDER_AUTO_LINT=false
export AIDER_AUTO_TEST=false
export AIDER_STREAM=false
export AIDER_CACHE_PROMPTS=true
export AIDER_ANALYTICS=false
export AIDER_MAP_TOKENS=4096

aider "$@"

exit_venv
