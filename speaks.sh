#!/bin/bash

SPEAK_TO_ME_DIR="$HOME/dev/speak-to-me"

exec uv run --project "$SPEAK_TO_ME_DIR" speaks "$@"
