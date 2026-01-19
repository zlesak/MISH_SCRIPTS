#!/bin/bash
set -euo pipefail

source ./common.sh

DO_DOWN=false
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--down" || "$1" == "-d" ]]; then
    DO_DOWN=true
  fi
fi

echo "${BOLD}${BLUE}Zastavuji aplikaci...${RESET}"

#
# GATEWAY
#
if docker ps -a --format '{{.Names}}' | grep -qx "$GATEWAY_CONTAINER"; then
  if $DO_DOWN; then
    echo "${BLUE}Mažu gateway kontejner...${RESET}"
    docker rm -f "$GATEWAY_CONTAINER" >/dev/null || true
  else
    if docker ps --format '{{.Names}}' | grep -qx "$GATEWAY_CONTAINER"; then
      echo "${BLUE}Zastavuji gateway...${RESET}"
      docker stop "$GATEWAY_CONTAINER" >/dev/null || handle_error
    else
      echo "${BLUE}Gateway již neběží (kontejner existuje).${RESET}"
    fi
  fi
fi

#
# BACKEND
#
if docker ps -a --format '{{.Names}}' | grep -qx "$BACKEND_CONTAINER"; then
  if $DO_DOWN; then
    echo "${BLUE}Mažu backend kontejner...${RESET}"
    docker rm -f "$BACKEND_CONTAINER" >/dev/null || true
  else
    if docker ps --format '{{.Names}}' | grep -qx "$BACKEND_CONTAINER"; then
      echo "${BLUE}Zastavuji backend...${RESET}"
      docker stop "$BACKEND_CONTAINER" >/dev/null || handle_error
    else
      echo "${BLUE}Backend již neběží (kontejner existuje).${RESET}"
    fi
  fi
fi

#
# FRONTEND
#
if docker ps -a --format '{{.Names}}' | grep -qx "$FRONTEND_CONTAINER"; then
  if $DO_DOWN; then
    echo "${BLUE}Mažu frontend kontejner...${RESET}"
    docker rm -f "$FRONTEND_CONTAINER" >/dev/null || true
  else
    if docker ps --format '{{.Names}}' | grep -qx "$FRONTEND_CONTAINER"; then
      echo "${BLUE}Zastavuji frontend...${RESET}"
      docker stop "$FRONTEND_CONTAINER" >/dev/null || handle_error
    else
      echo "${BLUE}Frontend již neběží (kontejner existuje).${RESET}"
    fi
  fi
fi

#
# MONGO
#
if docker ps -a --format '{{.Names}}' | grep -qx "$MONGO_CONTAINER"; then
  if [ -d "$SCRIPT_DIR/backend/repo/mongo" ]; then
    pushd "$SCRIPT_DIR/backend/repo/mongo" >/dev/null || handle_error
    if $DO_DOWN; then
      echo "${BLUE}Zastavuji a mažu MongoDB (docker compose down -v)...${RESET}"
      if docker compose version >/dev/null 2>&1; then
        docker compose down -v >/dev/null || true
      else
        docker-compose down -v >/dev/null || true
      fi
    else
      echo "${BLUE}Zastavuji MongoDB (docker compose stop)...${RESET}"
      if docker compose version >/dev/null 2>&1; then
        docker compose stop >/dev/null || handle_error
      else
        docker-compose stop >/dev/null || handle_error
      fi
    fi
    popd >/dev/null || true
  else
    echo "${RED}Adresář backend/mongo nebyl nalezen.${RESET}"
  fi
fi

#
# SECURITY
#
if docker ps -a --format '{{.Names}}' | grep -qx "$SECURITY_CONTAINER"; then
  if [ -d "$SCRIPT_DIR/backend/repo/mocked-auth-providers" ]; then
    pushd "$SCRIPT_DIR/backend/repo/mocked-auth-providers" >/dev/null || handle_error
    if $DO_DOWN; then
      echo "${BLUE}Zastavuji a mažu Security (docker compose down -v)...${RESET}"
      if docker compose version >/dev/null 2>&1; then
        docker compose down -v >/dev/null || true
      else
        docker-compose down -v >/dev/null || true
      fi
    else
      echo "${BLUE}Zastavuji Security (docker compose stop)...${RESET}"
      if docker compose version >/dev/null 2>&1; then
        docker compose stop >/dev/null || handle_error
      else
        docker-compose stop >/dev/null || handle_error
      fi
    fi
    popd >/dev/null || true
  else
    echo "${RED}Adresář backend/mocked-auth-providers nebyl nalezen.${RESET}"
  fi
fi

#
# FINAL
#
echo "${BOLD}${GREEN}UKONČENÍ DOKONČENO${RESET}"
echo ""