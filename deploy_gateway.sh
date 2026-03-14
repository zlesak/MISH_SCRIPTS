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

if [[ "$MODE" == "dev" ]]; then
  NGINX_CONFIG="nginx-dev.conf"
else
  NGINX_CONFIG="nginx.conf"
fi

echo "${BOLD}${GREEN}OPERACE PRO GATEWAY${RESET}"
echo "${BOLD}${BLUE}Restartuji Gateway kontejner (config: $NGINX_CONFIG)...${RESET}"
docker rm -f "$GATEWAY_CONTAINER" 2>/dev/null || true

docker run -d \
  --name "$GATEWAY_CONTAINER" \
  --restart unless-stopped \
  --network "$NETWORK_NAME" \
  --network-alias "$GATEWAY_ALIAS" \
  -p 80:80 \
  -v "$SCRIPT_DIR/nginx/$NGINX_CONFIG:/etc/nginx/nginx.conf:ro" \
  nginx:alpine || handle_error

echo "${BOLD}${GREEN}Gateway deploy dokončen.${RESET}"

