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

echo "${BOLD}${GREEN}OPERACE PRO REDIS${RESET}"
echo "${BOLD}${BLUE}Generuji certifikáty pro Redis...${RESET}"
pushd "$SCRIPT_DIR/backend/repo/script-utils" >/dev/null || handle_error
bash "./generate-all-redis-certs.sh"
popd >/dev/null || true

echo "${BOLD}${BLUE}Spouštím Redis...${RESET}"
pushd "$SCRIPT_DIR/backend/repo/redis" >/dev/null || handle_error
bash "./scripts/startup.sh"
popd >/dev/null || true

echo "${BOLD}${GREEN}Redis deploy dokončen.${RESET}"

