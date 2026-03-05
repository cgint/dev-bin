#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

if [ "$1" = "runnative" ]; then
    npm run dev
    exit 0
fi

# Define image name and tag
IMAGE_NAME="cgint/eu-logs-ai4you"
LAST_COMMIT_DATE_TIME=$(git log -1 --pretty=format:"%ad" --date=format:'%Y%m%d_%H%M%S')
echo "Last commit date time: $LAST_COMMIT_DATE_TIME"
TAG="v2-$LAST_COMMIT_DATE_TIME" # Or use a specific version, e.g., $(git rev-parse --short HEAD)


# Build the Docker image for linux/amd64 platform with plain progress
echo "Building Docker image for linux/amd64: $IMAGE_NAME:$TAG"
docker build --platform linux/amd64 --progress=plain -t "$IMAGE_NAME:$TAG" .

echo "Docker image built successfully: $IMAGE_NAME:$TAG"

# You can add commands here to push the image to a registry if needed
# Handle command line parameter
if [ "$1" = "push" ]; then
    echo "Pushing Docker image..."
    docker push "$IMAGE_NAME:$TAG"
elif [ "$1" = "run" ]; then
    echo "Running Docker container..."
    docker run --rm -it --init -p 3000:3000 "$IMAGE_NAME:$TAG"
fi