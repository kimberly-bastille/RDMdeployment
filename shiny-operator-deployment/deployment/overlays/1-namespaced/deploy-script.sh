#!/bin/bash

set -a
source .env
set +a

echo "Creating local files"

for file in resources/*; do
    envsubst < "$file" > "local/$(basename "$file")"
done

echo "Applying kustomize"

kustomize build . | kubectl apply -f - --server-side