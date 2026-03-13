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
pushd "$SCRIPT_DIR/backend/repo/redis" >/dev/null
docker compose down 2>/dev/null || true
popd >/dev/null || true
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
#CERTIFIKÁTY
#
echo "${BOLD}${GREEN}OPERACE PRO CERTIFIKÁTY${RESET}"

echo "${BOLD}${BLUE}Odstraňuji staré certs-main a keyfile před startem Mongo...${RESET}"
rm -rf "$SCRIPT_DIR/backend/repo/mongo/certs-main" "$SCRIPT_DIR/backend/repo/mongo/certs-replica-1" "$SCRIPT_DIR/backend/repo/mongo/certs-replica-2" "$SCRIPT_DIR/backend/repo/mongo/keyfile" || true
echo "${BOLD}${BLUE}Smazání starých souborů dokončeno.${RESET}"

echo "${BOLD}${BLUE}Odstraňuji staré certs-node složky pro Redis...${RESET}"
rm -rf "$SCRIPT_DIR/backend/repo/redis/certs-node-1" "$SCRIPT_DIR/backend/repo/redis/certs-node-2" "$SCRIPT_DIR/backend/repo/redis/certs-node-3" "$SCRIPT_DIR/backend/repo/redis/certs-node-4" "$SCRIPT_DIR/backend/repo/redis/certs-node-5" "$SCRIPT_DIR/backend/repo/redis/certs-node-6" "$SCRIPT_DIR/backend/repo/redis/certs-node-7" "$SCRIPT_DIR/backend/repo/redis/certs-node-8" "$SCRIPT_DIR/backend/repo/redis/certs-node-9" || true
echo "${BOLD}${BLUE}Smazání starých redis certs dokončeno.${RESET}"

echo "${BOLD}${BLUE}Generuji CA certifikát...${RESET}"
pushd "$SCRIPT_DIR/backend/repo/script-utils" >/dev/null || handle_error
bash "./generate-ca.sh" "$MONGO_PASSWORD"
popd >/dev/null || true
echo "${BOLD}${GREEN}CA certifikát vygenerován.${RESET}"

#
#MONGO
#
echo "${BOLD}${GREEN}OPERACE PRO MONGO${RESET}"
echo "${BOLD}${BLUE}Generuji certifikáty pro MongoDB...${RESET}"
pushd "$SCRIPT_DIR/backend/repo/script-utils" >/dev/null || handle_error
bash "./generate-all-mongo-certs.sh"
popd >/dev/null || true
echo "${BOLD}${BLUE}Spouštím MongoDB...${RESET}"
pushd "$SCRIPT_DIR/backend/repo/mongo" >/dev/null || handle_error
MONGO_CONF_OVERRIDE="$SCRIPT_DIR/mongo/mongod.conf"
if [[ -f "$MONGO_CONF_OVERRIDE" ]]; then
  cp "$MONGO_CONF_OVERRIDE" "$SCRIPT_DIR/backend/repo/mongo/conf/mongod.conf"
fi

# Generate keyfile (replica set auth) – do not rely on backend repo helper that hardcodes network name.
bash "$SCRIPT_DIR/backend/repo/mongo/scripts/generate-keyfile.sh" "$SCRIPT_DIR/backend/repo/mongo/keyfile" || handle_error

MONGO_COMPOSE_OVERRIDE="$SCRIPT_DIR/overrides/mongo/docker-compose.override.yml"
if [[ -f "$MONGO_COMPOSE_OVERRIDE" ]]; then
  compose -f docker-compose.yml -f "$MONGO_COMPOSE_OVERRIDE" down -v >/dev/null 2>&1 || true
  compose -f docker-compose.yml -f "$MONGO_COMPOSE_OVERRIDE" up -d || handle_error
else
  compose -f docker-compose.yml down -v >/dev/null 2>&1 || true
  compose -f docker-compose.yml up -d || handle_error
fi
popd >/dev/null || true

# Preflight: BE musí umět resolvnout mongo-* jména přes Docker DNS (stejná síť).
wait_container_on_network "mongo-main" "$NETWORK_NAME" 60 || handle_error
wait_container_on_network "mongo-replica-1" "$NETWORK_NAME" 60 || handle_error
wait_container_on_network "mongo-replica-2" "$NETWORK_NAME" 60 || handle_error

