#!/bin/bash

# Script to load environment variables from .env file

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found in current directory"
    exit 1
fi

# Read and export variables from .env file
echo "Loading environment variables from .env file..."

# Export variables while handling comments and empty lines
set -a
source .env
set +a

echo "Environment variables loaded successfully!"
echo ""
echo "Loaded variables:"
grep -v '^#' .env | grep -v '^$' | cut -d '=' -f 1
