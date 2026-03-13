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

if [[ "$SKIP_GRADLE" != true ]]; then
  echo "${BOLD}${BLUE}Buildim backend (bootJar -x test)...${RESET}"
  pushd "$SCRIPT_DIR/backend/repo" >/dev/null
  ./gradlew bootJar -x test
  popd >/dev/null
else
  echo "${BLUE}Preskakuji Gradle build (--skip-gradle).${RESET}"
fi

BACKEND_JAR=$(ls -t "$SCRIPT_DIR"/backend/repo/build/libs/*.jar 2>/dev/null | grep -v -- '-plain\.jar$' | head -n 1 || true)
if [[ -z "${BACKEND_JAR:-}" ]]; then
  echo "Nenasel jsem backend jar v $SCRIPT_DIR/backend/repo/build/libs"
  exit 1
fi

cp "$BACKEND_JAR" "$SCRIPT_DIR/backend/app.jar"

if [[ -f "$SCRIPT_DIR/backend/repo/mongo/certs-main/ca.pem" ]]; then
  cp "$SCRIPT_DIR/backend/repo/mongo/certs-main/ca.pem" "$SCRIPT_DIR/backend/ca.pem"
elif [[ ! -f "$SCRIPT_DIR/backend/ca.pem" ]]; then
  echo "Chybi ca.pem (nenalezeno ani v backend/repo/mongo/certs-main/ca.pem ani v backend/ca.pem)."
  echo "Spust nejdriv full start nebo vygeneruj certifikaty."
  exit 1
fi

cleanup() {
  rm -f "$SCRIPT_DIR/backend/ca.pem"
}
trap cleanup EXIT

echo "${BOLD}${BLUE}Buildim Docker image backendu...${RESET}"
pushd "$SCRIPT_DIR/backend" >/dev/null
bash ./build_backend.sh "${MONGO_PASSWORD:-adminpassword}"
popd >/dev/null

echo "${BOLD}${BLUE}Restartuji pouze backend kontejner...${RESET}"
docker rm -f "$BACKEND_CONTAINER" 2>/dev/null || true

docker run -d \
  --env-file "$ENV_FILE" \
  --name "$BACKEND_CONTAINER" \
  --restart unless-stopped \
  --network "$NETWORK_NAME" \
  -p 8050:8050 \
  "$BACKEND_CONTAINER"

echo "${BOLD}${GREEN}Backend redeploy dokoncen.${RESET}"
