#!/bin/bash

# Define colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)
BOLD=$(tput bold)
RESET=$(tput sgr0)

handle_error() {
    echo "${BOLD}${RED}Došlo k chybě! Stiskni Enter pro ukončení skriptu...${RESET}$"
    read -r
    exit 1
}

trap handle_error ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Názvy
NETWORK_NAME="mish_net"
MONGO_CONTAINER="mongodb"
BACKEND_CONTAINER="kotlin-backend"
FRONTEND_CONTAINER="vaadin-frontend"
echo "${BOLD}${GREEN}PODPŮRNÉ OPERACE${RESET}"

echo "${BOLD}${BLUE}Čistím staré kontejnery...${RESET}"
docker rm -f "$BACKEND_CONTAINER" "$FRONTEND_CONTAINER" "$MONGO_CONTAINER" 2>/dev/null || true

#
#NETWORK
#
if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "${BOLD}${BLUE}Vytvářím síť $NETWORK_NAME...${RESET}"
  docker network create "$NETWORK_NAME" || handle_error
fi

echo "${BOLD}${GREEN}PODPŮRNÉ OPERACE DOKONČENY${RESET}"
echo ""
#
#MONGO
#
echo "${BOLD}${GREEN}OPERACE PRO MONGO${RESET}"
echo "${BOLD}${BLUE}Spouštím MongoDB z docker-compose...${RESET}"
cd "$SCRIPT_DIR/../backend/mongo" || handle_error

if ! docker-compose up -d; then
  handle_error
fi
echo "${BOLD}${GREEN}MongoDB spuštěno.${RESET}"
echo "${BOLD}${GREEN}OPERACE PRO MONGO DOKONČENY${RESET}"
echo ""

#
#BACKEND
#
echo "${BOLD}${GREEN}OPERACE PRO BACKEND${RESET}"
echo "${BOLD}${BLUE}Buildím backend pomocí Gradle...${RESET}"
cd "$SCRIPT_DIR/../backend" || handle_error

if ! ./gradlew bootJar -x test; then
  handle_error
fi
echo "${BOLD}${GREEN}Backend úspěšně zbuildován.${RESET}"

echo "${BOLD}${BLUE}Kopíruju frontend .jar do build složky pro Docker...${RESET}"
BACKEND_JAR=$(find "$SCRIPT_DIR/../backend/build/libs" -name "*.jar" | head -n 1)
cp "$BACKEND_JAR" "$SCRIPT_DIR/backend/app.jar" || handle_error

echo "${BOLD}${BLUE}Buildím Docker image pro backend...${RESET}"
cd "$SCRIPT_DIR/backend" || handle_error
./build_backend.sh || handle_error

echo "${BOLD}${BLUE}Spouštím backend kontejner...${RESET}"
docker run -d \
  --name "$BACKEND_CONTAINER" \
  --network "$NETWORK_NAME" \
  -e SPRING_DATA_MONGODB_URI=mongodb://root:example@mongodb:27017/mish-db?authSource=admin \
  -p 8080:8080 \
  "$BACKEND_CONTAINER" || handle_error
echo "${BOLD}${GREEN}OPERACE PRO BACKEND DOKONČENY ${RESET}"
echo ""

#
#FINAL
#
echo "${BOLD}${GREEN}SPUŠTĚNÍ DOKONČENO${RESET}"
echo "${BOLD}${BLUE}Backend:${RESET}  http://localhost:8080"
echo "${BOLD}${BLUE}Frontend:${RESET} SPUSTIT RUČNĚ NA PORTU 8081!"
echo ""
read -p "Stiskni Enter pro ukončení skriptu..." -r