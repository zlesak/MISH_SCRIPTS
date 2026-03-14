#!/bin/bash
set -euo pipefail

source ./common.sh

MODE="prod"
FRONTEND_BRANCH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --dev)
      MODE="dev"
      shift
      ;;
    --branch-frontend=*)
      FRONTEND_BRANCH="${1#*=}"
      shift
      ;;
    *)
      echo "Neznámý argument: $1"
      echo "Použití: $0 [--dev] [--branch-frontend=NAZEV]"
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
  echo "Chybí env soubor: $ENV_FILE"
  exit 1
fi

export $(grep -v '^#' "$ENV_FILE" | xargs)

KEYCLOAK_EFFECTIVE_URL="${KEYCLOAK_URL:-}"
if [[ -n "${KEYCLOAK_EXTERNAL_URL:-}" ]]; then
  KEYCLOAK_EFFECTIVE_URL="${KEYCLOAK_EXTERNAL_URL}"
fi

mkdir -p "$SCRIPT_DIR/frontend/repo"

FRONTEND_GIT_OK=false
if [ -d "$SCRIPT_DIR/frontend/repo/.git" ]; then
  FRONTEND_REMOTE=$(git -C "$SCRIPT_DIR/frontend/repo" remote get-url origin 2>/dev/null || echo "")
  if [ -n "$FRONTEND_REMOTE" ] && [ "$FRONTEND_REMOTE" = "$FRONTEND_GIT_URL" ]; then
    FRONTEND_GIT_OK=true
  fi
fi

if ! $FRONTEND_GIT_OK; then
  echo "${BOLD}${BLUE}Klonuji frontend z $FRONTEND_GIT_URL ...${RESET}"
  rm -rf "$SCRIPT_DIR/frontend/repo"/* "$SCRIPT_DIR/frontend/repo"/.??* 2>/dev/null || true
  if [ -n "$FRONTEND_BRANCH" ]; then
    git clone -b "$FRONTEND_BRANCH" "$FRONTEND_GIT_URL" "$SCRIPT_DIR/frontend/repo" || { echo "${RED}Klonování frontendu selhalo!${RESET}"; exit 2; }
  else
    git clone "$FRONTEND_GIT_URL" "$SCRIPT_DIR/frontend/repo" || { echo "${RED}Klonování frontendu selhalo!${RESET}"; exit 2; }
  fi
fi

if [[ -d "$SCRIPT_DIR/frontend/repo/.git" && -n "$FRONTEND_BRANCH" ]]; then
  CURRENT_FRONTEND_BRANCH=$(git -C "$SCRIPT_DIR/frontend/repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ "$CURRENT_FRONTEND_BRANCH" != "$FRONTEND_BRANCH" ]]; then
    echo "${BOLD}${BLUE}Přepínám frontend na větev $FRONTEND_BRANCH...${RESET}"
    git -C "$SCRIPT_DIR/frontend/repo" fetch origin || { echo "${RED}Chyba při fetch frontend větve!${RESET}"; exit 2; }
    git -C "$SCRIPT_DIR/frontend/repo" checkout "$FRONTEND_BRANCH" || { echo "${RED}Chyba při checkout frontend větve!${RESET}"; exit 2; }
    git -C "$SCRIPT_DIR/frontend/repo" pull origin "$FRONTEND_BRANCH" || { echo "${RED}Chyba při pull frontend větve!${RESET}"; exit 2; }
  fi
fi

find "$SCRIPT_DIR/frontend/repo" \
  -path "$SCRIPT_DIR/frontend/repo/.git" -prune -o \
  -path "*/target/*" -prune -o \
  -path "*/node_modules/*" -prune -o \
  -type f -name "*.sh" -exec chmod 755 {} + 2>/dev/null || true

if ! docker network ls --format '{{.Name}}' | grep -qx "$NETWORK_NAME"; then
  echo "${BOLD}${BLUE}Vytvářím síť $NETWORK_NAME...${RESET}"
  docker network create "$NETWORK_NAME" >/dev/null
fi

echo "${BOLD}${BLUE}Zastavuji starý frontend kontejner (pokud existuje)...${RESET}"
docker rm -f "$FRONTEND_CONTAINER" 2>/dev/null || true

HASH_FILE="$SCRIPT_DIR/frontend/.last_build_hash"
SRC_HASH="$(get_src_hash "$SCRIPT_DIR/frontend/repo")"
ENV_HASH="$(grep -v '^#' "$ENV_FILE" 2>/dev/null | hash_stdin_md5)"
CURRENT_HASH="src:${SRC_HASH}|env:${ENV_HASH}"
LAST_HASH=""
[[ -f "$HASH_FILE" ]] && LAST_HASH="$(cat "$HASH_FILE")"

if [[ "$CURRENT_HASH" != "$LAST_HASH" ]] || ! docker image inspect "$FRONTEND_CONTAINER" >/dev/null 2>&1; then
  echo "${BOLD}${BLUE}Buildím Docker image pro frontend (build probíhá uvnitř Dockerfile)...${RESET}"
  pushd "$SCRIPT_DIR/frontend" >/dev/null || handle_error
  if IMAGE_FINGERPRINT="$CURRENT_HASH" bash ./build_frontend.sh; then
    echo "$CURRENT_HASH" > "$HASH_FILE"
  else
    handle_error
  fi
  popd >/dev/null || true
else
  echo "${BOLD}${BLUE}Frontend source nezměněn, přeskakuji build...${RESET}"
fi

echo "${BOLD}${BLUE}Spouštím frontend kontejner...${RESET}"
docker run -d \
  --env-file "$ENV_FILE" \
  -e KEYCLOAK_URL="${KEYCLOAK_EFFECTIVE_URL}" \
  --name "$FRONTEND_CONTAINER" \
  --restart unless-stopped \
  --network "$NETWORK_NAME" \
  -p 8081:8081 \
  "$FRONTEND_CONTAINER" || handle_error

echo "${BOLD}${BLUE}Kopíruju soubory do kontejneru...${RESET}"
docker cp "$SCRIPT_DIR/frontend/repo/src/main/webapp" "$FRONTEND_CONTAINER:/app/webapp" || handle_error
echo "${BOLD}${GREEN}Soubory zkopírovány do kontejneru${RESET}"
echo "${BOLD}${GREEN}OPERACE PRO FRONTEND DOKONČENY${RESET}"

echo "${BOLD}${GREEN}Deploy frontendu dokončen.${RESET}"
echo "${BOLD}${BLUE}FE:${RESET} ${FE_URL:-"http://localhost:8081"}"

