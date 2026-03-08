# zenmind-gateway

## 1. 项目简介

`zenmind-gateway` 是本地统一入口网关，固定入口为 `127.0.0.1:11945`。  
除 `/term`、`/appterm`、`/pan`、`/apppan`、`/ma` 外，其他业务路径优先走 Docker 网络 `zenmind-network` 转发到容器；各服务独立宿主机端口继续保留。

## 2. 快速开始

### 前置要求

- Docker Desktop（含 Docker Compose）
- 本机存在以下项目目录：
  - `~/Project/agent-platform-runner`
  - `~/Project/zenmind-app-server`
  - `~/Project/mcp-server-mock`
  - `~/Project/mcp-server-email`
  - `~/Project/mcp-server-bash`
  - `~/Project/term-webclient`
  - `~/Project/pan-webclient`

### 本地启动

```bash
cd ~/Project/zenmind-gateway
./start.sh
```

首次启动本项目会自动创建 `zenmind-network`。  
随后按顺序启动上游服务（已保留各自宿主机端口）：

```bash
cd ~/Project/zenmind-app-server && docker compose up -d --build
cd ~/Project/agent-platform-runner && docker compose up -d --build
cd ~/Project/mcp-server-mock && docker compose up -d --build
cd ~/Project/mcp-server-email && docker compose up -d --build
cd ~/Project/mcp-server-bash && docker compose up -d --build
```

启动 term-webclient（保持其原有启动方式）：

```bash
cd ~/Project/term-webclient
./release-scripts/mac/start.sh
```

如需启用 pan host 模式，请先启动 pan-webclient（宿主机 `11946`）：

```bash
cd ~/Project/pan-webclient
make web-build
APP_PORT=11946 PAN_STATIC_DIR=apps/web/dist make api-run
```

最后启动网关：

```bash
cd ~/Project/zenmind-gateway
./start.sh
```

### 路由验证

```bash
curl -i http://127.0.0.1:11945/healthz
curl -i http://127.0.0.1:11945/ma/
curl -i http://127.0.0.1:11945/ma/note/api/ping
curl -i http://127.0.0.1:11945/openid/.well-known/openid-configuration
curl -i -X POST http://127.0.0.1:11945/api/mcp/mock -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":"1","method":"tools/list"}'
```

## 3. 配置说明

- 网关配置文件：
  - 环境变量契约：`.env.example`（`GATEWAY_PORT=11945`、`AP_BACKEND_MODE=container`、`TERM_BACKEND_MODE=host`、`PAN_BACKEND_MODE=host`）
  - 路由规则：`nginx.conf`
- 配置优先级：`.env` > `.env.example`
- 网关不保存业务密钥；业务密钥在各子项目独立维护
- `zenmind-network` 是统一容器网络契约，除 term 外所有网关转发依赖该网络
- 该网络由本项目首次 `docker compose up -d` 自动创建（固定名称：`zenmind-network`）

### `/ma` 固定宿主机代理

- `/ma/*` 固定转发到 `host.docker.internal:11955`
- 转发前会去掉 `/ma` 前缀：
  - `/ma/` -> `http://host.docker.internal:11955/`
  - `/ma/note/` -> `http://host.docker.internal:11955/note/`
  - `/ma/note/api/ping` -> `http://host.docker.internal:11955/note/api/ping`
- `GET /ma` 会 `301` 到 `/ma/`
- 会改写上游返回的相对根 `Location` 响应头到 `/ma/*`
- 不改写 HTML、JS、CSS、JSON 响应体
- 不引入 `.env` 模式切换，`11955` 为固定宿主机上游

### `/api/ap/` 上游切换

- `AP_BACKEND_MODE=container`（默认）：
  - `/api/ap/` -> `agent-platform-runner:8080`
- `AP_BACKEND_MODE=host`：
  - `/api/ap/` -> `host.docker.internal:11949`
- 修改 `.env` 后执行 `docker compose up -d` 使配置生效

### `/appterm`、`/term` 上游切换

- `TERM_BACKEND_MODE=host`（默认）：
  - `/appterm` -> `host.docker.internal:11947`
  - `/term` -> `host.docker.internal:11947`
- `TERM_BACKEND_MODE=container`：
  - `/appterm` -> `term-webclient-frontend:80`
  - `/term` -> `term-webclient-frontend:80`
- `/appterm` 当前仍经 term frontend 反向代理，不是直接命中 term backend
- 修改 `.env` 后执行 `docker compose up -d` 使配置生效

### `/pan`、`/apppan` 上游切换

