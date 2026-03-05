#! /bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 \"<commit-message>\""
    echo "Error: Please provide exactly one commit message as a parameter"
    exit 1
fi

if [ -z "$OBSI_DIR" ]; then
    echo "Error: OBSI_DIR environment variable is not set"
    exit 1
fi

echo Temporarily changing directory to $OBSI_DIR ...
cd "$OBSI_DIR" || exit 1
git pull
git add .
git commit -m "$1"
git push
cd -
