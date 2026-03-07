# CLAUDE.md

## 1. 项目概览

`zenmind-gateway` 是统一入口网关，负责将本机 `127.0.0.1:11945` 的请求转发到各业务容器。  
除 `/term`、`/appterm` 外，所有路由优先走 Docker 外部网络 `zenmind-network` 的容器 DNS。

## 2. 技术栈

- Nginx `1.27-alpine`
- Docker Compose（单服务编排）
- Docker external network：`zenmind-network`
- 运行平台：Docker Desktop（用于 `host.docker.internal`）

## 3. 架构设计

- 网关容器：`zenmind-gateway`（监听容器 80，映射宿主机 `11945`）。
- 核心转发模式：
  - 容器网络转发（默认）：auth、agent-platform、mcp-*。
  - term 路由按模式切换：`TERM_BACKEND_MODE=host|container`。
- 各业务服务保留独立宿主机端口用于直连验证和故障排查，不影响网关入口。

## 4. 目录结构

- `docker-compose.yml`：网关容器定义与网络接入
- `nginx.conf`：路由与转发规则（系统行为核心）
- `nginx-backends/`：`/api/ap/`、`/appterm`、`/term` 上游模式片段（container/host）
- `.env.example`：网关环境变量契约（`GATEWAY_PORT`、`AP_BACKEND_MODE`、`TERM_BACKEND_MODE`）
- `README.md`：操作手册（启动、部署、运维）
- `CLAUDE.md`：系统事实文档（本文件）

## 5. 数据结构

本项目核心数据是“路由映射表”：

- `path`: 对外访问路径（如 `/api/ap/`）
- `upstream`: 上游服务地址（如 `http://agent-platform-runner:8080`）
- `mode`: `docker-network` 或 `host-forward`

当前关键映射：

- `/admin/api`、`/api/auth`、`/api/app`、`/oauth2`、`/openid` -> `app-server-backend:8080`
- `/admin` -> `app-server-frontend:80`
- `/api/ap/` -> `AP_BACKEND_MODE=container` 时 `agent-platform-runner:8080`；`AP_BACKEND_MODE=host` 时 `host.docker.internal:11949`
- `/api/mcp/mock` -> `mcp-server-mock:8080/mcp`
- `/api/mcp/email` -> `mcp-server-email:8080/mcp`
- `/api/mcp/bash` -> `mcp-server-bash:8080/mcp`
- `/appterm` -> `TERM_BACKEND_MODE=host` 时 `host.docker.internal:11947`；`TERM_BACKEND_MODE=container` 时 `term-webclient-frontend:80`
- `/term` -> `TERM_BACKEND_MODE=host` 时 `host.docker.internal:11947`；`TERM_BACKEND_MODE=container` 时 `term-webclient-backend:8080`

## 6. API 定义

网关对外接口（示例）：

- `GET /healthz`：网关健康检查
- `GET|POST /admin/*`：认证前后端入口
- `GET|POST /api/ap/*`：agent-platform 接口入口
- `POST /api/mcp/mock`
- `POST /api/mcp/email`
- `POST /api/mcp/bash`
- `GET|POST /term/*`、`/appterm/*`：终端 Web 路由入口

统一行为：

- 透传 `Host`、`X-Forwarded-*`
- 开启 WebSocket upgrade 头部传递
- 对长连接接口启用较长 `proxy_read_timeout`

## 7. 开发要点

- 配置优先级：`.env`（本地）覆盖 `.env.example` 默认值。
- 网关不维护业务密钥，密钥在各子项目自身配置中管理。
- 变更路由时遵循“路径稳定优先、上游可替换”原则，减少客户端改动。
- 新服务接入优先走 `zenmind-network` 容器别名，再补文档中的端口矩阵。
- `AP_BACKEND_MODE` 仅接受 `container` 或 `host`，默认 `container`。
- `TERM_BACKEND_MODE` 仅接受 `host` 或 `container`，默认 `host`。

## 8. 开发流程

1. 更新 `nginx.conf` 路由规则。
2. 执行 `docker compose config` 做静态校验。
3. 启动/重启网关：`docker compose up -d`。
4. 通过 `curl` 验证 `/healthz` 与关键业务路径。
5. 如涉及新服务，先确认服务容器已接入 `zenmind-network`。

## 9. 已知约束与注意事项

- 当 `AP_BACKEND_MODE=container` 且上游容器未接入 `zenmind-network` 时，`/api/ap/` 将返回 `502`。
- 当 `TERM_BACKEND_MODE=container` 且 term-webclient 容器别名不可达时，`/appterm` 或 `/term` 将返回 `502`。
- 网关容器仅作为本地开发/联调入口，不承载生产级负载均衡策略。
- `zenmind-network` 必须预先存在（`docker network create zenmind-network`）。
