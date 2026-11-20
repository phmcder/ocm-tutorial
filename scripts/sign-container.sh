#!/bin/sh
set -eu

IMAGE_DIGEST=$(oras resolve --plain-http "$1")
IMAGE_REF="${1%:*}@$IMAGE_DIGEST"

docker run --rm --network "container:$(docker compose ps -q zob)" \
  --env COSIGN_PASSWORD="password123" \
  --volume "$PWD/_output:/keys" \
  --workdir /keys \
  docker.io/cleanstart/cosign:latest \
  sign --upload=false \
  --key cosign-key.key \
  --allow-http-registry \
  --signing-config cosign-config.json \
  --trusted-root trusted-root.json \
  --bundle $2 \
  $IMAGE_REF
