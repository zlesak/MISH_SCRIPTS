#!/bin/bash

set -euo pipefail

source ./common.sh

#
#INITIAL OPERATIONS
#

# Výchozí hodnoty
MODE="prod"
RUN_FRONTEND=true
BACKEND_BRANCH=""
FRONTEND_BRANCH=""

# Zpracování argumentů
while [[ $# -gt 0 ]]; do
  case $1 in
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

# Výběr správného env souboru - nutno dodat produkční, není součástí repozitáře!
if [[ "$MODE" == "dev" ]]; then
  ENV_FILE="$SCRIPT_DIR/.dev.env"
else
  ENV_FILE="$SCRIPT_DIR/.env"
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Chybí env soubor: $ENV_FILE"
  exit 1
fi

# Načtení proměnných z env souboru
export $(grep -v '^#' "$ENV_FILE" | xargs)

# Příprava složek pro repozitáře
mkdir -p "$SCRIPT_DIR/backend/repo"
mkdir -p "$SCRIPT_DIR/frontend/repo"

# Kontrola a případné klonování backendu
BACKEND_GIT_OK=false
if [ -d "$SCRIPT_DIR/backend/repo/.git" ]; then
  BACKEND_REMOTE=$(git -C "$SCRIPT_DIR/backend/repo" remote get-url origin 2>/dev/null || echo "")
  if [ -n "$BACKEND_REMOTE" ] && [ "$BACKEND_REMOTE" = "$BACKEND_GIT_URL" ]; then
    BACKEND_GIT_OK=true
  fi
fi
if ! $BACKEND_GIT_OK; then
  echo "${BOLD}${BLUE}Klonuji backend z $BACKEND_GIT_URL ...${RESET}"
  rm -rf "$SCRIPT_DIR/backend/repo"/* "$SCRIPT_DIR/backend/repo"/.??* 2>/dev/null || true
  if [ -n "$BACKEND_BRANCH" ]; then
    git clone -b "$BACKEND_BRANCH" "$BACKEND_GIT_URL" "$SCRIPT_DIR/backend/repo" || { echo "${RED}Klonování backendu selhalo!${RESET}"; exit 2; }
  else
    git clone "$BACKEND_GIT_URL" "$SCRIPT_DIR/backend/repo" || { echo "${RED}Klonování backendu selhalo!${RESET}"; exit 2; }
  fi
else
  echo "${BLUE}Backend již obsahuje správný repozitář ($BACKEND_GIT_URL).${RESET}"
fi

# Kontrola a případné klonování frontendu
FRONTEND_GIT_OK=false
if [ -d "$SCRIPT_DIR/frontend/repo/.git" ]; then
  FRONTEND_REMOTE=$(git -C "$SCRIPT_DIR/frontend/repo" remote get-url origin 2>/dev/null || echo "")
  if [ -n "$FRONTEND_REMOTE" ] && [ "$FRONTEND_REMOTE" = "$FRONTEND_GIT_URL" ]; then
    FRONTEND_GIT_OK=true
  fi
fi
if ! $FRONTEND_GIT_OK; then
  echo "${BOLD}${BLUE}Klonuji frontend z $FRONTEND_GIT_URL ...${RESET}"
  rm -rf "$SCRIPT_DIR/frontend/repo"/* "$SCRIPT_DIR/frontend/repo"/.??* 2>/dev/null || true
  if [ -n "$FRONTEND_BRANCH" ]; then
    git clone -b "$FRONTEND_BRANCH" "$FRONTEND_GIT_URL" "$SCRIPT_DIR/frontend/repo" || { echo "${RED}Klonování frontendu selhalo!${RESET}"; exit 2; }
  else
    git clone "$FRONTEND_GIT_URL" "$SCRIPT_DIR/frontend/repo" || { echo "${RED}Klonování frontendu selhalo!${RESET}"; exit 2; }
  fi
else
  echo "${BLUE}Frontend již obsahuje správný repozitář ($FRONTEND_GIT_URL).${RESET}"
fi

# Kontrola a případné přepnutí větve backendu
if [[ -d "$SCRIPT_DIR/backend/repo/.git" && -n "$BACKEND_BRANCH" ]]; then
  CURRENT_BACKEND_BRANCH=$(git -C "$SCRIPT_DIR/backend/repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ "$CURRENT_BACKEND_BRANCH" != "$BACKEND_BRANCH" ]]; then
    echo "${BOLD}${BLUE}Přepínám backend na větev $BACKEND_BRANCH...${RESET}"
    git -C "$SCRIPT_DIR/backend/repo" fetch origin || { echo "${RED}Chyba při fetch backend větve!${RESET}"; exit 2; }
    git -C "$SCRIPT_DIR/backend/repo" checkout "$BACKEND_BRANCH" || { echo "${RED}Chyba při checkout backend větve!${RESET}"; exit 2; }
    git -C "$SCRIPT_DIR/backend/repo" pull origin "$BACKEND_BRANCH" || { echo "${RED}Chyba při pull backend větve!${RESET}"; exit 2; }
  else
    echo "${BLUE}Backend je již na větvi $BACKEND_BRANCH.${RESET}"
  fi
fi

# Kontrola a případné přepnutí větve frontendu
if [[ -d "$SCRIPT_DIR/frontend/repo/.git" && -n "$FRONTEND_BRANCH" ]]; then
  CURRENT_FRONTEND_BRANCH=$(git -C "$SCRIPT_DIR/frontend/repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ "$CURRENT_FRONTEND_BRANCH" != "$FRONTEND_BRANCH" ]]; then
    echo "${BOLD}${BLUE}Přepínám frontend na větev $FRONTEND_BRANCH...${RESET}"
    git -C "$SCRIPT_DIR/frontend/repo" fetch origin || { echo "${RED}Chyba při fetch frontend větve!${RESET}"; exit 2; }
    git -C "$SCRIPT_DIR/frontend/repo" checkout "$FRONTEND_BRANCH" || { echo "${RED}Chyba při checkout frontend větve!${RESET}"; exit 2; }
    git -C "$SCRIPT_DIR/frontend/repo" pull origin "$FRONTEND_BRANCH" || { echo "${RED}Chyba při pull frontend větve!${RESET}"; exit 2; }
  else
    echo "${BLUE}Frontend je již na větvi $FRONTEND_BRANCH.${RESET}"
  fi
fi

echo "${BOLD}${GREEN}PODPŮRNÉ OPERACE${RESET}"
echo "${BOLD}${BLUE}Čistím staré kontejnery...${RESET}"
docker rm -f "$BACKEND_CONTAINER" "$FRONTEND_CONTAINER" "$MONGO_CONTAINER" "$GATEWAY_CONTAINER" 2>/dev/null || true
echo "${BOLD}${GREEN}PODPŮRNÉ OPERACE DOKONČENY${RESET}"
echo ""

#
#NETWORK
#
echo "${BOLD}${GREEN}PODPŮRNÉ OPERACE PRO SÍŤ${RESET}"
if ! docker network ls --format '{{.Name}}' | grep -qx "$NETWORK_NAME"; then
  echo "${BOLD}${BLUE}Vytvářím síť $NETWORK_NAME...${RESET}"
  docker network create "$NETWORK_NAME" >/dev/null
else
  echo "${BLUE}Síť $NETWORK_NAME již existuje.${RESET}"
fi
echo "${BOLD}${GREEN}OPERACE PRO SÍŤ DOKONČENY${RESET}"
echo ""

#
#MONGO
#
echo "${BOLD}${GREEN}OPERACE PRO MONGO${RESET}"
echo "${BOLD}${BLUE}Spouštím MongoDB...${RESET}"
pushd "$SCRIPT_DIR/backend/repo/mongo" >/dev/null || handle_error
if ! bash "./scripts/start-mongo.sh" "$MONGO_PASSWORD"; then
  handle_error
fi
popd >/dev/null || true
echo "${BOLD}${GREEN}MongoDB spuštěno.${RESET}"
echo "${BOLD}${GREEN}OPERACE PRO MONGO DOKONČENY${RESET}"
echo ""
#
#SECURITY
#
echo "${BOLD}${GREEN}OPERACE PRO SECURITY${RESET}"
echo "${BOLD}${BLUE}Spouštím Security...${RESET}"
pushd "$SCRIPT_DIR/backend/repo/mocked-auth-providers" >/dev/null || handle_error
if ! compose up -d; then
  handle_error
fi
popd >/dev/null || true
echo "${BOLD}${GREEN}Security spuštěno.${RESET}"
echo "${BOLD}${GREEN}OPERACE PRO SECURITY DOKONČENY${RESET}"
echo ""

#
#BACKEND
#
echo "${BOLD}${GREEN}OPERACE PRO BACKEND${RESET}"

echo "${BOLD}${BLUE}KOPÍRUJI ca.pem CERTIFIKÁT${RESET}"
rm -f "$SCRIPT_DIR/backend/ca.pem"
cp "$SCRIPT_DIR/backend/repo/mongo/certs/ca.pem" "$SCRIPT_DIR/backend"

echo "${BOLD}${BLUE}Buildím backend pomocí Gradle...${RESET}"
pushd "$SCRIPT_DIR/backend/repo" >/dev/null || handle_error
if ! ./gradlew bootJar -x test; then
  handle_error
fi
echo "${BOLD}${GREEN}Backend úspěšně sestaven.${RESET}"

echo "${BOLD}${BLUE}Kopíruju backend .jar do build složky pro Docker...${RESET}"
BACKEND_JAR=$(find "$SCRIPT_DIR/backend/repo/build/libs" -name "*.jar" | head -n 1)
cp "$BACKEND_JAR" "$SCRIPT_DIR/backend/app.jar" || handle_error
popd >/dev/null || true

echo "${BOLD}${BLUE}Buildím Docker image pro backend...${RESET}"
pushd "$SCRIPT_DIR/backend" >/dev/null || handle_error
bash ./build_backend.sh "${MONGO_PASSWORD:-adminpassword}" || handle_error
popd >/dev/null || true

echo "${BOLD}${BLUE}Odstraňuji tmp ca.pem...${RESET}"
rm -f "$SCRIPT_DIR/backend/ca.pem"

echo "${BOLD}${BLUE}Spouštím backend kontejner...${RESET}"
docker run -d \
  --env-file "$ENV_FILE" \
  --name "$BACKEND_CONTAINER" \
  --network "$NETWORK_NAME" \
  -p 8050:8050 \
  "$BACKEND_CONTAINER" || handle_error
echo "${BOLD}${GREEN}OPERACE PRO BACKEND DOKONČENY ${RESET}"
echo ""

#
#FRONTEND - pouze pokud není --no-frontend
#
if $RUN_FRONTEND; then
  echo "${BOLD}${GREEN}OPERACE PRO FRONTEND${RESET}"
  if [ -d "$SCRIPT_DIR/frontend/repo" ]; then
    pushd "$SCRIPT_DIR/frontend/repo" >/dev/null || handle_error
    echo "${BOLD}${BLUE}Buildím frontend...${RESET}"
    bash ./mvnw clean package -DskipTests -Pproduction || handle_error

    echo "${BOLD}${BLUE}Kopíruju frontend .jar do build složky pro Docker...${RESET}"
    FRONTEND_JAR=$(find "$SCRIPT_DIR/frontend/repo/target" -name "*.jar" | head -n 1)
    cp "$FRONTEND_JAR" "$SCRIPT_DIR/frontend/app.jar" || handle_error
    popd >/dev/null || true

    echo "${BOLD}${BLUE}Buildím Docker image pro frontend...${RESET}"
    pushd "$SCRIPT_DIR/frontend" >/dev/null || handle_error
    bash ./build_frontend.sh || handle_error
    popd >/dev/null || true

    echo "${BOLD}${BLUE}Spouštím frontend kontejner...${RESET}"
    docker run -d \
      --env-file "$ENV_FILE" \
      --name "$FRONTEND_CONTAINER" \
      --network "$NETWORK_NAME" \
      -p 8081:8081 \
      "$FRONTEND_CONTAINER" || handle_error

    echo "${BOLD}${BLUE}Kopíruju soubory do kontejneru...${RESET}"
    docker cp "$SCRIPT_DIR/frontend/repo/src/main/webapp" "$FRONTEND_CONTAINER:/app/webapp" || handle_error
    echo "${BOLD}${GREEN}Soubory zkopírovány do kontejneru${RESET}"
    echo "${BOLD}${GREEN}OPERACE PRO FRONTEND DOKONČENY${RESET}"
  else
    echo "${RED}Frontend adresář nebyl nalezen – přeskočeno.${RESET}"
  fi
else
  echo "${BOLD}${BLUE}Frontend nebude spuštěn (--no-frontend).${RESET}"
fi

#
# GATEWAY
#
echo "${BOLD}${GREEN}OPERACE PRO GATEWAY${RESET}"
echo "${BOLD}${BLUE}Spouštím Gateway kontejner...${RESET}"
docker run -d \
  --name "$GATEWAY_CONTAINER" \
  --network "$NETWORK_NAME" \
  --network-alias "$GATEWAY_ALIAS" \
  -p 80:80 \
  -v "$SCRIPT_DIR/nginx/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:alpine || handle_error
echo "${BOLD}${GREEN}OPERACE PRO GATEWAY DOKONČENY${RESET}"

#
#FINAL
#
echo ""
echo "${BOLD}${GREEN}SPUŠTĚNÍ DOKONČENO${RESET}"
echo "${BOLD}${BLUE}Aplikace:${RESET}   ${FE_URL:-"http://localhost:80"}"
if ! $RUN_FRONTEND; then
  echo "${BOLD}${BLUE}Frontend:${RESET} SPUSTIT RUČNĚ NA PORTU 8081! Nelze využívat nginx gateway."
fi

