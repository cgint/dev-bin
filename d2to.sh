#!/bin/bash

# D2 Diagram Converter Script
# Usage: d2to.sh [-d] <file.d2> [output_file] [d2_options...]
# Defaults: if no d2_options are provided, uses: -t 105 -s
# Example: d2to.sh diagram.d2 output.svg -s -t 105
#          d2to.sh -d diagram.d2 output.svg -s -t 105 (use Docker)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

USE_DOCKER=false

# Function to show usage
show_usage() {
    echo -e "${YELLOW}Usage:${NC} $0 [-d] <file.d2> [output_file] [d2_options...]"
    echo ""
    echo "Arguments:"
    echo "  -h           Show this help message"
    echo "  -d           Use Docker instead of local installation"
    echo "  file.d2      Path to D2 source file (required)"
    echo "  output_file  Output file path (optional, defaults to input filename with .svg extension)"
    echo "  d2_options   Options to pass to d2 (if omitted, defaults to: -t 105 -s)"
    echo "               The rendering layout defaults to \`-l dagre\` which is good at hierarchical 'top-to-bottom' flow (more human appealing usually - preferred)."
    echo "               Use \`-l elk\` to select the Eclipse Layout Kernel layout engine in case you really need orthogonal (right-angle) routing."
    echo ""
    echo "Examples:"
    echo "  $0 diagram.d2 (defaults to diagram.svg with: -t 105 -s)"
    echo "  $0 diagram.d2 output.svg"
    echo "  $0 diagram.d2 output.svg -s -t 105"
    echo "  $0 -d diagram.d2 output.svg -s -t 105 (use Docker)"
    echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -d)
            USE_DOCKER=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Print usage if no arguments provided
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

INPUT_FILE="$1"

# If input file doesn't have .d2 extension, try adding it
if [[ ! "$INPUT_FILE" =~ \.d2$ ]]; then
    # Check if file with .d2 extension exists
    if [ -f "${INPUT_FILE}.d2" ]; then
        INPUT_FILE="${INPUT_FILE}.d2"
    fi
fi

# Determine output file and collect d2 extra arguments
# If second arg exists and doesn't start with -, it's the output file
# Everything after input (and optional output) goes to d2
D2_EXTRA_ARGS=()
if [ $# -ge 2 ] && [[ ! "$2" =~ ^- ]]; then
    # Second argument is output file
    OUTPUT_FILE="$2"
    # Collect remaining args as d2 options
    shift 2
    while [ $# -gt 0 ]; do
        D2_EXTRA_ARGS+=("$1")
        shift
    done
else
    # No output file specified, or second arg is a d2 option
    OUTPUT_FILE=""
    shift
    while [ $# -gt 0 ]; do
        D2_EXTRA_ARGS+=("$1")
        shift
    done
fi

# Default d2 options if none provided
# If user provides any d2 options, use only those provided.
if [ ${#D2_EXTRA_ARGS[@]} -eq 0 ]; then
    D2_EXTRA_ARGS=(-t 105 -s)
fi

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error:${NC} File '$INPUT_FILE' not found"
    exit 1
fi

# Check if input file has .d2 extension
if [[ ! "$INPUT_FILE" =~ \.d2$ ]]; then
    echo -e "${YELLOW}Warning:${NC} File '$INPUT_FILE' does not have .d2 extension"
fi

# Get directory and basename for input file
INPUT_DIR=$(cd "$(dirname "$INPUT_FILE")" && pwd)
INPUT_BASENAME=$(basename "$INPUT_FILE" .d2)

# Set output file if not provided
if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="$INPUT_DIR/${INPUT_BASENAME}.svg"
else
    # If output file is relative, make it relative to input directory
    if [[ ! "$OUTPUT_FILE" =~ ^/ ]]; then
        OUTPUT_FILE="$INPUT_DIR/$OUTPUT_FILE"
    fi
fi

# Function to check if d2 is installed
check_d2_installed() {
    command -v d2 >/dev/null 2>&1
}

# Function to install d2
install_d2() {
    echo -e "${YELLOW}d2 is not installed.${NC}"
    read -p "Would you like to install it using Homebrew? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Installing d2...${NC}"
        brew install d2
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ d2 installed successfully${NC}"
            return 0
        else
            echo -e "${RED}✗ Error:${NC} Failed to install d2"
            exit 1
        fi
    else
        echo -e "${RED}Error:${NC} d2 is required but not installed"
        exit 1
    fi
}

echo -e "${GREEN}Generating D2 diagram...${NC}"
echo "  Input:  $INPUT_DIR/$INPUT_BASENAME.d2"
echo "  Output: $OUTPUT_FILE"
echo "  Mode:   $([ "$USE_DOCKER" = true ] && echo "Docker" || echo "Local")"
echo "  Options: ${D2_EXTRA_ARGS[*]}"
echo ""

# Common setup: cd to input dir and build command with basenames
cd "$INPUT_DIR"
D2_CMD_ARGS=("${D2_EXTRA_ARGS[@]}" "$INPUT_BASENAME.d2" "$(basename "$OUTPUT_FILE")")

echo -ne "${YELLOW}Command:${NC} "
printf '%q ' d2 "${D2_CMD_ARGS[@]}"

if [ "$USE_DOCKER" = true ]; then
    echo " (executed inside Docker)"
    docker run --rm -v "$(pwd):/home/debian/src" terrastruct/d2 "${D2_CMD_ARGS[@]}"
    EXIT_CODE=$?
else
    echo
    if ! check_d2_installed; then
        install_d2
    fi
    d2 "${D2_CMD_ARGS[@]}"
    EXIT_CODE=$?
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Success!${NC} Output saved to: $OUTPUT_FILE"
else
    echo -e "${RED}✗ Error:${NC} Failed to generate diagram"
    exit 1
fi