echo "${BOLD}${GREEN}MongoDB spuštěno.${RESET}"
echo "${BOLD}${GREEN}OPERACE PRO MONGO DOKONČENY${RESET}"
echo ""

#
#REDIS
#
echo "${BOLD}${GREEN}OPERACE PRO REDIS${RESET}"
echo "${BOLD}${BLUE}Generuji certifikáty pro Redis...${RESET}"
pushd "$SCRIPT_DIR/backend/repo/script-utils" >/dev/null || handle_error
bash "./generate-all-redis-certs.sh"
popd >/dev/null || true
echo "${BOLD}${BLUE}Spouštím Redis...${RESET}"
pushd "$SCRIPT_DIR/backend/repo/redis" >/dev/null || handle_error
REDIS_COMPOSE_OVERRIDE="$SCRIPT_DIR/overrides/redis/docker-compose.override.yml"
if [[ -f "$REDIS_COMPOSE_OVERRIDE" ]]; then
  compose -f docker-compose.yaml -f "$REDIS_COMPOSE_OVERRIDE" up -d || handle_error
else
  compose up -d || handle_error
fi
popd >/dev/null || true
echo "${BOLD}${GREEN}Redis spuštěn.${RESET}"
echo "${BOLD}${GREEN}OPERACE PRO REDIS DOKONČENY${RESET}"
echo ""
#
#SECURITY
#
echo "${BOLD}${GREEN}OPERACE PRO SECURITY${RESET}"
echo "${BOLD}${BLUE}Spouštím Security...${RESET}"
pushd "$SCRIPT_DIR/backend/repo/mocked-auth-providers" >/dev/null || handle_error
KEYCLOAK_OVERRIDE="$SCRIPT_DIR/overrides/mocked-auth-providers/docker-compose.override.yaml"
if [[ -f "$KEYCLOAK_OVERRIDE" ]]; then
  compose -f docker-compose.yaml -f "$KEYCLOAK_OVERRIDE" up -d || handle_error
else
  compose up -d || handle_error
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
cp "$SCRIPT_DIR/backend/repo/mongo/certs-main/ca.pem" "$SCRIPT_DIR/backend"

BACKEND_FINGERPRINT="$(get_repo_fingerprint "$SCRIPT_DIR/backend/repo")"
NEEDS_BACKEND_BUILD=true
if docker image inspect "$BACKEND_CONTAINER" >/dev/null 2>&1 && image_matches_fingerprint "$BACKEND_CONTAINER" "$BACKEND_FINGERPRINT"; then
  NEEDS_BACKEND_BUILD=false
fi

if [[ "$NEEDS_BACKEND_BUILD" == "true" ]]; then
  echo "${BOLD}${BLUE}Buildím backend pomocí Gradle...${RESET}"
  pushd "$SCRIPT_DIR/backend/repo" >/dev/null || handle_error
  ./gradlew bootJar -x test || handle_error
  echo "${BOLD}${GREEN}Backend úspěšně sestaven.${RESET}"

  echo "${BOLD}${BLUE}Kopíruju backend .jar do build složky pro Docker...${RESET}"
  BACKEND_JAR=$(find "$SCRIPT_DIR/backend/repo/build/libs" -name "*.jar" \
    ! -name "*-plain.jar" \
    ! -name "*-sources.jar" \
    ! -name "*-javadoc.jar" | sort | head -n 1)

  if [[ -z "$BACKEND_JAR" ]]; then
    echo "${RED}Nebyl nalezen spustitelný backend jar!${RESET}"
    exit 1
  fi

  cp "$BACKEND_JAR" "$SCRIPT_DIR/backend/app.jar" || handle_error

  echo "${BOLD}${BLUE}Kontroluji manifest backend jaru...${RESET}"
  unzip -p "$SCRIPT_DIR/backend/app.jar" META-INF/MANIFEST.MF | grep -E "Main-Class|Start-Class" || {
    echo "${RED}Backend app.jar není spustitelný jar!${RESET}"
    exit 1
  }
  popd >/dev/null || true

  echo "${BOLD}${BLUE}Buildím Docker image pro backend...${RESET}"
  pushd "$SCRIPT_DIR/backend" >/dev/null || handle_error
  IMAGE_FINGERPRINT="$BACKEND_FINGERPRINT" bash ./build_backend.sh "${MONGO_PASSWORD:-adminpassword}" || handle_error
  popd >/dev/null || true
