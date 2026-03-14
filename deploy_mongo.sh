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

echo "${BOLD}${GREEN}OPERACE PRO CERTIFIKÁTY${RESET}"
echo "${BOLD}${BLUE}Generuji CA certifikát...${RESET}"
pushd "$SCRIPT_DIR/backend/repo/script-utils" >/dev/null || handle_error
bash "./generate-ca.sh" "$MONGO_PASSWORD"
popd >/dev/null || true

echo "${BOLD}${BLUE}Odstraňuji staré certs-main a keyfile před startem Mongo...${RESET}"
rm -rf "$SCRIPT_DIR/backend/repo/mongo/certs-main" "$SCRIPT_DIR/backend/repo/mongo/keyfile" || true

echo "${BOLD}${GREEN}OPERACE PRO MONGO${RESET}"
echo "${BOLD}${BLUE}Generuji certifikáty pro MongoDB...${RESET}"
pushd "$SCRIPT_DIR/backend/repo/script-utils" >/dev/null || handle_error
bash "./generate-all-mongo-certs.sh"
popd >/dev/null || true

echo "${BOLD}${BLUE}Spouštím MongoDB...${RESET}"
pushd "$SCRIPT_DIR/backend/repo/mongo" >/dev/null || handle_error
bash "./scripts/start-mongo.sh" "$MONGO_PASSWORD"
popd >/dev/null || true

if [[ -f "$SCRIPT_DIR/backend/repo/mongo/keyfile/keyfile" ]]; then
  echo "${BLUE}Keyfile perms:${RESET} $(ls -l "$SCRIPT_DIR/backend/repo/mongo/keyfile/keyfile" 2>/dev/null || true)"
fi

echo "${BOLD}${GREEN}Mongo deploy dokončen.${RESET}"

