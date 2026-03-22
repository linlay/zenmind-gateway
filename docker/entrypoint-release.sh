#!/bin/sh
set -eu

die() {
  echo "[entrypoint] $*" >&2
  exit 1
}

validate_mode() {
  name="$1"
  value="$2"

  case "$value" in
    host|container) ;;
    *) die "$name must be host or container (got: $value)" ;;
  esac
}

AP_BACKEND_MODE="${AP_BACKEND_MODE:-container}"
TERM_BACKEND_MODE="${TERM_BACKEND_MODE:-host}"
PAN_BACKEND_MODE="${PAN_BACKEND_MODE:-host}"

validate_mode AP_BACKEND_MODE "$AP_BACKEND_MODE"
validate_mode TERM_BACKEND_MODE "$TERM_BACKEND_MODE"
validate_mode PAN_BACKEND_MODE "$PAN_BACKEND_MODE"

cp "/opt/zenmind/nginx-backends/ap-backend.${AP_BACKEND_MODE}.conf" \
  /etc/nginx/conf.d/ap-backend.conf
cp "/opt/zenmind/nginx-backends/term-backends.${TERM_BACKEND_MODE}.conf" \
  /etc/nginx/conf.d/term-backends.conf
cp "/opt/zenmind/nginx-backends/pan-backends.${PAN_BACKEND_MODE}.conf" \
  /etc/nginx/conf.d/pan-backends.conf

nginx -t >/dev/null

exec "$@"
