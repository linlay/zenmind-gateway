# 版本化离线打包方案

## 1. 目标与边界

这套方案把 `zenmind-gateway` 产出为一个带明确版本号、单目标架构、可离线部署的 release bundle，便于上传到 GitHub Release、自建制品库或内网服务器后直接解压运行。

它解决的是“如何交付网关运行版本”，不解决“如何同时分发全部上游服务”：

- 交付物是最终 bundle，而不是源码压缩包。
- bundle 内包含预构建网关镜像和最小部署资产，部署端不需要源码构建环境。
- 每次构建只产出一个目标架构 bundle，不做多架构合包。
- bundle 只包含 `zenmind-gateway`，不包含 app-server、agent-platform、voice-server、mcp-*、term-webclient、pan-webclient。

当前仓库的版本单一来源是根目录 `VERSION` 文件，正式版本格式固定为 `vX.Y.Z`。以版本 `v0.1.0` 为例，最终产物命名规则为：

- `zenmind-gateway-v0.1.0-linux-arm64.tar.gz`
- `zenmind-gateway-v0.1.0-linux-amd64.tar.gz`

## 2. 方案总览

这套方案拆成四层：

1. 版本层：根目录 `VERSION`
2. 构建层：`make release` / `scripts/release.sh`
3. 组装层：`scripts/release-assets/`
4. 交付层：`dist/release/`

网关项目采用“单镜像 bundle”模式：

- release 镜像基于 `nginx:1.27-alpine`
- 镜像内置 `nginx.conf` 和全部 `nginx-backends/*.conf`
- 容器启动时根据 `AP_BACKEND_MODE`、`TERM_BACKEND_MODE`、`PAN_BACKEND_MODE` 选择对应后端片段

这样部署端不再依赖源码目录 bind mount，bundle 解压后即可运行。

## 3. 打包入口与输入

一步式正式发布入口：

```bash
make release
```

也可以直接执行：

```bash
bash scripts/release.sh
```

常见用法：

```bash
make release VERSION=v1.0.0 ARCH=arm64
make release VERSION=v1.0.0 ARCH=amd64
```

主要输入包括：

- 版本号：`VERSION` 文件或环境变量 `VERSION`
- 目标架构：环境变量 `ARCH` 或当前机器架构
- release 镜像定义：`docker/Dockerfile.release`
- 启动选择脚本：`docker/entrypoint-release.sh`
- release 模板资产：`scripts/release-assets/compose.release.yml`
- release 模板资产：`scripts/release-assets/start.sh`
- release 模板资产：`scripts/release-assets/stop.sh`
- release 模板资产：`scripts/release-assets/README.txt`
- 配置模板：`.env.example`

脚本会强校验版本格式，只接受 `vX.Y.Z`。

## 4. 构建与组装过程

### 4.1 镜像构建

打包脚本使用 `docker buildx build` 构建一个 release 镜像：

- `zenmind-gateway:<VERSION>`

并直接导出为：

- `images/zenmind-gateway.tar`

### 4.2 bundle 组装

脚本会在临时目录组装标准离线目录 `zenmind-gateway/`，包含：

- `images/zenmind-gateway.tar`
- `compose.release.yml`
- `start.sh`
- `stop.sh`
- `README.txt`
- `.env.example`

同时会把 `.env.example` 里的 `GATEWAY_VERSION` 写成当前构建版本，保证部署端复制后默认镜像标签和 bundle 中镜像一致。

### 4.3 最终输出

最终交付物固定输出到：

- `dist/release/zenmind-gateway-vX.Y.Z-linux-arm64.tar.gz`
- `dist/release/zenmind-gateway-vX.Y.Z-linux-amd64.tar.gz`

## 5. 部署端如何消费 bundle

标准部署步骤：

```bash
tar -xzf zenmind-gateway-v1.0.0-linux-amd64.tar.gz
cd zenmind-gateway
cp .env.example .env
./start.sh
```

`start.sh` 会按顺序完成这些工作：

1. 校验 `.env` 是否存在
2. 校验 Docker Engine 和 Docker Compose v2
3. 读取 `GATEWAY_VERSION`
4. 如果本机没有对应镜像，则从 `images/zenmind-gateway.tar` 自动 `docker load`
5. 确保 `zenmind-network` 存在；不存在则创建
6. 使用 `compose.release.yml` 启动网关容器

`stop.sh` 会用同一套 compose 配置执行：

```bash
docker compose -f compose.release.yml down --remove-orphans
```

## 6. 配置与运行约定

部署端重点配置项：

- `GATEWAY_VERSION`：镜像标签，默认与 bundle 版本一致
- `GATEWAY_PORT`：宿主机暴露端口，默认 `11945`
- `AP_BACKEND_MODE`：`container` 或 `host`
- `TERM_BACKEND_MODE`：`host` 或 `container`
- `PAN_BACKEND_MODE`：`host` 或 `container`

release compose 使用共享网络 `zenmind-network`：

- bundle 负责确保该网络存在
- bundle 不负责启动该网络中的其他服务
- host 模式继续通过 `host.docker.internal` 访问宿主机服务

## 7. 升级、回滚与交付建议

升级时，建议下载新版本 bundle，解压到新目录后复用旧目录的 `.env`，再执行新的 `./start.sh`。

回滚时，停止当前版本后切回上一版 bundle 目录，再执行上一版的 `./start.sh` 即可。

推荐把 `dist/release/` 作为统一归档和上传入口，保持固定产物目录与固定命名，方便后续接自动化发布。

## 8. 关键文件索引

- `VERSION`
- `Makefile`
- `docker/Dockerfile.release`
- `docker/entrypoint-release.sh`
- `scripts/release.sh`
- `scripts/release-assets/compose.release.yml`
- `scripts/release-assets/start.sh`
- `scripts/release-assets/stop.sh`
- `scripts/release-assets/README.txt`
- `.env.example`
