#!/bin/bash

INPUT_FILE="$1"
OUTPUT_FILE="${INPUT_FILE%.*}.webp"

cwebp "$INPUT_FILE" -o "$OUTPUT_FILE"