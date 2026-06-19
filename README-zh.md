# Agent Sandbox

在 Docker 沙箱中运行 coding agent（opencode / Claude Code / Copilot / aider 等），
限制其只能访问指定的工作目录，无法触及宿主机其他文件。

## 设计原则

- **通用**：沙箱与具体 agent 解耦，切换只需改 `.env` 中的 `AGENT=`
- **安全**：容器根文件系统只读，丢弃所有 Linux 能力
- **持久**：agent 数据和认证状态持久化在 `DATA_DIR`，不随容器销毁
- **零重建**：`entrypoint.sh` 挂载注入，修改它无需 `docker compose build`

## 目录结构

```
opencode-sandbox/
├── .env                     ← 所有配置（agent、路径、镜像源、API key）
├── .env.example             ← 分发模板
├── Dockerfile               ← 公共运行环境 + 按需预装 agent
├── entrypoint.sh            ← 智能路由，挂载方式注入
├── run.sh                   ← 运行脚本模板
├── README.md                ← 英文 README
└── README-zh.md             ← 中文 README（本文件）
```

## 快速开始

### 1. 配置

```bash
cp .env.example .env
```

编辑 `.env`。字段说明：

| 变量 | 说明 |
|------|------|
| `AGENT` | 要运行的 agent（opencode, claude, copilot, aider） |
| `PREINSTALL_AGENTS` | 构建镜像时要预装的 agent |
| `WORKSPACE_DIR` | 挂载到容器内的工作目录 |
| `CONFIG_DIR` | agent 配置目录（只读挂载） |
| `DATA_DIR` | 持久化 agent 数据目录 |
| `DOCKER_BASE_IMAGE` | 基础 Docker 镜像 |
| `NPM_REGISTRY` | npm 源 |
| `PIP_INDEX_URL` | PyPI 源 |
| `OPENCODE_INSTALL_URL` | opencode 安装脚本地址 |
| `ANTHROPIC_API_KEY` | Anthropic API 密钥 |
| `OPENAI_API_KEY` | OpenAI API 密钥 |
| `GOOGLE_GENERATIVE_AI_API_KEY` | Google Generative AI API 密钥 |
| `GITHUB_TOKEN` | GitHub 令牌 |

### 2. 构建

使用国内镜像构建：

```bash
docker build \
  --build-arg BASE_IMAGE=$DOCKER_BASE_IMAGE \
  --build-arg NPM_REGISTRY=$NPM_REGISTRY \
  --build-arg PIP_INDEX_URL=$PIP_INDEX_URL \
  --build-arg PREINSTALL_AGENTS=$PREINSTALL_AGENT \
  -t agent-sandbox:latest .
```

## 运行方式

entrypoint 只负责环境准备（配置/数据目录初始化），启动命令由你传入。

第一步：设置环境变量
```bash
source .env
```

第二步：确保文件夹存在
```bash
mkdir -p $WORKSPACE_DIR $CONFIG_DIR $DATA_DIR
```

第三步：确保 DATA_DIR 权限正确
```bash
chmod 0777 $DATA_DIR 2>/dev/null || true
```

第四步：运行 Docker

TUI 模式：
```bash
docker run --rm -it --init \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --tmpfs /var/tmp:size=64M \
  --tmpfs /home/agent:size=512M,uid=1001,gid=1001 \
  -v $WORKSPACE_DIR \
  -v $CONFIG_DIR:/agent-config:ro \
  -v $DATA_DIR:/agent-data \
  -v $PWD/entrypoint.sh:/entrypoint.sh:ro \
  -p 4096:4096 \
  -e AGENT=$AGENT \
  -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  -e OPENAI_API_KEY=$OPENAI_API_KEY \
  -e GOOGLE_GENERATIVE_AI_API_KEY=$GOOGLE_GENERATIVE_AI_API_KEY \
  agent-sandbox:latest
```

