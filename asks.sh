#!/bin/bash

DOC_AGENT_BM25_DIR_OPTION_1="$HOME/dev/agents-temp/"
DOC_AGENT_BM25_DIR_OPTION_2="$HOME/dev/doc-expert-agent-mcp/"
CMD_EXECUTE_PREFIX="uv run ask"

DOC_AGENT_BM25_DIR="$DOC_AGENT_BM25_DIR_OPTION_1"
if [ ! -d "$DOC_AGENT_BM25_DIR" ]; then
    DOC_AGENT_BM25_DIR="$DOC_AGENT_BM25_DIR_OPTION_2"
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0 <topic> <question>"
    echo
    echo "Available topics: "
    (cd $DOC_AGENT_BM25_DIR && $CMD_EXECUTE_PREFIX --list-topics)
    exit 0
fi

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <topic> <question>"
    echo
    echo "Available topics: "
    (cd $DOC_AGENT_BM25_DIR && $CMD_EXECUTE_PREFIX --list-topics)
    exit 1
fi

TOPIC="$1"
if [ "$TOPIC" = "agent" ]; then
    TOPIC="agentic-sessions"
fi
shift

echo "Asking question in topic '$TOPIC': $@"
echo

(cd $DOC_AGENT_BM25_DIR && $CMD_EXECUTE_PREFIX "$TOPIC" "$@")