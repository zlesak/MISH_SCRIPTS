#!/bin/bash

set -euo pipefail

source ./common.sh

MODE="prod"
SKIP_MAVEN=false
FRONTEND_BRANCH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --dev)
      MODE="dev"
      shift
      ;;
    --skip-maven)
      SKIP_MAVEN=true
      shift
      ;;
    --branch-frontend=*)
      FRONTEND_BRANCH="${1#*=}"
      shift
      ;;
    *)
      echo "Neznamy argument: $1"
      echo "Pouziti: $0 [--dev] [--skip-maven] [--branch-frontend=NAZEV]"
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

if [[ ! -d "$SCRIPT_DIR/frontend/repo/.git" ]]; then
  echo "Frontend repozitar neexistuje v $SCRIPT_DIR/frontend/repo"
  echo "Spust nejdriv ./start_all.sh nebo repozitar naklonuj manualne."
  exit 1
fi

if [[ -n "$FRONTEND_BRANCH" ]]; then
  CURRENT_FRONTEND_BRANCH=$(git -C "$SCRIPT_DIR/frontend/repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ "$CURRENT_FRONTEND_BRANCH" != "$FRONTEND_BRANCH" ]]; then
    echo "${BOLD}${BLUE}Prepinam frontend na vetev $FRONTEND_BRANCH...${RESET}"
    git -C "$SCRIPT_DIR/frontend/repo" fetch origin
    git -C "$SCRIPT_DIR/frontend/repo" checkout "$FRONTEND_BRANCH"
  fi
fi

if ! docker network ls --format '{{.Name}}' | grep -qx "$NETWORK_NAME"; then
  echo "${BOLD}${BLUE}Vytvarim sit $NETWORK_NAME...${RESET}"
  docker network create "$NETWORK_NAME" >/dev/null
fi

echo "${BOLD}${GREEN}FRONTEND ONLY DEPLOY${RESET}"

if [[ "$SKIP_MAVEN" != true ]]; then
  echo "${BOLD}${BLUE}Buildim frontend (mvnw clean package -DskipTests -Pproduction)...${RESET}"
  pushd "$SCRIPT_DIR/frontend/repo" >/dev/null
  bash ./mvnw clean package -DskipTests -Pproduction
  popd >/dev/null
else
  echo "${BLUE}Preskakuji Maven build (--skip-maven).${RESET}"
fi

FRONTEND_JAR=$(ls -t "$SCRIPT_DIR"/frontend/repo/target/*.jar 2>/dev/null | grep -v -- '/original-' | head -n 1 || true)
if [[ -z "${FRONTEND_JAR:-}" ]]; then
  echo "Nenasel jsem frontend jar v $SCRIPT_DIR/frontend/repo/target"
  exit 1
fi

cp "$FRONTEND_JAR" "$SCRIPT_DIR/frontend/app.jar"

echo "${BOLD}${BLUE}Buildim Docker image frontendu...${RESET}"
pushd "$SCRIPT_DIR/frontend" >/dev/null
bash ./build_frontend.sh
popd >/dev/null

echo "${BOLD}${BLUE}Restartuji pouze frontend kontejner...${RESET}"
docker rm -f "$FRONTEND_CONTAINER" 2>/dev/null || true

docker run -d \
  --env-file "$ENV_FILE" \
  --name "$FRONTEND_CONTAINER" \
  --restart unless-stopped \
  --network "$NETWORK_NAME" \
  -p 8081:8081 \
  "$FRONTEND_CONTAINER"

echo "${BOLD}${BLUE}Kopiruju webapp assets do frontend kontejneru...${RESET}"
docker cp "$SCRIPT_DIR/frontend/repo/src/main/webapp" "$FRONTEND_CONTAINER:/app/webapp"

echo "${BOLD}${GREEN}Frontend redeploy dokoncen.${RESET}"