else
  echo "${BOLD}${BLUE}Backend image je aktuální ($BACKEND_FINGERPRINT), přeskakuji build...${RESET}"
fi

echo "${BOLD}${BLUE}Odstraňuji tmp ca.pem...${RESET}"
rm -f "$SCRIPT_DIR/backend/ca.pem"

echo "${BOLD}${BLUE}Spouštím backend kontejner...${RESET}"
docker run -d \
  --env-file "$ENV_FILE" \
  --name "$BACKEND_CONTAINER" \
  --restart unless-stopped \
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
    FRONTEND_FINGERPRINT="$(get_repo_fingerprint "$SCRIPT_DIR/frontend/repo")"
    NEEDS_FRONTEND_BUILD=true
    if docker image inspect "$FRONTEND_CONTAINER" >/dev/null 2>&1 && image_matches_fingerprint "$FRONTEND_CONTAINER" "$FRONTEND_FINGERPRINT"; then
      NEEDS_FRONTEND_BUILD=false
    fi

    pushd "$SCRIPT_DIR/frontend/repo" >/dev/null || handle_error
    if [[ "$NEEDS_FRONTEND_BUILD" == "true" ]]; then
      echo "${BOLD}${BLUE}Buildím frontend...${RESET}"
      bash ./mvnw clean package -DskipTests -Pproduction || handle_error

      echo "${BOLD}${BLUE}Kopíruju frontend .jar do build složky pro Docker...${RESET}"
      FRONTEND_JAR=$(find "$SCRIPT_DIR/frontend/repo/target" -name "*.jar" \
        ! -name "*-sources.jar" \
        ! -name "*-javadoc.jar" \
        ! -name "*-plain.jar" | sort | head -n 1)

      if [[ -z "$FRONTEND_JAR" ]]; then
        echo "${RED}Nebyl nalezen spustitelný frontend jar!${RESET}"
        exit 1
      fi

      cp "$FRONTEND_JAR" "$SCRIPT_DIR/frontend/app.jar" || handle_error

      echo "${BOLD}${BLUE}Kontroluji manifest frontend jaru...${RESET}"
      unzip -p "$SCRIPT_DIR/frontend/app.jar" META-INF/MANIFEST.MF | grep -E "Main-Class|Start-Class" || {
        echo "${RED}Frontend app.jar není spustitelný jar!${RESET}"
        exit 1
      }
    else
      echo "${BOLD}${BLUE}Frontend image je aktuální ($FRONTEND_FINGERPRINT), přeskakuji build...${RESET}"
    fi
    popd >/dev/null || true

    if [[ "$NEEDS_FRONTEND_BUILD" == "true" ]]; then
      echo "${BOLD}${BLUE}Buildím Docker image pro frontend...${RESET}"
      pushd "$SCRIPT_DIR/frontend" >/dev/null || handle_error
      IMAGE_FINGERPRINT="$FRONTEND_FINGERPRINT" bash ./build_frontend.sh || handle_error
      popd >/dev/null || true
    fi

    echo "${BOLD}${BLUE}Spouštím frontend kontejner...${RESET}"
    docker run -d \
      --env-file "$ENV_FILE" \
      --name "$FRONTEND_CONTAINER" \
      --restart unless-stopped \
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
# Výběr  nginx konfiguračního souboru dle --dev
if [[ "$MODE" == "dev" ]]; then
  NGINX_CONFIG="nginx-dev.conf"
else
  NGINX_CONFIG="nginx.conf"  
fi

echo "${BOLD}${GREEN}OPERACE PRO GATEWAY${RESET}"
echo "${BOLD}${BLUE}Spouštím Gateway kontejner (config: $NGINX_CONFIG)...${RESET}"
docker run -d \
  --name "$GATEWAY_CONTAINER" \
  --restart unless-stopped \
  --network "$NETWORK_NAME" \
  --network-alias "$GATEWAY_ALIAS" \
  -p 80:80 \
  -v "$SCRIPT_DIR/nginx/$NGINX_CONFIG:/etc/nginx/nginx.conf:ro" \
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