Web 模式：
```bash
docker rm -f $(docker ps -q --filter publish=4096) 2>/dev/null
docker run --rm -it --init \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --tmpfs /var/tmp:size=64M \
  --tmpfs /home/agent:size=512M,uid=1001,gid=1001 \
  -v $WORKSPACE_DIR \
  -v $CONFIG_DIR:/agent-config:ro \
  -v $DATA_DIR:/agent-data \
  -v $PWD/entrypoint.sh:/entrypoint.sh:ro \
  -p 4096:4096 \
  -e AGENT=$AGENT \
  -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  -e OPENAI_API_KEY=$OPENAI_API_KEY \
  -e GOOGLE_GENERATIVE_AI_API_KEY=$GOOGLE_GENERATIVE_AI_API_KEY \
  agent-sandbox:latest web --hostname 0.0.0.0 --port 4096
```

模板参见 `run.sh`。

## 切换 Agent

改 `.env` 中的两行：

```bash
AGENT=claude
CONFIG_DIR=./sandbox/claude-config
DATA_DIR=./sandbox/claude-data
```

在 `entrypoint.sh` 中确保有对应的 `case` 分支（已内置 opencode / claude / copilot / aider），
用到的 agent 已包含在 `PREINSTALL_AGENTS` 中（否则需 rebuild 一次）。

## 切换镜像源

默认使用国内镜像（DaoCloud / npmmirror / 阿里云 PyPI）。
如需切换回官方源，在 `.env` 中注释国内行，取消官方行：

```bash
#DOCKER_BASE_IMAGE=docker.m.daocloud.io/library/ubuntu:24.04
DOCKER_BASE_IMAGE=ubuntu:24.04
#NPM_REGISTRY=https://registry.npmmirror.com
NPM_REGISTRY=https://registry.npmjs.org
#PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/
PIP_INDEX_URL=https://pypi.org/simple
```

切换 Docker 镜像源后需重新 pull 基础镜像：

```bash
docker pull ubuntu:24.04
docker build ...
```

## 什么时候需要重建镜像

**不需要 rebuild 的改动（全在 `.env`，改完即生效）：**

| 变量 | 原因 |
|------|------|
| `WORKSPACE_DIR` / `CONFIG_DIR` / `DATA_DIR` | volume mount，运行时解析 |
| `AGENT` | 环境变量，entrypoint.sh 运行时读取 |
| `ANTHROPIC_API_KEY` 等 | API key，运行时使用 |
| `DOCKER_BASE_IMAGE` | 改 tag 才需重新 pull，不改 tag 不涉及镜像层 |

**需要 rebuild 的唯一场景：**

```
在 PREINSTALL_AGENTS 中新增一个之前没装过的 agent
```

## 路径定制

`.env` 中的路径可指向任意宿主机绝对路径：

```bash
WORKSPACE_DIR=/home/user/projects/my-app
CONFIG_DIR=/home/user/.config/opencode
DATA_DIR=/mnt/ssd/opencode-data
```

> **注意**：容器以非 root 用户运行（UID 1001），因此 `DATA_DIR` 需要设为 `0777` 权限
> 才能写入。`./run.sh` 会自动处理，若手工配置路径请手动 `chmod 0777 $DATA_DIR`。

## 新增 Agent

1. `entrypoint.sh` 的 `case` 中加一个分支（挂载注入，无需 rebuild）
2. `.env` 中 `PREINSTALL_AGENTS` 加入新 agent 名
3. 在 `sandbox/` 下建好配置和数据目录，填写 `.env`

## 安全加固

| 手段 | 效果 |
|------|------|
| `read_only: true` | 容器根文件系统只读（可选，openocode TUI 无法兼容本模式，已禁用） |
| `cap_drop: ALL` | 丢弃所有 Linux 能力 |
| 仅挂载 `WORKSPACE_DIR` / `CONFIG_DIR` / `DATA_DIR` | 无法访问宿主机其他文件 |
| 不挂载 Docker socket | 无法逃逸 |

## 常见问题

### Permission denied

容器以 UID 1001 (agent) 运行，宿主机目录需要 `o+w` 权限：

```bash
chmod 0777 ./sandbox/data
```

## 依赖

- Docker Engine 24+
- 国内网络需要配置镜像源（已在 `.env.example` 中预设）
