#! /bin/bash

# gem.sh
#
# A wrapper script for the 'gemini' CLI tool that simplifies model selection and 
# ensures the correct authentication environment by unsetting specific Google Cloud 
# and Vertex AI environment variables.
#
# Usage: ./gem.sh [flash|pro] [gemini_args...]
#
# If no model is specified, it defaults to the 'gemini' command's default model.

# Load environment variables from local .env file
# source "$(dirname "$0")/_env_loader.sh"

# Now we use GEMINI_API_KEY for auth as 3 pro preview is not available through Vertext AI and our Project(-Location)
# unset GEMINI_API_KEY # so we can use gemini 3 model series
unset GOOGLE_API_KEY # to avoid 'Both GOOGLE_API_KEY and GEMINI_API_KEY are set. Using GOOGLE_API_KEY.' - we use GEMINI_API_KEY
unset VERTEXAI_LOCATION
unset VERTEXAI_PROJECT
unset VERTEXAI_LOCATION
unset GOOGLE_CLOUD_PROJECT
unset GOOGLE_CLOUD_LOCATION

model=""
if [[ "$1" == "flash" ]]; then
  model="-m gemini-3-flash-preview"
  shift
elif [[ "$1" == "pro" ]]; then
  model="-m gemini-3.1-pro-preview"
  shift
elif [[ "$1" == "lite" ]]; then
  model="-m gemini-3.1-flash-lite-preview"
  shift
fi

# if [[ -z "$model" ]]; then
#   echo "Starting gemini with default from gemini cli tool" >&2
# else
#   echo "Starting gemini with model: $model" >&2
# fi
gemini $model "$@"