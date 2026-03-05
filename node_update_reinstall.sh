#! /bin/bash

if [ ! -f "package.json" ]; then
    echo "Error: package.json not found. Exiting."
    exit 1
fi


echo "Removing node_modules and package-lock.json..."
rm -rf node_modules package-lock.json

echo
echo "Installing dependencies..."
npm install

echo
echo "Updating dependencies..."
npm update

echo
echo "Fixing vulnerabilities..."
npm audit fix
