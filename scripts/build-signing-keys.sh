#!/bin/sh
set -eu

# Create a signing configuration to prevent cosign making network calls
docker run --rm --network none \
  --volume "$PWD/_output:/keys" \
  --env COSIGN_PASSWORD="password123" \
  --workdir /keys \
  docker.io/cleanstart/cosign:latest \
signing-config create \
--out /keys/cosign-config.json

docker run --rm --network none \
  --volume "$PWD/_output:/keys" \
  --workdir /keys \
  docker.io/cleanstart/cosign:latest \
  trusted-root create --out trusted-root.json

docker run --rm --network none \
  --volume "$PWD/_output:/keys" \
  --env COSIGN_PASSWORD="password123" \
  --workdir /keys \
  docker.io/cleanstart/cosign:latest \
  generate-key-pair --output-key-prefix cosign-key