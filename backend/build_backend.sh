#!/bin/bash
set -euo pipefail

BUILD_ARGS=()
if [[ -n "${IMAGE_FINGERPRINT:-}" ]]; then
  BUILD_ARGS+=(--label "mish.repo_fingerprint=${IMAGE_FINGERPRINT}")
fi

DOCKERFILE="${DOCKERFILE:-Dockerfile}"
docker build "${BUILD_ARGS[@]}" -f "$DOCKERFILE" -t kotlin-backend .
