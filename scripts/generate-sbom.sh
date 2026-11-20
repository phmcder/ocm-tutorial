#!/bin/sh
set -eu

# Use syft to generate an SBOM for the specified image and output it to the given file
docker run --rm \
  --network "container:$(docker compose ps -q zob)" \
  -e SYFT_CHECK_FOR_APP_UPDATE=false \
  -e SYFT_REGISTRY_INSECURE_USE_HTTP=true \
  docker.io/anchore/syft:v1.57.2 \
  scan "registry:$1" \
  -o spdx-json > "$2"