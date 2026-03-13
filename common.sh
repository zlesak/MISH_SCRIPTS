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
    echo "${BOLD}${RED}Došlo k chybě!${RESET}"
    exit 1
}
trap handle_error ERR

# Názvy kontejnerů
SECURITY_CONTAINER=mock-oidc
BACKEND_CONTAINER=kotlin-backend
MONGO_CONTAINER=mongo-tls
MONGO_MAIN_CONTAINER=mongo-main
MONGO_REPLICA1_CONTAINER=mongo-replica-1
MONGO_REPLICA2_CONTAINER=mongo-replica-2
FRONTEND_CONTAINER=vaadin-frontend
GATEWAY_CONTAINER=mish-gateway

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

hash_stdin_md5() {
  if command -v md5sum >/dev/null 2>&1; then
    md5sum | cut -d' ' -f1
  elif command -v md5 >/dev/null 2>&1; then
    md5 -q
  else
    echo "missing_md5_tool"
    return 1
  fi
}

get_repo_fingerprint() {
  local repo_dir="$1"

  if [[ -d "$repo_dir/.git" ]] && command -v git >/dev/null 2>&1; then
    local head=""
    head="$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null || true)"
    if [[ -n "$head" ]]; then
      local dirty=""
      dirty="$(git -C "$repo_dir" status --porcelain 2>/dev/null || true)"
      if [[ -n "$dirty" ]]; then
        local diff_hash=""
        diff_hash="$(git -C "$repo_dir" diff --no-ext-diff | hash_stdin_md5 2>/dev/null || true)"
        echo "git:${head}+dirty:${diff_hash:-unknown}"
      else
        echo "git:${head}"
      fi
      return 0
    fi
  fi

  echo "nogit:$(date +%s)"
}

get_image_label() {
  local image="$1"
  local label_key="$2"

  local value=""
  value="$(docker image inspect "$image" --format "{{ index .Config.Labels \"${label_key}\" }}" 2>/dev/null || true)"
  if [[ "$value" == "<no value>" ]]; then
    value=""
  fi
  echo "$value"
}

image_matches_fingerprint() {
  local image="$1"
  local fingerprint="$2"

  [[ "$(get_image_label "$image" "mish.repo_fingerprint")" == "$fingerprint" ]]
}

container_exists() {
  local container="$1"
  docker container inspect "$container" >/dev/null 2>&1
}

container_running() {
  local container="$1"
  [[ "$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || echo "false")" == "true" ]]
}

container_in_network() {
  local container="$1"
  local network="$2"
  docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{println $k}}{{end}}' "$container" 2>/dev/null | grep -qx "$network"
}

require_container_on_network() {
  local container="$1"
  local network="$2"

  if ! container_exists "$container"; then
    echo "${BOLD}${RED}Chybí kontejner ${container} (není vytvořen).${RESET}"
    return 1
  fi
  if ! container_running "$container"; then
    echo "${BOLD}${RED}Kontejner ${container} neběží.${RESET}"
    return 1
  fi
  if ! container_in_network "$container" "$network"; then
    echo "${BOLD}${RED}Kontejner ${container} není v síti ${network}.${RESET}"
    return 1
  fi
  return 0
}

wait_container_on_network() {
  local container="$1"
  local network="$2"
  local timeout_seconds="${3:-60}"

  local start_ts
  start_ts="$(date +%s)"

  while true; do
    if require_container_on_network "$container" "$network" >/dev/null 2>&1; then
      return 0
    fi

    local now_ts
    now_ts="$(date +%s)"
    if (( now_ts - start_ts >= timeout_seconds )); then
      require_container_on_network "$container" "$network"
      return 1
    fi
    sleep 1
  done
}
