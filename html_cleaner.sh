#!/bin/bash

# clean_html.sh - Wrapper script for html_cleaner.py
# Usage: clean_html.sh [--minify] input.html output.html

# Get the absolute path to the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Default to normal cleaning (non-minified)
MINIFY_FLAG=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --minify)
      MINIFY_FLAG="--minify"
      shift
      ;;
    *)
      # If this is the first non-flag argument, it's the input file
      if [ -z "$INPUT_FILE" ]; then
        INPUT_FILE="$1"
      # If this is the second non-flag argument, it's the output file
      elif [ -z "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="$1"
      # Too many arguments provided
      else
        echo "Error: Too many arguments provided" >&2
        echo "Usage: clean_html.sh [--minify] input.html output.html" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# Check if required parameters are provided
if [ -z "$INPUT_FILE" ] || [ -z "$OUTPUT_FILE" ]; then
  echo "Error: Input and output files must be specified" >&2
  echo "Usage: clean_html.sh [--minify] input.html output.html" >&2
  exit 1
fi

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: Input file '$INPUT_FILE' not found" >&2
  exit 1
fi

# Convert relative paths to absolute if needed
if [[ ! "$INPUT_FILE" == /* ]]; then
  INPUT_FILE="$(pwd)/$INPUT_FILE"
fi

if [[ ! "$OUTPUT_FILE" == /* ]]; then
  OUTPUT_FILE="$(pwd)/$OUTPUT_FILE"
fi

# Change to the script directory where html_cleaner.py is located
cd "$SCRIPT_DIR"

# Run the HTML cleaner with uv
echo "Cleaning HTML file: $INPUT_FILE"
echo "Output will be saved to: $OUTPUT_FILE"

# Run the script with uv, specifying the dependencies
uv run --with beautifulsoup4 --with lxml html_cleaner.py $MINIFY_FLAG "$INPUT_FILE" "$OUTPUT_FILE"

# Check if command was successful
if [ $? -eq 0 ]; then
  echo "HTML cleaning completed successfully"
else
  echo "Error: HTML cleaning failed" >&2
  exit 1
fi

exit 0 