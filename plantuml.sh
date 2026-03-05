#!/bin/bash

# PlantUML Docker Runner Script (pipe-based)
# Usage: ./plantuml.sh <file.puml> [output_format]
# Example: ./plantuml.sh diagram.puml svg

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print usage if no arguments provided
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage:${NC} $0 <file.puml> [output_format]"
    echo ""
    echo "Arguments:"
    echo "  file.puml      Path to PlantUML source file (required)"
    echo "  output_format  Output format (png, svg, pdf, txt, etc.)"
    echo "                 Default: svg"
    echo ""
    echo "Examples:"
    echo "  $0 diagram.puml (defaults to svg)"
    echo "  $0 diagram.puml png"
    echo "  $0 diagram.puml svg (default)"
    echo ""
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FORMAT="${2:-svg}"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error:${NC} File '$INPUT_FILE' not found"
    exit 1
fi

# Check if input file has .puml extension
if [[ ! "$INPUT_FILE" =~ \.puml$ ]]; then
    echo -e "${YELLOW}Warning:${NC} File '$INPUT_FILE' does not have .puml extension"
fi

# Get absolute path of input file
INPUT_FILE_ABS=$(cd "$(dirname "$INPUT_FILE")" && pwd)/$(basename "$INPUT_FILE")
INPUT_DIR=$(dirname "$INPUT_FILE_ABS")
INPUT_BASENAME=$(basename "$INPUT_FILE_ABS" .puml)

# Output file will be in the same directory as input
OUTPUT_FILE="$INPUT_DIR/${INPUT_BASENAME}.${OUTPUT_FORMAT}"

echo -e "${GREEN}Generating PlantUML diagram...${NC}"
echo "  Input:  $INPUT_FILE_ABS"
echo "  Output: $OUTPUT_FILE"
echo "  Format: $OUTPUT_FORMAT"
echo ""

# Run PlantUML using Docker with pipe
cat "$INPUT_FILE_ABS" | docker run --rm -i plantuml/plantuml:latest -t"$OUTPUT_FORMAT" -pipe > "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Success!${NC} Output saved to: $OUTPUT_FILE"
else
    echo -e "${RED}✗ Error:${NC} Failed to generate diagram"
    exit 1
fi