- `PAN_BACKEND_MODE=host`（默认）：
  - `/pan`、`/pan/api/`、`/pan/assets/` -> `host.docker.internal:11946`
  - `/apppan`、`/apppan/api/`、`/apppan/assets/` -> `host.docker.internal:11946`
- `PAN_BACKEND_MODE=container`：
  - `/pan`、`/pan/api/`、`/pan/assets/` -> `pan-webclient:8080`
  - `/apppan`、`/apppan/api/`、`/apppan/assets/` -> `pan-webclient:8080`
- `pan-webclient` container 模式要求服务容器加入 `zenmind-network`，并可由 gateway 解析为 `pan-webclient`
- 修改 `.env` 后执行 `docker compose up -d` 使配置生效

### 端口矩阵（宿主机）

- `11945`：gateway（统一入口）
- `11952`：zenmind-app-server backend
- `11950`：zenmind-app-server frontend
- `11949`：agent-platform-runner
- `11969`：mcp-server-mock
- `11967`：mcp-server-email
- `11963`：mcp-server-bash
- `11947`：term-webclient frontend（网关 `/term`、`/appterm` 转发目标）
- `11937`：term-webclient backend（由 term-webclient 自身使用）
- `11946`：pan-webclient backend（网关 `/pan`、`/apppan` 转发目标）
- `11955`：MA 宿主机服务（网关 `/ma/*` 转发目标）

### 网关路由矩阵

- `/admin/api`、`/api/auth`、`/api/app`、`/oauth2`、`/openid` -> `app-server-backend:8080`
- `/admin` -> `app-server-frontend:80`
- `/api/ap/` -> `AP_BACKEND_MODE=container` 时 `agent-platform-runner:8080`；`AP_BACKEND_MODE=host` 时 `host.docker.internal:11949`
- `/api/mcp/mock` -> `mcp-server-mock:8080/mcp`
- `/api/mcp/email` -> `mcp-server-email:8080/mcp`
- `/api/mcp/bash` -> `mcp-server-bash:8080/mcp`
- `/appterm` -> `TERM_BACKEND_MODE=host` 时 `host.docker.internal:11947`；`TERM_BACKEND_MODE=container` 时 `term-webclient-frontend:80`
- `/term` -> `TERM_BACKEND_MODE=host` 时 `host.docker.internal:11947`；`TERM_BACKEND_MODE=container` 时 `term-webclient-frontend:80`
- `/ma/*` -> `host.docker.internal:11955`，转发前去掉 `/ma` 前缀
- `/ma/*` 的 `Location: /foo` 响应头会被改写为 `Location: /ma/foo`
- `/pan` -> `PAN_BACKEND_MODE=host` 时 `host.docker.internal:11946`；`PAN_BACKEND_MODE=container` 时 `pan-webclient:8080`
- `/pan/api/*`、`/pan/assets/*` -> rewrite 后转发到 pan 上游 `/api/*`、`/assets/*`
- `/apppan` -> `PAN_BACKEND_MODE=host` 时 `host.docker.internal:11946`；`PAN_BACKEND_MODE=container` 时 `pan-webclient:8080`
- `/apppan/api/*`、`/apppan/assets/*` -> rewrite 后转发到 pan 上游 `/api/*`、`/assets/*`

## 4. 部署

### 本地容器部署（推荐）

```bash
cd ~/Project/zenmind-gateway
./start.sh --build
```

### 重启网关（配置变更后）

```bash
cd ~/Project/zenmind-gateway
docker compose down
docker compose up -d
```

## 5. 运维

### 查看网关日志

```bash
cd ~/Project/zenmind-gateway
docker compose logs -f gateway
```

### 常见排查

- `502 Bad Gateway`
  - 检查目标服务容器是否启动
  - 检查目标容器是否接入 `zenmind-network`
  - 检查网关中服务别名是否与 compose 别名一致
  - 若 `PAN_BACKEND_MODE=host`，检查 pan-webclient 是否已监听 `127.0.0.1:11946`
  - 若访问 `/ma/*`，检查宿主机服务是否已监听 `127.0.0.1:11955`
- 端口占用
  - `lsof -nP -iTCP:11945 -sTCP:LISTEN`
- 规则未生效
  - 执行 `docker compose down && docker compose up -d` 重新加载 `nginx.conf`

### 快速自检命令

```bash
docker network inspect zenmind-network
docker ps --format 'table {{.Names}}\t{{.Ports}}'
curl -i http://127.0.0.1:11945/healthz
curl -i http://127.0.0.1:11945/ma/
```
