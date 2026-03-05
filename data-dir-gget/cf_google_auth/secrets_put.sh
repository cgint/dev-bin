#!/bin/bash
set -euo pipefail

KEY_NAME=$1

if [ -z "$KEY_NAME" ]; then
  echo "Usage: $0 <key-name> put|env"
  echo "  put: put the secrets to cloudflare"
  echo "  env: add the secrets to the .env file"
  exit 1
fi

KEY_JSON=$(cd "$HOME/dev/infra-gcp-glc"; tofu output -raw "$KEY_NAME")

KEY_JSON=$(printf '%q' "$KEY_JSON" | sed "s/^\\$'//g" | sed "s/'$//g")
KEY_JSON_PRIVATE_KEY=$(echo "$KEY_JSON" | jq -r .private_key)
KEY_JSON_PRIVATE_KEY=$(printf '%q' "$KEY_JSON_PRIVATE_KEY" | sed "s/^\\$'//g" | sed "s/'$//g")
KEY_JSON_CLIENT_EMAIL=$(echo "$KEY_JSON" | jq -r .client_email)
KEY_JSON_PRIVATE_KEY_ID=$(echo "$KEY_JSON" | jq -r .private_key_id)
KEY_JSON_PROJECT_ID=$(echo "$KEY_JSON" | jq -r .project_id)

# echo "$KEY_JSON_PRIVATE_KEY"
echo "EMAIL = $KEY_JSON_CLIENT_EMAIL"
echo "PRIVATE_KEY_ID = $KEY_JSON_PRIVATE_KEY_ID"
echo "PROJECT_ID = $KEY_JSON_PROJECT_ID"
echo

if [ "$2" == "put" ]; then
  echo "$KEY_JSON_PRIVATE_KEY" | npx wrangler pages secret put VITE_GSA_PRIVATE_KEY
  echo "$KEY_JSON_CLIENT_EMAIL" | npx wrangler pages secret put VITE_GSA_CLIENT_EMAIL
  echo "$KEY_JSON_PRIVATE_KEY_ID" | npx wrangler pages secret put VITE_GSA_PRIVATE_KEY_ID
  echo "$KEY_JSON_PROJECT_ID" | npx wrangler pages secret put VITE_GSA_PROJECT_ID
  echo "Secrets set successfully using wrangler."
else
  echo "Secrets not set using wrangler. Use 'put' to set them."
fi

if [ "$2" == "env" ]; then
  TARGET_FILE=".env"
  echo "\n\n# Created by secrets_put.sh" >> $TARGET_FILE
  KEY_JSON_PRIVATE_KEY=$(echo "$KEY_JSON" | jq -r .private_key)
  echo "VITE_GSA_PRIVATE_KEY=\"$(printf '%s' "$KEY_JSON_PRIVATE_KEY" | perl -pe 's/\n/\\\\n/g')\"" >> $TARGET_FILE
  echo "VITE_GSA_CLIENT_EMAIL=\"$KEY_JSON_CLIENT_EMAIL\"" >> $TARGET_FILE
  echo "VITE_GSA_PRIVATE_KEY_ID=\"$KEY_JSON_PRIVATE_KEY_ID\"" >> $TARGET_FILE
  echo "VITE_GSA_PROJECT_ID=\"$KEY_JSON_PROJECT_ID\"" >> $TARGET_FILE
  echo "Secrets set successfully in .env file."
else
  echo "Secrets not set in .env file. Use 'env' to set them."
fi
