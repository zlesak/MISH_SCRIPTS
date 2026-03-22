#!/bin/bash
set -euo pipefail

source ./lib.sh

MODE="prod"

while [[ $# -gt 0 ]]; do
  case $1 in
    --dev)
      MODE="dev"
      shift
      ;;
    *)
      echo "Neznámý argument: $1"
      echo "Použití: $0 [--dev]"
      exit 1
      ;;
  esac
done

load_env "$MODE"
ensure_network

NGINX_CONFIG="nginx.conf"
NGINX_CONFIG_PATH="$SCRIPT_DIR/nginx/$NGINX_CONFIG"

if [[ ! -f "$NGINX_CONFIG_PATH" ]]; then
  echo "Chybí nginx config: $NGINX_CONFIG_PATH"
  exit 1
fi

SSL_DIR="$SCRIPT_DIR/nginx/ssl"
CERT_FILE="$SSL_DIR/fullchain.pem"
KEY_FILE="$SSL_DIR/privkey.pem"

mkdir -p "$SSL_DIR"

if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
  echo "${BOLD}${BLUE}Generuji self-signed certifikát...${RESET}"
  openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout "$KEY_FILE" \
  -out "$CERT_FILE" \
  -subj "/C=CZ/ST=HradecKralove/L=HradecKralove/O=UHK/OU=IMIT/CN=imitgw.uhk.cz"
fi

echo "${BOLD}${GREEN}OPERACE PRO GATEWAY${RESET}"
echo "${BOLD}${BLUE}Restartuji Gateway kontejner (mode: $MODE, config: $NGINX_CONFIG)...${RESET}"
docker rm -f "$GATEWAY_CONTAINER" 2>/dev/null || true

docker run -d \
  --name "$GATEWAY_CONTAINER" \
  --restart unless-stopped \
  --network "$NETWORK_NAME" \
  --network-alias "$GATEWAY_ALIAS" \
  -p 80:80 \
  -p 443:443 \
  -v "$NGINX_CONFIG_PATH:/etc/nginx/nginx.conf:ro" \
  -v "$SCRIPT_DIR/nginx/ssl:/etc/nginx/ssl:ro" \
  nginx:alpine || handle_error

echo "${BOLD}${GREEN}Gateway deploy dokončen.${RESET}"

