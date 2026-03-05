#!/bin/bash

echo
if [ -f "wrangler.toml" ]; then
  echo "wrangler.toml found"
  PROJECT_NAME=$(grep 'name = ' wrangler.toml | sed 's/name = "\(.*\)"/\1/')
  if [ -n "$PROJECT_NAME" ]; then
    echo "Project name found: $PROJECT_NAME"
    echo
    npx wrangler pages deployment tail --project-name "$PROJECT_NAME" "$@"
    exit 0
  fi
fi

echo "No wrangler.toml found"
echo
npx wrangler pages deployment tail "$@"