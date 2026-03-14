#!/bin/bash
set -euo pipefail

source ./lib.sh

MODE="prod"
RUN_FRONTEND=true
BACKEND_BRANCH=""
FRONTEND_BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev)
      MODE="dev"
      shift
      ;;
    --no-frontend)
      RUN_FRONTEND=false
      shift
      ;;
    --branch-backend=*)
      BACKEND_BRANCH="${1#*=}"
      shift
      ;;
    --branch-frontend=*)
      FRONTEND_BRANCH="${1#*=}"
      shift
      ;;
    *)
      echo "Neznámý argument: $1"
      echo "Použití: $0 [--dev] [--no-frontend] [--branch-backend=NAZEV] [--branch-frontend=NAZEV]"
      exit 1
      ;;
  esac
done

load_env "$MODE"

MODE_ARGS=()
[[ "$MODE" == "dev" ]] && MODE_ARGS+=("--dev")

BACKEND_ARGS=("${MODE_ARGS[@]}")
[[ -n "$BACKEND_BRANCH" ]] && BACKEND_ARGS+=("--branch-backend=$BACKEND_BRANCH")

FRONTEND_ARGS=("${MODE_ARGS[@]}")
[[ -n "$FRONTEND_BRANCH" ]] && FRONTEND_ARGS+=("--branch-frontend=$FRONTEND_BRANCH")

GATEWAY_ARGS=("${MODE_ARGS[@]}")

run_step() {
  local title="$1"
  shift
  echo "${BOLD}${GREEN}${title}${RESET}"
  "$@"
  echo ""
}

run_step "MONGO DEPLOY" bash "$SCRIPT_DIR/deploy_mongo.sh" "${BACKEND_ARGS[@]}"
run_step "REDIS DEPLOY" bash "$SCRIPT_DIR/deploy_redis.sh" "${BACKEND_ARGS[@]}"
run_step "SECURITY DEPLOY" bash "$SCRIPT_DIR/deploy_security.sh" "${BACKEND_ARGS[@]}"
run_step "BACKEND DEPLOY" bash "$SCRIPT_DIR/deploy_backend.sh" "${BACKEND_ARGS[@]}"

if $RUN_FRONTEND; then
  run_step "FRONTEND DEPLOY" bash "$SCRIPT_DIR/deploy_frontend.sh" "${FRONTEND_ARGS[@]}"
else
  echo "${BOLD}${BLUE}Frontend nebude spuštěn (--no-frontend).${RESET}"
  echo ""
fi

run_step "GATEWAY DEPLOY" bash "$SCRIPT_DIR/deploy_gateway.sh" "${GATEWAY_ARGS[@]}"

echo "${BOLD}${GREEN}SPUŠTĚNÍ DOKONČENO${RESET}"
echo "${BOLD}${BLUE}Aplikace:${RESET}   ${FE_URL:-http://localhost:80}"
if ! $RUN_FRONTEND; then
  echo "${BOLD}${BLUE}Frontend:${RESET} SPUSTIT RUČNĚ NA PORTU 8081! Nelze využívat nginx gateway."
fi
