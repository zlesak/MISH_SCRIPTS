#!/bin/bash
set -euo pipefail

source ./common.sh

echo "${BOLD}${BLUE}Zastavuji aplikaci...${RESET}"

#
#BACKEND - pokud existuje
#
if docker ps -a --format '{{.Names}}' | grep -qx "$BACKEND_CONTAINER"; then
  if docker ps --format '{{.Names}}' | grep -qx "$BACKEND_CONTAINER"; then
    echo "${BLUE}Zastavuji backend...${RESET}"
    docker stop "$BACKEND_CONTAINER" >/dev/null || handle_error
  else
    echo "${BLUE}Backend již neběží (kontejner existuje).${RESET}"
  fi
fi

#
#FRONTEND - pokud existuje
#
if docker ps -a --format '{{.Names}}' | grep -qx "$FRONTEND_CONTAINER"; then
  if docker ps --format '{{.Names}}' | grep -qx "$FRONTEND_CONTAINER"; then
    echo "${BLUE}Zastavuji frontend...${RESET}"
    docker stop "$FRONTEND_CONTAINER" >/dev/null || handle_error
  else
    echo "${BLUE}Frontend již neběží (kontejner existuje).${RESET}"
  fi
fi

#
#MONGO - pokud existuje
#
if docker ps -a --format '{{.Names}}' | grep -qx "$MONGO_CONTAINER"; then
  echo "${BLUE}Zastavuji MongoDB (docker compose stop)...${RESET}"
  if [ -d "$SCRIPT_DIR/../backend/mongo" ]; then
    pushd "$SCRIPT_DIR/../backend/mongo" >/dev/null || handle_error
    if docker compose version >/dev/null 2>&1; then
      docker compose stop >/dev/null || handle_error
    else
      docker-compose stop >/dev/null || handle_error
    fi
    popd >/dev/null || true
  else
    echo "${RED}Adresář backend/mongo nebyl nalezen.${RESET}"
  fi
fi

#
#FINAL
#
echo "${BOLD}${GREEN}UKONČENÍ DOKONČENO${RESET}"
echo ""