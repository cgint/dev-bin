#!/bin/bash

# Check if at least two arguments are provided
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <timeout_in_seconds> <command...>"
    exit 1
fi

TIMEOUT="$1"
shift # Removes the first argument (the timeout)
COMMAND="$@"

# Execute the command in the background
$COMMAND &
CMD_PID=$!

# Start a background process to sleep and kill the command if it's still running
(
  sleep "$TIMEOUT"
  # Check if the process is still running before trying to kill it
  if ps -p $CMD_PID > /dev/null; then
    echo "Timeout of $TIMEOUT seconds reached. Killing process $CMD_PID."
    kill $CMD_PID
  fi
) &
WATCHER_PID=$!

# Wait for the command to finish and get its exit code
wait $CMD_PID 2>/dev/null
EXIT_CODE=$?

# Kill the watcher process since the command has finished
kill $WATCHER_PID 2>/dev/null

# Return the exit code of the command
exit $EXIT_CODE
