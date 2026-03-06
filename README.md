# zenmind-gateway

Dockerized nginx gateway for the local `127.0.0.1:11945` ingress.

## What It Routes

- `/healthz` -> gateway local health check
- `/admin/api`, `/api/auth`, `/api/app`, `/oauth2`, `/openid` -> `auth-backend:8080`
- `/admin` -> `auth-frontend:80`
- `/api/ap/` -> `agent-platform:8080`
- `/term`, `/appterm` -> `host.docker.internal:11947`

All Dockerized upstreams are reached by Docker network alias on the shared external network `zenmind-network`. `term-webclient` remains a host-side exception.

## Files

- `docker-compose.yml`: gateway container definition
- `.env.example`: optional host port override
- `nginx.conf`: nginx config listening on container port `11945`

## Start

1. Prepare local env if you want to keep the default port declaration explicit:

   ```bash
   cp .env.example .env
   ```

2. Create the shared network once:

   ```bash
   docker network create zenmind-network
   ```

3. Recreate upstream services so they join the shared network:

   ```bash
   cd /Users/linlay-macmini/Project/zenmind-app-server
   docker compose up -d --build

   cd /Users/linlay-macmini/Project/agent-platform-runner
   docker compose up -d --build
   ```

4. Stop the old host nginx listener on `11945` if it is still active:

   ```bash
   lsof -nP -iTCP:11945 -sTCP:LISTEN
   ```

5. Start the gateway:

   ```bash
   cd /Users/linlay-macmini/Project/zenmind-gateway
   docker compose up -d
   ```

## Verify

```bash
docker network inspect zenmind-network
curl -i http://127.0.0.1:11945/healthz
curl -i http://127.0.0.1:11945/openid/.well-known/openid-configuration
```

Expected behavior:

- `healthz` returns `200 ok`
- auth routes proxy to `app-auth-backend`
- `/admin/` loads the auth frontend through the gateway
- `/api/ap/...` works after `agent-platform-runner` is deployed on Docker
- `/term/` and `/appterm/` continue to proxy to the host listener on `11947`

If `agent-platform` is not running yet, `/api/ap/...` is expected to return `502`.

## Troubleshooting

- Check gateway logs:

  ```bash
  docker compose logs -f gateway
  ```

- Confirm upstream aliases from inside the network:

  ```bash
  docker network inspect zenmind-network
  ```

- If `11945` fails to bind, another local process is still listening on that port.
