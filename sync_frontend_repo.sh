#!/bin/bash
set -euo pipefail

source ./lib.sh

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

load_env "$MODE"
ensure_repo "$SCRIPT_DIR/frontend/repo" "$FRONTEND_GIT_URL" "$FRONTEND_BRANCH"
fix_sh_perms "$SCRIPT_DIR/frontend/repo"

echo "${BOLD}${GREEN}Frontend repo připraven.${RESET}"

