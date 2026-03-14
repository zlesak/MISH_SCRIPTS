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
ensure_repo "$SCRIPT_DIR/backend/repo" "$BACKEND_GIT_URL" "$BACKEND_BRANCH"
fix_sh_perms "$SCRIPT_DIR/backend/repo"

echo "${BOLD}${GREEN}Backend repo připraven.${RESET}"

