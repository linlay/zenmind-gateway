#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE_ASSETS_DIR="$SCRIPT_DIR/release-assets"

die() { echo "[release] $*" >&2; exit 1; }

VERSION="${VERSION:-$(cat "$REPO_ROOT/VERSION" 2>/dev/null || echo "dev")}"
[[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "VERSION must match vX.Y.Z (got: $VERSION)"

if [[ -z "${ARCH:-}" ]]; then
  case "$(uname -m)" in
    x86_64|amd64) ARCH=amd64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *) die "cannot detect ARCH from $(uname -m); pass ARCH=amd64|arm64" ;;
  esac
fi

PLATFORM="linux/$ARCH"
IMAGE="zenmind-gateway:$VERSION"
BUNDLE_NAME="zenmind-gateway-${VERSION}-linux-${ARCH}"
BUNDLE_TAR="$REPO_ROOT/dist/release/${BUNDLE_NAME}.tar.gz"

command -v docker >/dev/null 2>&1 || die "docker is required"

echo "[release] VERSION=$VERSION ARCH=$ARCH PLATFORM=$PLATFORM"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/zenmind-gateway-release.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

IMAGES_DIR="$TMP_DIR/images"
mkdir -p "$IMAGES_DIR"

echo "[release] building gateway image..."
docker buildx build \
  --platform "$PLATFORM" \
  --file "$REPO_ROOT/docker/Dockerfile.release" \
  --tag "$IMAGE" \
  --output "type=docker,dest=$IMAGES_DIR/zenmind-gateway.tar" \
  "$REPO_ROOT"

BUNDLE_ROOT="$TMP_DIR/zenmind-gateway"
mkdir -p "$BUNDLE_ROOT/images"

cp "$RELEASE_ASSETS_DIR/compose.release.yml" "$BUNDLE_ROOT/compose.release.yml"
cp "$RELEASE_ASSETS_DIR/start.sh" "$BUNDLE_ROOT/start.sh"
cp "$RELEASE_ASSETS_DIR/stop.sh" "$BUNDLE_ROOT/stop.sh"
cp "$RELEASE_ASSETS_DIR/README.txt" "$BUNDLE_ROOT/README.txt"
cp "$REPO_ROOT/.env.example" "$BUNDLE_ROOT/.env.example"
cp "$IMAGES_DIR/zenmind-gateway.tar" "$BUNDLE_ROOT/images/"

sed -i.bak "s/^GATEWAY_VERSION=.*/GATEWAY_VERSION=$VERSION/" "$BUNDLE_ROOT/.env.example"
rm -f "$BUNDLE_ROOT/.env.example.bak"

chmod +x "$BUNDLE_ROOT/start.sh" "$BUNDLE_ROOT/stop.sh"

mkdir -p "$(dirname "$BUNDLE_TAR")"
tar -czf "$BUNDLE_TAR" -C "$TMP_DIR" zenmind-gateway

echo "[release] done: $BUNDLE_TAR"
