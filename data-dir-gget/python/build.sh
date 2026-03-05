#!/bin/bash
set -euo pipefail

if [ "$1" = "runnative" ]; then
    if [ -f .env ]; then
        source .env
    fi
    uv run uvicorn app:app --host 127.0.0.1 --port 8080 --workers 1 --reload
    exit 0
fi

if [ "$1" = "envinit" ]; then
    rm -rf .venv && uv sync
    exit 0
fi

if [ "$1" = "test" ]; then
    shift
    clear; uv run pytest -s -vv $@
    exit 0
fi

echo "YOU MUST SET THESE VARIABLES:"
exit 1
SERVICE_NAME="--- your service name here ---"
PROJECT_ID="gen-lang-client-0910640178"
IMAGE_NAME=$SERVICE_NAME
IMAGE_NAME_REMOTE="europe-west1-docker.pkg.dev/${PROJECT_ID}/docker-image-repo/${IMAGE_NAME}"
SERVICE_NAME_RUN=$IMAGE_NAME
SERVICE_ACCOUNT="${IMAGE_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
TARGET_OVERRIDE="--platform=linux/amd64"
DEPLOY_REGION="europe-west1"


# Run precommit checks in case of remote deployment
if ([ "$1" = "push" ] || [ "$1" = "deploy" ]) && [ -f "./precommit.sh" ]; then
    echo
    echo "Running precommit checks..."
    echo
    if ! ./precommit.sh; then
        echo
        echo "Precommit checks failed. Aborting."
        echo
        exit 1
    fi

    echo
    echo "Precommit checks SUCCESSFUL. Continuing..."
    echo
fi

if [ "$1" = "nobuild" ]; then
    shift
    echo "Skipping build step"
else
    docker build $TARGET_OVERRIDE --progress=plain -t $IMAGE_NAME .
fi


if [ "$1" = "run" ]; then
    docker run $TARGET_OVERRIDE --rm -it --env-file .env -e GEMINI_API_KEY -e BRAVE_SUBSCRIPTION_TOKEN -v $(pwd)/storage:/app/storage -p 8080:8080 $IMAGE_NAME
fi

if [ "$1" = "runfire" ]; then
    source .env.local.fire
    docker run $TARGET_OVERRIDE --rm -it --env-file .env.local.fire -e GEMINI_API_KEY -e BRAVE_SUBSCRIPTION_TOKEN -v $(pwd)/storage:/app/storage -p 8080:8080 $IMAGE_NAME
fi

deploy_to_cloud_run() {
    gcloud run deploy $SERVICE_NAME_RUN --image $IMAGE_NAME_REMOTE --platform managed --region $DEPLOY_REGION \
        --cpu-boost --min-instances=0 --max-instances=1 --cpu=1 --memory=1Gi --execution-environment=gen2 \
        --service-account=$SERVICE_ACCOUNT --env-vars-file=cloudrun.env.yaml \
        --allow-unauthenticated \
        # --add-volume name=tooling-data-gcs,type=cloud-storage,bucket=ai4you-react-tooling-data \
        # --add-volume-mount volume=tooling-data-gcs,mount-path=/app/storage
}

if [ "$1" = "push" ]; then
    echo "Pushing image to remote repository with tag: $IMAGE_NAME"
    docker image tag $IMAGE_NAME $IMAGE_NAME_REMOTE && docker push $IMAGE_NAME_REMOTE
    if [ "$2" = "deploy" ]; then
        deploy_to_cloud_run
    fi
fi

if [ "$1" = "deploy" ]; then
    deploy_to_cloud_run
fi