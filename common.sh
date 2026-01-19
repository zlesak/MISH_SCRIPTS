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

# Error handling funkce
handle_error() {
    echo "${BOLD}${RED}Došlo k chybě! Stiskni Enter pro ukončení skriptu...${RESET}$"
    exit -1
}
trap handle_error ERR

# Názvy kontejnerů
SECURITY_CONTAINER=mock-oidc
BACKEND_CONTAINER=kotlin-backend
MONGO_CONTAINER=mongo-tls
FRONTEND_CONTAINER=vaadin-frontend

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}