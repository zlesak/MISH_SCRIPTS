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

get_src_hash() {
    local repo_dir="$1"
    local src_dir="$repo_dir/src"

    # Prefer git HEAD (fast + stable) if repo is a git clone
    if [[ -d "$repo_dir/.git" ]] && command -v git >/dev/null 2>&1; then
      local head=""
      head="$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null || true)"
      if [[ -n "$head" ]]; then
        local dirty=""
        dirty="$(git -C "$repo_dir" status --porcelain 2>/dev/null || true)"
        if [[ -n "$dirty" ]]; then
          echo "git:${head}+dirty:$(git -C "$repo_dir" diff --no-ext-diff | hash_stdin_md5)"
        else
          echo "git:${head}"
        fi
        return 0
      fi
    fi

    # Fallback: content hash of src + build files
    if [[ ! -d "$src_dir" ]]; then
        echo "missing_src"
        return 0
    fi

    (find "$src_dir" -type f -print0 | sort -z | xargs -0 cat; cat "$repo_dir/pom.xml" 2>/dev/null; cat "$repo_dir/build.gradle" 2>/dev/null; cat "$repo_dir/build.gradle.kts" 2>/dev/null) | hash_stdin_md5
}
