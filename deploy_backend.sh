#!/bin/bash
set -euo pipefail

source ./lib.sh

MODE="prod"
BACKEND_BRANCH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --dev)
      MODE="dev"
      shift
      ;;
    --branch-backend=*)
      BACKEND_BRANCH="${1#*=}"
      shift
      ;;
    *)
      echo "Neznámý argument: $1"
      echo "Použití: $0 [--dev] [--branch-backend=NAZEV]"
      exit 1
      ;;
  esac
done

load_env "$MODE"
ensure_network
ensure_repo "$SCRIPT_DIR/backend/repo" "$BACKEND_GIT_URL" "$BACKEND_BRANCH"
fix_sh_perms "$SCRIPT_DIR/backend/repo"

echo "${BOLD}${GREEN}OPERACE PRO BACKEND${RESET}"

if [[ ! -f "$SCRIPT_DIR/backend/repo/mongo/certs-main/ca.pem" ]]; then
  echo "${BOLD}${RED}Chybí CA cert pro Mongo: $SCRIPT_DIR/backend/repo/mongo/certs-main/ca.pem${RESET}"
  echo "${BLUE}Nejdřív spusť: bash ./deploy_mongo.sh${RESET}"
  exit 2
fi

echo "${BOLD}${BLUE}Zastavuji starý backend kontejner (pokud existuje)...${RESET}"
docker rm -f "$BACKEND_CONTAINER" 2>/dev/null || true

echo "${BOLD}${BLUE}KOPÍRUJI ca.pem CERTIFIKÁT${RESET}"
rm -f "$SCRIPT_DIR/backend/ca.pem"
cp "$SCRIPT_DIR/backend/repo/mongo/certs-main/ca.pem" "$SCRIPT_DIR/backend"

HASH_FILE="$SCRIPT_DIR/backend/.last_build_hash"
SRC_HASH="$(get_src_hash "$SCRIPT_DIR/backend/repo")"
ENV_HASH="$(grep -v '^#' "$ENV_FILE" 2>/dev/null | hash_stdin_md5)"
CA_HASH="$(cat "$SCRIPT_DIR/backend/repo/mongo/certs-main/ca.pem" | hash_stdin_md5)"
CURRENT_HASH="src:${SRC_HASH}|env:${ENV_HASH}|ca:${CA_HASH}"
LAST_HASH=""
[[ -f "$HASH_FILE" ]] && LAST_HASH="$(cat "$HASH_FILE")"

if [[ "$CURRENT_HASH" != "$LAST_HASH" ]] || ! docker image inspect "$BACKEND_CONTAINER" >/dev/null 2>&1; then
  echo "${BOLD}${BLUE}Buildím Docker image pro backend (build probíhá uvnitř Dockerfile)...${RESET}"
  pushd "$SCRIPT_DIR/backend" >/dev/null || handle_error
  if IMAGE_FINGERPRINT="$CURRENT_HASH" bash ./build_backend.sh "${MONGO_PASSWORD:-adminpassword}"; then
    echo "$CURRENT_HASH" > "$HASH_FILE"
  else
    handle_error
  fi
  popd >/dev/null || true
else
  echo "${BOLD}${BLUE}Backend source nezměněn, přeskakuji build...${RESET}"
fi

echo "${BOLD}${BLUE}Odstraňuji tmp ca.pem...${RESET}"
rm -f "$SCRIPT_DIR/backend/ca.pem"

echo "${BOLD}${BLUE}Spouštím backend kontejner...${RESET}"
docker run -d \
  --env-file "$ENV_FILE" \
  --name "$BACKEND_CONTAINER" \
  --restart unless-stopped \
  --network "$NETWORK_NAME" \
  -p 8050:8050 \
  "$BACKEND_CONTAINER" || handle_error

echo "${BOLD}${GREEN}Backend deploy dokončen.${RESET}"
