# zenmind-gateway

## 1. 项目简介

`zenmind-gateway` 是本地统一入口网关，固定入口为 `127.0.0.1:11945`。  
除 `/term`、`/appterm` 外，其他业务路径优先走 Docker 网络 `zenmind-network` 转发到容器；各服务独立宿主机端口继续保留。

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

最后启动网关：

```bash
cd ~/Project/zenmind-gateway
./start.sh
```

### 路由验证

```bash
curl -i http://127.0.0.1:11945/healthz
curl -i http://127.0.0.1:11945/openid/.well-known/openid-configuration
curl -i -X POST http://127.0.0.1:11945/api/mcp/mock -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":"1","method":"tools/list"}'
```

## 3. 配置说明

- 网关配置文件：
  - 端口契约：`.env.example`（`GATEWAY_PORT=11945`）
  - 路由规则：`nginx.conf`
- 配置优先级：`.env` > `.env.example`
- 网关不保存业务密钥；业务密钥在各子项目独立维护
- `zenmind-network` 是统一容器网络契约，除 term 外所有网关转发依赖该网络
- 该网络由本项目首次 `docker compose up -d` 自动创建（固定名称：`zenmind-network`）

### 端口矩阵（宿主机）

- `11945`：gateway（统一入口）
- `11952`：zenmind-app-server backend
- `11950`：zenmind-app-server frontend
- `11949`：agent-platform-runner
- `11969`：mcp-server-mock
- `11967`：mcp-server-email
- `11963`：mcp-server-bash
- `11947`：term-webclient frontend（网关 `/term`、`/appterm` 转发目标）
- `11946`：term-webclient backend（由 term-webclient 自身使用）

### 网关路由矩阵

- `/admin/api`、`/api/auth`、`/api/app`、`/oauth2`、`/openid` -> `app-server-backend:8080`
- `/admin` -> `app-server-frontend:80`
- `/api/ap/` -> `agent-platform:8080`
- `/api/mcp/mock` -> `mcp-server-mock:8080/mcp`
- `/api/mcp/email` -> `mcp-server-email:8080/mcp`
- `/api/mcp/bash` -> `mcp-server-bash:8080/mcp`
- `/term`、`/appterm` -> `host.docker.internal:11947`

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
- 端口占用
  - `lsof -nP -iTCP:11945 -sTCP:LISTEN`
- 规则未生效
  - 执行 `docker compose down && docker compose up -d` 重新加载 `nginx.conf`

### 快速自检命令

```bash
docker network inspect zenmind-network
docker ps --format 'table {{.Names}}\t{{.Ports}}'
curl -i http://127.0.0.1:11945/healthz
```
