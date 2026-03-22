#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_NAME="zenmind-network"

die() { echo "[start] $*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die "docker is required"
docker compose version >/dev/null 2>&1 || die "docker compose v2 is required"

if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  docker network create "$NETWORK_NAME" >/dev/null
fi

cd "$SCRIPT_DIR"
docker compose up -d "$@"

PORT="$(grep -E '^GATEWAY_PORT=' "${SCRIPT_DIR}/.env" 2>/dev/null | tail -n1 | cut -d= -f2 || true)"
PORT="${PORT:-11945}"

echo "[start] started zenmind-gateway"
echo "[start] health: http://127.0.0.1:${PORT}/healthz"
