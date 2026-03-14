#!/bin/bash
set -euo pipefail

source ./common.sh

DO_DOWN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --down|-d)
      DO_DOWN=true
      shift
      ;;
    *)
      echo "Neznámý argument: $1"
      echo "Použití: $0 [--down|-d]"
      exit 1
      ;;
  esac
done

container_exists() {
  local name="$1"
  docker ps -a --format '{{.Names}}' | grep -qx "$name"
}

container_running() {
  local name="$1"
  docker ps --format '{{.Names}}' | grep -qx "$name"
}

stop_or_remove_container() {
  local name="$1"
  local label="$2"

  if ! container_exists "$name"; then
    echo "${BLUE}${label} kontejner neexistuje.${RESET}"
    return 0
  fi

  if $DO_DOWN; then
    echo "${BLUE}Mažu ${label} kontejner...${RESET}"
    docker rm -f "$name" >/dev/null || true
    return 0
  fi

  if container_running "$name"; then
    echo "${BLUE}Zastavuji ${label}...${RESET}"
    docker stop "$name" >/dev/null || true
  else
    echo "${BLUE}${label} již neběží (kontejner existuje).${RESET}"
  fi
}

stop_or_down_compose_stack() {
  local dir="$1"
  local label="$2"

  if [[ ! -d "$dir" ]]; then
    echo "${RED}Adresář ${dir} nebyl nalezen.${RESET}"
    return 0
  fi

  pushd "$dir" >/dev/null || handle_error
  if $DO_DOWN; then
    echo "${BLUE}Zastavuji a mažu ${label} (docker compose down -v)...${RESET}"
    compose down -v >/dev/null || true
  else
    echo "${BLUE}Zastavuji ${label} (docker compose stop)...${RESET}"
    compose stop >/dev/null || true
  fi
  popd >/dev/null || true
}

echo "${BOLD}${BLUE}Zastavuji aplikaci...${RESET}"

#
# GATEWAY
#
stop_or_remove_container "$GATEWAY_CONTAINER" "gateway"

#
# BACKEND
#
stop_or_remove_container "$BACKEND_CONTAINER" "backend"

#
# FRONTEND
#
stop_or_remove_container "$FRONTEND_CONTAINER" "frontend"

#
# REDIS
#
stop_or_down_compose_stack "$SCRIPT_DIR/backend/repo/redis" "Redis"

#
# MONGO
#
stop_or_down_compose_stack "$SCRIPT_DIR/backend/repo/mongo" "MongoDB"

#
# SECURITY
#
stop_or_down_compose_stack "$SCRIPT_DIR/backend/repo/mocked-auth-providers" "Security"

#
# FINAL
#
echo "${BOLD}${GREEN}UKONČENÍ DOKONČENO${RESET}"
echo ""
