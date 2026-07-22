#!/usr/bin/env bash
set -euo pipefail

# Script location and extensions directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_DIR="$SCRIPT_DIR/extensions"
PI_DIR="$HOME/.pi"

AUTO_CONFIRM=false
for arg in "$@"; do
  case "$arg" in
    -y|--yes)
      AUTO_CONFIRM=true
      ;;
    -h|--help)
      echo "Usage: $0 [-y|--yes]"
      echo "  Scans extensions/*.ts, finds matching copies in ~/.pi,"
      echo "  shows pending updates (dry-run summary), and asks for user OK before copying."
      exit 0
      ;;
  esac
done

if [ ! -d "$EXT_DIR" ]; then
  echo "Error: extensions directory not found at $EXT_DIR" >&2
  exit 1
fi

echo "=================================================="
echo " Extension Sync Scanner"
echo " Source: $EXT_DIR"
echo " Search Root: $PI_DIR"
echo "=================================================="
echo

PENDING_SRC=()
PENDING_DEST=()

TOTAL_CHECKED=0
UP_TO_DATE=0
PENDING_COUNT=0

shopt -s nullglob
EXT_FILES=("$EXT_DIR"/*.ts)
shopt -u nullglob

if [ ${#EXT_FILES[@]} -eq 0 ]; then
  echo "No .ts files found in $EXT_DIR"
  exit 0
fi

for src in "${EXT_FILES[@]}"; do
  filename="$(basename "$src")"
  echo "Checking $filename..."

  # Find all matching files in ~/.pi (ignoring the source file itself)
  matches=$(find "$PI_DIR" -type f -name "$filename" 2>/dev/null || true)

  if [ -z "$matches" ]; then
    echo "  (No matching target files found in $PI_DIR)"
    echo
    continue
  fi

  while IFS= read -r dest; do
    [ -z "$dest" ] && continue
    # Normalize paths for comparison
    src_real="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
    dest_real="$(cd "$(dirname "$dest")" 2>/dev/null && pwd)/$(basename "$dest")" || dest_real="$dest"
    
    [ "$src_real" = "$dest_real" ] && continue

    TOTAL_CHECKED=$((TOTAL_CHECKED + 1))

    if cmp -s "$src" "$dest"; then
      echo "  [UP TO DATE] $dest"
      UP_TO_DATE=$((UP_TO_DATE + 1))
    else
      echo "  [NEEDS UPDATE] $dest"
      PENDING_SRC+=("$src")
      PENDING_DEST+=("$dest")
      PENDING_COUNT=$((PENDING_COUNT + 1))
    fi
  done <<< "$matches"
  echo
done

echo "--------------------------------------------------"
echo " Summary: $TOTAL_CHECKED targets checked ($UP_TO_DATE up-to-date, $PENDING_COUNT pending update)"
echo "--------------------------------------------------"

if [ $PENDING_COUNT -eq 0 ]; then
  echo "All targets are up to date. Nothing to do."
  exit 0
fi

echo
echo "The following $PENDING_COUNT update(s) WOULD be performed:"
for ((i=0; i<PENDING_COUNT; i++)); do
  echo "  cp \"${PENDING_SRC[i]}\" \"${PENDING_DEST[i]}\""
done
echo

if [ "$AUTO_CONFIRM" = false ]; then
  if [ -t 0 ]; then
    read -p "Do you want to apply these updates now? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Aborted by user. No files were changed."
      exit 0
    fi
  else
    echo "Non-interactive terminal detected. Run with -y or --yes to apply updates."
    exit 0
  fi
fi

echo "Applying updates..."
for ((i=0; i<PENDING_COUNT; i++)); do
  cp "${PENDING_SRC[i]}" "${PENDING_DEST[i]}"
  echo "  [COPIED] ${PENDING_DEST[i]}"
done

echo "Done! All target files successfully updated."
