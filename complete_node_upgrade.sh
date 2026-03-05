#! /bin/bash

if [ ! -f "package.json" ]; then
    echo "Error: package.json not found. Exiting."
    exit 1
fi

# Check if ncu (npm-check-updates) is installed
if ! command -v ncu &> /dev/null
then
    echo "ncu is not installed. Installing ncu..."
    npm install -g npm-check-updates
    if [ $? -eq 0 ]; then
        echo "ncu installed successfully."
    else
        echo "Failed to install ncu. Please install it manually."
        exit 1
    fi
fi

echo "Upgrading dependencies with ncu..."
ncu -u

echo
read -p "Is it okay to delete the node_modules directory? (y/N): " response
response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
if [[ $response == "y" ]]; then
    rm -rf node_modules
    echo "node_modules directory deleted."
else
    echo "Skipping deletion of node_modules directory."
fi

echo
echo "Installing dependencies with npm install..."
npm install