#!/bin/bash
set -euo pipefail

source ./common.sh

load_env() {
  local mode="${1:-prod}"
  local env_file=""

  if [[ "$mode" == "dev" ]]; then
    env_file="$SCRIPT_DIR/.dev.env"
  else
    env_file="$SCRIPT_DIR/.env"
  fi

  if [[ ! -f "$env_file" ]]; then
    echo "Chybí env soubor: $env_file"
    return 1
  fi

  export ENV_FILE="$env_file"
  export $(grep -v '^#' "$env_file" | xargs)

  # Keycloak: browser musí chodit na externí URL, ne na docker DNS.
  export KEYCLOAK_EFFECTIVE_URL="${KEYCLOAK_URL:-}"
  if [[ -n "${KEYCLOAK_EXTERNAL_URL:-}" ]]; then
    export KEYCLOAK_EFFECTIVE_URL="${KEYCLOAK_EXTERNAL_URL}"
    export KEYCLOAK_PUBLIC_URL="${KEYCLOAK_PUBLIC_URL:-$KEYCLOAK_EXTERNAL_URL}"
    export KEYCLOAK_ADMIN_URL="${KEYCLOAK_ADMIN_URL:-$KEYCLOAK_EXTERNAL_URL}"
  else
    export KEYCLOAK_PUBLIC_URL="${KEYCLOAK_PUBLIC_URL:-${KEYCLOAK_URL:-}}"
    export KEYCLOAK_ADMIN_URL="${KEYCLOAK_ADMIN_URL:-${KEYCLOAK_URL:-}}"
  fi

  validate_required_env
}

validate_required_env() {
  local required_vars=(
    NETWORK_NAME
    GATEWAY_ALIAS
    BACKEND_GIT_URL
    FRONTEND_GIT_URL
    MONGO_PASSWORD
  )

  local missing=()
  local var_name
  for var_name in "${required_vars[@]}"; do
    if [[ -z "${!var_name:-}" ]]; then
      missing+=("$var_name")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    echo "${BOLD}${RED}V env souboru ${ENV_FILE:-<unknown>} chybí povinné proměnné: ${missing[*]}${RESET}"
    return 1
  fi
}

ensure_network() {
  if ! docker network ls --format '{{.Name}}' | grep -qx "${NETWORK_NAME:?NETWORK_NAME not set}"; then
    echo "${BOLD}${BLUE}Vytvářím síť $NETWORK_NAME...${RESET}"
    docker network create "$NETWORK_NAME" >/dev/null
  fi
}

fix_sh_perms() {
  local root_dir="${1:?Usage: fix_sh_perms <dir>}"
  find "$root_dir" \
    -path "$root_dir/.git" -prune -o \
    -path "*/target/*" -prune -o \
    -path "*/node_modules/*" -prune -o \
    -type f -name "*.sh" -exec chmod 755 {} + 2>/dev/null || true
}

ensure_repo() {
  local repo_dir="${1:?Usage: ensure_repo <dir> <git-url> [branch]}"
  local git_url="${2:?Usage: ensure_repo <dir> <git-url> [branch]}"
  local branch="${3:-}"

  mkdir -p "$repo_dir"

  local ok=false
  if [[ -d "$repo_dir/.git" ]]; then
    local remote=""
    remote="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || echo "")"
    if [[ -n "$remote" && "$remote" == "$git_url" ]]; then
      ok=true
    fi
  fi

  if ! $ok; then
    echo "${BOLD}${BLUE}Klonuji repo z $git_url ...${RESET}"
    rm -rf "$repo_dir"/* "$repo_dir"/.??* 2>/dev/null || true
    if [[ -n "$branch" ]]; then
      git clone -b "$branch" "$git_url" "$repo_dir"
    else
      git clone "$git_url" "$repo_dir"
    fi
  fi

  if [[ -d "$repo_dir/.git" && -n "$branch" ]]; then
    local current=""
    current="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
    if [[ "$current" != "$branch" ]]; then
      echo "${BOLD}${BLUE}Přepínám repo na větev $branch...${RESET}"
      git -C "$repo_dir" fetch origin
      git -C "$repo_dir" checkout "$branch"
      git -C "$repo_dir" pull origin "$branch"
    fi
  fi
}

wait_container_healthy() {
  local container="${1:?Usage: wait_container_healthy <container> [timeout_seconds]}"
  local timeout="${2:-120}"
  local deadline=$((SECONDS + timeout))

  while true; do
    local health=""
    health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$container" 2>/dev/null || echo missing)"
    if [[ "$health" == "healthy" ]] || [[ "$health" == "no-healthcheck" ]]; then
      return 0
    fi
    if (( SECONDS >= deadline )); then
      echo "${BOLD}${RED}$container není healthy (stav: $health). Výpis logu:${RESET}"
      docker logs --tail 200 "$container" 2>/dev/null || true
      return 1
    fi
    sleep 2
  done
}

