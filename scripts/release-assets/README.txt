zenmind-gateway release bundle

1. Copy .env.example to .env
2. Adjust GATEWAY_PORT / AP_BACKEND_MODE / TERM_BACKEND_MODE / PAN_BACKEND_MODE if needed
3. Run ./start.sh

The bundle contains only the gateway image and deployment assets.
Upstream services must already be reachable through zenmind-network or host.docker.internal.
