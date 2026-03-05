#!/bin/bash

# Neo4j Backup Script for knowledge-grafiti
# Creates a single backup of the Neo4j database running in Docker
# Usage: ./neo4j_backup.sh downtime <container_name> <full_output_path>

set -euo pipefail

# Global variable to track if container was stopped
CONTAINER_WAS_STOPPED=false

# Cleanup function to ensure container is restarted
cleanup() {
    local exit_code=$?
    if [ "$CONTAINER_WAS_STOPPED" = true ]; then
        echo ""
        echo "🔄 CRITICAL: Ensuring Neo4j container is restarted..."
        if docker start "$CONTAINER_NAME" > /dev/null 2>&1; then
            echo "✅ SUCCESS: Neo4j container '$CONTAINER_NAME' is running again"
        else
            echo "❌ CRITICAL ERROR: Failed to restart Neo4j container '$CONTAINER_NAME'"
            echo "❌ You MUST manually start the container: docker start $CONTAINER_NAME"
            exit_code=2
        fi
    fi
    exit $exit_code
}

# Set trap to ensure cleanup runs on any exit
trap cleanup EXIT INT TERM

# Check if all arguments are provided
if [ $# -lt 3 ] || [ "$1" != "downtime" ]; then
    echo ""
    echo " ==> ❌ ERROR: All parameters are required including downtime acknowledgment"
    echo ""
    echo "Usage: $0 downtime <container_name> <full_output_path>"
    echo ""
    echo "Example: $0 downtime knowledge-grafiti-neo4j-1 /path/to/my-backup.dump.gz"
    echo ""
    echo "⚠️  WARNING: This backup REQUIRES DATABASE DOWNTIME"
    echo "⚠️  The Neo4j container will be STOPPED during backup"
    echo "⚠️  All connections will be INTERRUPTED"
    echo "⚠️  You must specify 'downtime' as the first parameter to acknowledge this"
    echo ""
    echo "Available containers have neo4j in the name or image:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep -E "(neo4j|NAME)"
    exit 1
fi

# Configuration
CONTAINER_NAME="$2"
DATABASE_NAME="neo4j"
OUTPUT_FILE="$3"

# Check if container is running
if ! docker ps --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    echo "ERROR: Container '$CONTAINER_NAME' is not running."
    echo ""
    echo "Available running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    exit 1
fi

# Create output directory if it doesn't exist
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"

# Stop the Neo4j container
echo "Stopping Neo4j container for backup..."
if docker stop "$CONTAINER_NAME" > /dev/null 2>&1; then
    CONTAINER_WAS_STOPPED=true
    echo "✅ Container stopped successfully"
else
    echo "❌ ERROR: Failed to stop container '$CONTAINER_NAME'"
    exit 1
fi

# Create backup using neo4j-admin database dump
echo "Creating backup..."
if ! docker run --rm \
    --volumes-from "$CONTAINER_NAME" \
    --volume "$OUTPUT_DIR:/host-backup" \
    neo4j:5.26.0 \
    bash -c "neo4j-admin database dump $DATABASE_NAME --to-path=/host-backup --overwrite-destination=true"; then
    echo "❌ ERROR: Failed to create database dump"
    exit 1
fi

# Move and compress to user-specified path
TEMP_DUMP="/host-backup/$DATABASE_NAME.dump"
if [[ "$OUTPUT_FILE" == *.gz ]]; then
    # User wants compressed output
    BASE_FILE="${OUTPUT_FILE%.gz}"
    if ! docker run --rm --volume "$OUTPUT_DIR:/host-backup" alpine:latest \
        sh -c "mv $TEMP_DUMP /host-backup/$(basename "$BASE_FILE") && gzip /host-backup/$(basename "$BASE_FILE")"; then
        echo "❌ ERROR: Failed to compress backup file"
        exit 1
    fi
else
    # User wants uncompressed output
    if ! docker run --rm --volume "$OUTPUT_DIR:/host-backup" alpine:latest \
        mv "$TEMP_DUMP" "/host-backup/$(basename "$OUTPUT_FILE")"; then
        echo "❌ ERROR: Failed to move backup file"
        exit 1
    fi
fi

echo "✅ Backup completed successfully: $OUTPUT_FILE"
echo "🔄 Container will be restarted automatically..." 