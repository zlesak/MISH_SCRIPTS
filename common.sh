#!/bin/bash
set -euo pipefail

# Define colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)
BOLD=$(tput bold)
RESET=$(tput sgr0)

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Sdílené názvy napoříč skripty
NETWORK_NAME="mish_net"
MONGO_CONTAINER="mongodb"
SECURITY_CONTAINER="mock-oidc"
BACKEND_CONTAINER="kotlin-backend"
FRONTEND_CONTAINER="vaadin-frontend"

# Error handling funkce
handle_error() {
    echo "${BOLD}${RED}Došlo k chybě! Stiskni Enter pro ukončení skriptu...${RESET}$"
    exit -1
}
trap handle_error ERR

ensure_network() {
  if ! docker network ls --format '{{.Name}}' | grep -qx "$NETWORK_NAME"; then
    echo "${BOLD}${BLUE}Vytvářím síť $NETWORK_NAME...${RESET}"
    docker network create "$NETWORK_NAME" >/dev/null
  else
    echo "${BLUE}Síť $NETWORK_NAME již existuje.${RESET}"
  fi
}

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}
