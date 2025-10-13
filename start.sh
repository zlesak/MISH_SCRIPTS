#!/bin/bash

source ./common.sh

echo "${BOLD}${GREEN}PODPŮRNÉ OPERACE${RESET}"

echo "${BOLD}${BLUE}Čistím staré kontejnery...${RESET}"
docker rm -f "$BACKEND_CONTAINER" "$FRONTEND_CONTAINER" "$MONGO_CONTAINER" 2>/dev/null || true

echo "${BOLD}${GREEN}PODPŮRNÉ OPERACE DOKONČENY${RESET}"
echo ""
#
#NETWORK
#
echo "${BOLD}${GREEN}PODPŮRNÉ OPERACE PRO SÍŤ${RESET}"
ensure_network

echo "${BOLD}${GREEN}OPERACE PRO SÍŤ DOKONČENY${RESET}"
echo ""

#
#MONGO
#
echo "${BOLD}${GREEN}OPERACE PRO MONGO${RESET}"
echo "${BOLD}${BLUE}Spouštím MongoDB z docker-compose...${RESET}"
pushd "$SCRIPT_DIR/../backend/mongo" >/dev/null || handle_error
if ! compose up -d; then
  handle_error
fi
popd >/dev/null || true
echo "${BOLD}${GREEN}MongoDB spuštěno.${RESET}"
echo "${BOLD}${GREEN}OPERACE PRO MONGO DOKONČENY${RESET}"
echo ""

#
#BACKEND
#
echo "${BOLD}${GREEN}OPERACE PRO BACKEND${RESET}"
echo "${BOLD}${BLUE}Buildím backend pomocí Gradle...${RESET}"
pushd "$SCRIPT_DIR/../backend" >/dev/null || handle_error
if ! ./gradlew bootJar -x test; then
  handle_error
fi
echo "${BOLD}${GREEN}Backend úspěšně zbuildován.${RESET}"

echo "${BOLD}${BLUE}Kopíruju backend .jar do build složky pro Docker...${RESET}"
BACKEND_JAR=$(find "$SCRIPT_DIR/../backend/build/libs" -name "*.jar" | head -n 1)
cp "$BACKEND_JAR" "$SCRIPT_DIR/backend/app.jar" || handle_error
popd >/dev/null || true

echo "${BOLD}${BLUE}Buildím Docker image pro backend...${RESET}"
pushd "$SCRIPT_DIR/backend" >/dev/null || handle_error
bash ./build_backend.sh || handle_error
popd >/dev/null || true

echo "${BOLD}${BLUE}Spouštím backend kontejner...${RESET}"
docker run -d \
  --name "$BACKEND_CONTAINER" \
  --network "$NETWORK_NAME" \
  -e SPRING_DATA_MONGODB_URI="mongodb://root:example@mongodb:27017/mish-db?authSource=admin" \
  -p 8080:8080 \
  "$BACKEND_CONTAINER" || handle_error
echo "${BOLD}${GREEN}OPERACE PRO BACKEND DOKONČENY ${RESET}"
echo ""

#
#FRONTEND
#
echo "${BOLD}${GREEN}OPERACE PRO FRONTEND${RESET}"
if [ -d "$SCRIPT_DIR/../frontend" ]; then
  pushd "$SCRIPT_DIR/../frontend" >/dev/null || handle_error
  echo "${BOLD}${BLUE}Buildím frontend...${RESET}"
  bash ./mvnw clean package -DskipTests -Pproduction || handle_error

  echo "${BOLD}${BLUE}Kopíruju frontend .jar do build složky pro Docker...${RESET}"
  FRONTEND_JAR=$(find "$SCRIPT_DIR/../frontend/target" -name "*.jar" | head -n 1)
  cp "$FRONTEND_JAR" "$SCRIPT_DIR/frontend/app.jar" || handle_error
  popd >/dev/null || true

  echo "${BOLD}${BLUE}Buildím Docker image pro frontend...${RESET}"
  pushd "$SCRIPT_DIR/frontend" >/dev/null || handle_error
  bash ./build_frontend.sh || handle_error
  popd >/dev/null || true

  echo "${BOLD}${BLUE}Spouštím frontend kontejner...${RESET}"
  docker run -d \
    --name "$FRONTEND_CONTAINER" \
    --network "$NETWORK_NAME" \
    -e BACKEND_URL="http://kotlin-backend:8080" \
    -p 8081:8081 \
    "$FRONTEND_CONTAINER" || handle_error

  echo "${BOLD}${BLUE}Kopíruju soubory do kontejneru...${RESET}"
  docker cp "$SCRIPT_DIR/../frontend/src/main/webapp" "$FRONTEND_CONTAINER:/app/webapp" || handle_error
  echo "${BOLD}${GREEN}Soubory zkopírovány do kontejneru${RESET}"
  echo "${BOLD}${GREEN}OPERACE PRO FRONTEND DOKONČENY${RESET}"
else
  echo "${RED}Frontend adresář nebyl nalezen – přeskočeno.${RESET}"
fi
echo ""

#
#FINAL
#
echo "${BOLD}${GREEN}SPUŠTĚNÍ DOKONČENO${RESET}"
echo "${BOLD}${BLUE}Backend:${RESET}  http://localhost:8080"
echo "${BOLD}${BLUE}Frontend:${RESET} http://localhost:8081"
echo ""