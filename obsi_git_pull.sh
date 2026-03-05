#! /bin/bash

if [ -z "$OBSI_DIR" ]; then
    echo "Error: OBSI_DIR environment variable is not set"
    exit 1
fi

echo Temporarily changing directory to $OBSI_DIR ...
cd "$OBSI_DIR" || exit 1
git pull
cd -
