# zenmind-gateway

## 1. 项目简介

`zenmind-gateway` 是本地统一入口网关，固定入口为 `127.0.0.1:11945`。

- 除 `/term`、`/appterm`、`/pan`、`/apppan`、`/ma` 外，其他业务路径优先走 Docker 网络 `zenmind-network` 转发到容器
- term、pan 支持 `host|container` 模式切换
- `/ma/*` 固定转发到 `host.docker.internal:11955`

## 2. 快速开始

### 前置要求

- Docker Desktop 或可用的 Docker Engine + Docker Compose v2
- 上游服务已按各自项目方式启动

### 本地启动

```bash
cd ~/Project/zenmind-gateway
cp .env.example .env
./start.sh
```

`./start.sh` 会自动确保 `zenmind-network` 存在，然后执行 `docker compose up -d`。

如需显式重建：

```bash
cd ~/Project/zenmind-gateway
./start.sh --build
```

停止网关：

```bash
cd ~/Project/zenmind-gateway
./stop.sh
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

配置文件：

- 环境变量模板：`.env.example`
- 开发态编排：`compose.yml`
- 路由规则：`nginx.conf`
- 模式片段：`nginx-backends/`

配置优先级：

- `.env` 覆盖 `.env.example`

主要环境变量：

- `GATEWAY_VERSION=latest`
- `GATEWAY_PORT=11945`
- `AP_BACKEND_MODE=container`
- `TERM_BACKEND_MODE=host`
- `PAN_BACKEND_MODE=host`

模式约束：

- `AP_BACKEND_MODE` 仅接受 `container` 或 `host`
- `TERM_BACKEND_MODE` 仅接受 `host` 或 `container`
- `PAN_BACKEND_MODE` 仅接受 `host` 或 `container`

## 4. 网关路由矩阵

- `/admin/api`、`/api/auth`、`/api/app`、`/oauth2`、`/openid` -> `app-server-backend:8080`
- `/admin` -> `app-server-frontend:80`
- `/ap/api/*` -> `AP_BACKEND_MODE=container` 时转发到 `agent-platform:8080/api/*`；`AP_BACKEND_MODE=host` 时转发到 `host.docker.internal:11949/api/*`
- `/ap/ws` -> `AP_BACKEND_MODE=container` 时转发到 `agent-platform:8080/ws`；`AP_BACKEND_MODE=host` 时转发到 `host.docker.internal:11949/ws`
- `/api/voice/*` -> `voice-server:11953`
- `/api/mcp/mock` -> `mcp-server-mock:8080/mcp`
- `/api/mcp/email` -> `mcp-server-email:8080/mcp`
- `/api/mcp/bash` -> `mcp-server-bash:8080/mcp`
- `/appterm` -> `TERM_BACKEND_MODE=host` 时 `host.docker.internal:11947`；`TERM_BACKEND_MODE=container` 时 `term-webclient-frontend:80`
- `/term` -> `TERM_BACKEND_MODE=host` 时 `host.docker.internal:11947`；`TERM_BACKEND_MODE=container` 时 `term-webclient-frontend:80`
- `/ma/*` -> `host.docker.internal:11955`，转发前去掉 `/ma` 前缀
- `/pan`、`/pan/api/*`、`/pan/assets/*` -> `PAN_BACKEND_MODE=host` 时 `host.docker.internal:11946`；`PAN_BACKEND_MODE=container` 时 `pan-webclient:8080`
- `/apppan`、`/apppan/api/*`、`/apppan/assets/*` -> `PAN_BACKEND_MODE=host` 时 `host.docker.internal:11946`；`PAN_BACKEND_MODE=container` 时 `pan-webclient:8080`

## 5. 版本化发布与打包

本项目支持生成单架构离线 release bundle，bundle 只包含 `zenmind-gateway` 自身，不包含上游业务服务。

版本单一来源：

- `VERSION`

正式打包入口：

```bash
make release
```

常见用法：

```bash
make release VERSION=v1.0.0 ARCH=amd64
make release VERSION=v1.0.0 ARCH=arm64
```

产物固定输出到：

- `dist/release/zenmind-gateway-vX.Y.Z-linux-amd64.tar.gz`
- `dist/release/zenmind-gateway-vX.Y.Z-linux-arm64.tar.gz`

bundle 解压后的核心文件：

- `.env.example`
- `compose.release.yml`
- `start.sh`
- `stop.sh`
- `README.txt`
- `images/zenmind-gateway.tar`

### release bundle 部署步骤

```bash
tar -xzf zenmind-gateway-v1.0.0-linux-amd64.tar.gz
cd zenmind-gateway
cp .env.example .env
./start.sh
```

release `start.sh` 会自动：

- 校验 `.env`
- 按需加载 `images/zenmind-gateway.tar`
- 确保 `zenmind-network` 存在
- 用 `compose.release.yml` 启动容器

### 升级与回滚

- 升级：解压新版本 bundle，复用旧目录的 `.env`，执行新目录下的 `./start.sh`
- 回滚：停止当前版本后，切回上一版 bundle 目录执行上一版 `./start.sh`

详细说明见 [docs/versioned-release-bundle.md](/Users/linlay/Project/zenmind/zenmind-gateway/docs/versioned-release-bundle.md)。

## 6. 运维

查看日志：

```bash
cd ~/Project/zenmind-gateway
docker compose logs -f gateway
```

常见排查：

- `502 Bad Gateway`
- 检查目标服务容器是否启动
- 检查目标容器是否接入 `zenmind-network`
- 检查目标服务别名是否与网关配置一致
- 若访问 `/api/voice/*`，检查 `voice-server` 是否可在 `zenmind-network` 中解析
- 若 `PAN_BACKEND_MODE=host`，检查 pan-webclient 是否已监听 `127.0.0.1:11946`
- 若访问 `/ma/*`，检查宿主机服务是否已监听 `127.0.0.1:11955`

快速自检命令：

```bash
docker network inspect zenmind-network
docker compose config
curl -i http://127.0.0.1:11945/healthz
curl -i http://127.0.0.1:11945/ma/
```
