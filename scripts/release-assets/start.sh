#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
COMPOSE_FILE="$SCRIPT_DIR/compose.release.yml"
IMAGES_DIR="$SCRIPT_DIR/images"
NETWORK_NAME="zenmind-network"

die() { echo "[start] $*" >&2; exit 1; }

[[ -f "$ENV_FILE" ]] || die "missing .env (copy from .env.example first)"

command -v docker >/dev/null 2>&1 || die "docker is required"
docker compose version >/dev/null 2>&1 || die "docker compose v2 is required"

set -a
. "$ENV_FILE"
set +a

GATEWAY_VERSION="${GATEWAY_VERSION:-latest}"
GATEWAY_PORT="${GATEWAY_PORT:-11945}"
IMAGE="zenmind-gateway:$GATEWAY_VERSION"

load_image() {
  local ref="$1"
  local tar="$2"

  if docker image inspect "$ref" >/dev/null 2>&1; then
    return 0
  fi

  [[ -f "$tar" ]] || die "missing image tar: $tar"
  docker load -i "$tar" >/dev/null
  docker image inspect "$ref" >/dev/null 2>&1 || die "failed to load image: $ref"
}

ensure_network() {
  if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    return 0
  fi

  docker network create "$NETWORK_NAME" >/dev/null
}

load_image "$IMAGE" "$IMAGES_DIR/zenmind-gateway.tar"
ensure_network

export GATEWAY_VERSION GATEWAY_PORT AP_BACKEND_MODE TERM_BACKEND_MODE PAN_BACKEND_MODE
docker compose -f "$COMPOSE_FILE" up -d

echo "[start] started zenmind-gateway $GATEWAY_VERSION"
echo "[start] health: http://127.0.0.1:${GATEWAY_PORT}/healthz"
