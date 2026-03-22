#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "[stop] $*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die "docker is required"
docker compose version >/dev/null 2>&1 || die "docker compose v2 is required"

cd "$SCRIPT_DIR"
docker compose down "$@"

echo "[stop] stopped zenmind-gateway"
