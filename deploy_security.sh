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

echo "${BOLD}${GREEN}OPERACE PRO SECURITY${RESET}"
echo "${BOLD}${BLUE}Spouštím Security (mock-oidc)...${RESET}"
pushd "$SCRIPT_DIR/backend/repo/mocked-auth-providers" >/dev/null || handle_error

export KEYCLOAK_PUBLIC_URL="${KEYCLOAK_PUBLIC_URL:?KEYCLOAK_PUBLIC_URL not set}"
export KEYCLOAK_ADMIN_URL="${KEYCLOAK_ADMIN_URL:?KEYCLOAK_ADMIN_URL not set}"

compose up -d
popd >/dev/null || true

echo "${BOLD}${GREEN}Security deploy dokončen.${RESET}"

