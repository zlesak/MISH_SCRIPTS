#!/bin/bash

set -euo pipefail

source ./common.sh

MODE="prod"
SKIP_GRADLE=false
BACKEND_BRANCH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --dev)
      MODE="dev"
      shift
      ;;
    --skip-gradle)
      SKIP_GRADLE=true
      shift
      ;;
    --branch-backend=*)
      BACKEND_BRANCH="${1#*=}"
      shift
      ;;
    *)
      echo "Neznamy argument: $1"
      echo "Pouziti: $0 [--dev] [--skip-gradle] [--branch-backend=NAZEV]"
      exit 1
      ;;
  esac
done

if [[ "$MODE" == "dev" ]]; then
  ENV_FILE="$SCRIPT_DIR/.dev.env"
else
  ENV_FILE="$SCRIPT_DIR/.env"
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Chybi env soubor: $ENV_FILE"
  exit 1
fi

export $(grep -v '^#' "$ENV_FILE" | xargs)

if [[ ! -d "$SCRIPT_DIR/backend/repo/.git" ]]; then
  echo "Backend repozitar neexistuje v $SCRIPT_DIR/backend/repo"
  echo "Spust nejdriv ./start_all.sh nebo repozitar naklonuj manualne."
  exit 1
fi

if [[ -n "$BACKEND_BRANCH" ]]; then
  CURRENT_BACKEND_BRANCH=$(git -C "$SCRIPT_DIR/backend/repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ "$CURRENT_BACKEND_BRANCH" != "$BACKEND_BRANCH" ]]; then
    echo "${BOLD}${BLUE}Prepinam backend na vetev $BACKEND_BRANCH...${RESET}"
    git -C "$SCRIPT_DIR/backend/repo" fetch origin
    git -C "$SCRIPT_DIR/backend/repo" checkout "$BACKEND_BRANCH"
  fi
fi

if ! docker network ls --format '{{.Name}}' | grep -qx "$NETWORK_NAME"; then
  echo "${BOLD}${BLUE}Vytvarim sit $NETWORK_NAME...${RESET}"
  docker network create "$NETWORK_NAME" >/dev/null
fi

echo "${BOLD}${GREEN}BACKEND ONLY DEPLOY${RESET}"

BACKEND_FINGERPRINT="$(get_repo_fingerprint "$SCRIPT_DIR/backend/repo")"
NEEDS_BACKEND_BUILD=true
if docker image inspect "$BACKEND_CONTAINER" >/dev/null 2>&1 && image_matches_fingerprint "$BACKEND_CONTAINER" "$BACKEND_FINGERPRINT"; then
  NEEDS_BACKEND_BUILD=false
fi

if [[ "$NEEDS_BACKEND_BUILD" == "true" ]]; then
  if [[ "$SKIP_GRADLE" == "true" ]]; then
    echo "${BLUE}Pozn.: --skip-gradle nemá vliv (build probíhá uvnitř Dockerfile).${RESET}"
  else
    echo "${BLUE}Pozn.: build probíhá uvnitř Dockerfile (žádný Gradle na hostu).${RESET}"
  fi
else
  echo "${BOLD}${BLUE}Backend image je aktuální ($BACKEND_FINGERPRINT), přeskakuji build...${RESET}"
fi

if [[ "$NEEDS_BACKEND_BUILD" == "true" ]]; then
  if [[ -f "$SCRIPT_DIR/backend/repo/mongo/certs-main/ca.pem" ]]; then
    cp "$SCRIPT_DIR/backend/repo/mongo/certs-main/ca.pem" "$SCRIPT_DIR/backend/ca.pem"
  elif [[ ! -f "$SCRIPT_DIR/backend/ca.pem" ]]; then
    echo "Chybi ca.pem (nenalezeno ani v backend/repo/mongo/certs-main/ca.pem ani v backend/ca.pem)."
    echo "Spust nejdriv full start nebo vygeneruj certifikaty."
    exit 1
  fi
fi

cleanup() {
  rm -f "$SCRIPT_DIR/backend/ca.pem"
}
trap cleanup EXIT

echo "${BOLD}${BLUE}Buildim Docker image backendu...${RESET}"
pushd "$SCRIPT_DIR/backend" >/dev/null
if [[ "$NEEDS_BACKEND_BUILD" == "true" ]]; then
  IMAGE_FINGERPRINT="$BACKEND_FINGERPRINT" bash ./build_backend.sh
fi
popd >/dev/null

echo "${BOLD}${BLUE}Restartuji pouze backend kontejner...${RESET}"
docker rm -f "$BACKEND_CONTAINER" 2>/dev/null || true

if [[ "${MONGO_HOST:-}" == *"mongo-main"* ]]; then
  wait_container_on_network "mongo-main" "$NETWORK_NAME" 60 || handle_error
  wait_container_on_network "mongo-replica-1" "$NETWORK_NAME" 60 || handle_error
  wait_container_on_network "mongo-replica-2" "$NETWORK_NAME" 60 || handle_error
fi

docker run -d \
  --env-file "$ENV_FILE" \
  --name "$BACKEND_CONTAINER" \
  --restart unless-stopped \
  --network "$NETWORK_NAME" \
  -p 8050:8050 \
  "$BACKEND_CONTAINER"

echo "${BOLD}${GREEN}Backend redeploy dokoncen.${RESET}"
