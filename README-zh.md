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


加载环境变量

```bash
source .env
```

### 2. 构建

使用国内镜像构建：

```bash
docker build \
  --build-arg BASE_IMAGE=$DOCKER_BASE_IMAGE \
  --build-arg NPM_REGISTRY=$NPM_REGISTRY \
  --build-arg PIP_INDEX_URL=$PIP_INDEX_URL \
  --build-arg PREINSTALL_AGENTS=$PREINSTALL_AGENTS \
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

## Docker 参数详解

> 不熟悉 Docker 也没关系。每个参数先用 🏠 大白话打比方，再用 🔧 讲技术细节。这样做是为了让所有人都能看懂。

### 📌 先搞懂两个关键标记

| 标记 | 意思 | 生活类比 |
|------|------|---------|
| 📖 只读 | 容器**只能看，不能改** | 学校公告栏的通知——你只能读，撕不掉也改不了 |
| ✏️ 读写 | 容器**既能看也能改** | 你自己的笔记本——能读上面的字，也能往上写新内容 |

所有卷挂载表格都会标注 📖（只看）或 ✏️（能看能改），请留意。

---

### 一、做镜像：`docker build`（≈ 盖房子）

镜像是一个**可复用的模板**，相当于装好操作系统和必要软件的"毛坯房"。一次构建，多次启动。

```bash
docker build \
  --build-arg BASE_IMAGE=$DOCKER_BASE_IMAGE \
  --build-arg PREINSTALL_AGENTS=$PREINSTALL_AGENTS \
  --build-arg NPM_REGISTRY=$NPM_REGISTRY \
  --build-arg PIP_INDEX_URL=$PIP_INDEX_URL \
  --build-arg OPENCODE_INSTALL_URL=$OPENCODE_INSTALL_URL \
  -t agent-sandbox:latest .
```

| 参数 | 🏠 大白话 | 🔧 技术细节 |
|------|-----------|------------|
| `--build-arg BASE_IMAGE=...` | 选毛坯房款式——房子要用什么材料建（Ubuntu 24.04） | Dockerfile:1 `FROM $BASE_IMAGE`，默认 `ubuntu:24.04`，可换镜像源加速 |
| `--build-arg PREINSTALL_AGENTS=...` | 装修时就把家电搬进去，入住直接能用 | Dockerfile:25-35 `npm install -g` 将 agent 装到镜像层 |
| `--build-arg NPM_REGISTRY=...` | 指定快递站（npm 软件从哪下载） | Dockerfile:23 `npm config set registry` |
| `--build-arg PIP_INDEX_URL=...` | 指定另一个快递站（Python 包从哪下载） | Dockerfile:24 `pip config set global.index-url` |
| `--build-arg OPENCODE_INSTALL_URL=...` | 备用的快递站（npm 装不上时换种方式） | Dockerfile:27 备用 curl 安装 |

---

### 二、跑容器：`docker run`（≈ 住进去）

#### 2.1 生命周期——房子怎么开、怎么关

**`--rm`**
- 🏠 退房时自动拆房，不残留垃圾。但你的私人物品（存在 `DATA_DIR` 里的数据）放在独立的保险柜里，房子拆了也不丢。
- 🔧 容器主进程退出后自动 `docker rm` 删除容器文件系统层，volume 挂载的数据不受影响。

**`-it`**
- 🏠 `-i` = 门开着，你能朝里面喊话；`-t` = 窗户透明，你能看到里面在干啥。两个都要有，才能和 agent 对话。
- 🔧 `--interactive` 保持 stdin 打开；`--tty` 分配伪终端。二者缺一则无法交互。

**`--init`**
- 🏠 房子里请了个管家叫 tini。没有管家时你喊"停下"（Ctrl+C），信号传不到干活的人。管家负责正确传话，并打扫干完活后留下的垃圾（僵尸进程）。
- 🔧 tini 作为 PID 1 运行，负责转发 SIGTERM/SIGINT 给子进程，并在子进程退出后执行 `wait()` 回收，防止僵尸进程残留。

---

#### 2.2 安全防护——防贼防盗

**`--cap-drop ALL`**
- 🏠 把家里所有工具箱的钥匙都扔掉。房子里的人即使有"管理员"身份，也拧不了螺丝、接不了网线、换不了门锁，只能在划定的客厅里活动。
- 🔧 Linux capabilities 是系统赋予进程的特权（约 40 种，如 `CAP_NET_ADMIN` 网络配置、`CAP_SYS_ADMIN` 系统管理、`CAP_SYS_MODULE` 加载内核模块等）。`--cap-drop ALL` 丢弃全部 capability，即使以 root 运行也无法执行任何特权操作。

**`--security-opt no-new-privileges:true`**
- 🏠 禁止攀爬翻墙——小人不能踩在别人肩膀上跳出去。即使房子里有 `sudo` 这个梯子，也用不了。
- 🔧 阻止容器内进程通过执行 suid 二进制文件或调用 `setuid()`/`setgid()` 系统调用来提升权限。从进程创建到生命周期结束，权限只降不升。

---

#### 2.3 临时存储——便签纸和书桌

这两个参数给容器提供**可写的临时空间**。容器根文件系统可能是只读的，临时文件需要地方存放。

**`--tmpfs /var/tmp:size=64M`**
- 🏠 给你一沓 64MB 的便签纸，写满就扔。房子拆了便签纸自动销毁，不占磁盘空间、不残留。
- 🔧 在 `/var/tmp` 挂载 64MB 内存文件系统（tmpfs），数据写入内存而非磁盘，容器停止后自动释放。

**`--tmpfs /home/agent:size=512M,uid=1001,gid=1001`**
- 🏠 agent 的 512MB 大书桌，办公用的。`uid=1001` 是 agent 的工牌号，确保这张桌子确实是 agent 本人的。
- 🔧 agent 家目录（entrypoint.sh:5 `export HOME="/home/agent"`），512MB tmpfs，属主为 UID/GID 1001（与 Dockerfile:16 `useradd -m -s /bin/bash agent` 创建的 agent 用户一致）。用于存放 shell 历史、会话缓存等运行时状态。

---

#### 2.4 数据卷（Volume）——四个储物柜

数据卷是将宿主机上的目录**映射**到容器内部的技术。容器里的程序读写这个目录，实际上就是在读写宿主机上的文件。

> 回忆一下上面的 📖（只看）和 ✏️（能看能改）标记。

| 参数 | 🏠 类比 | 🔧 行为 | 权限 |
|------|---------|---------|------|
| `-v $WORKSPACE_DIR` | 院子通向你的车库 — agent 直接进出你的代码目录 | bind mount，宿主机路径挂载到容器内**同名绝对路径** | ✏️ 能看能改 |
| `-v $CONFIG_DIR:/agent-config:ro` | 一本只允许看的说明书 — agent 读规则，但改不了规则 | entrypoint.sh 根据不同 agent 分支执行 `cp` 或 `ln -sfT` 读配置 | 📖 只看 |
| `-v $DATA_DIR:/agent-data` | 私人保险柜 — 存对话历史、登录状态，拆房也不丢 | entrypoint.sh `ln -sfT /agent-data` 到 agent 的数据目录（如 `~/.local/share/opencode`） | ✏️ 能看能改 |
| `-v $PWD/entrypoint.sh:/entrypoint.sh:ro` | 替换房屋使用手册 — 改了手册不用重建房子 | 运行时 mount 覆盖镜像内 `/entrypoint.sh`，下次启动立即生效 | 📖 只看 |

---

#### 2.5 端口——对外窗口

**`-p 4096:4096`**
- 🏠 墙上开了个窗，号码是 4096。Web 模式下你可以在浏览器输入 `http://localhost:4096` 访问 agent 的网页界面。
- 🔧 宿主机端口 4096 映射到容器端口 4096，Web 模式的 agent 监听 `0.0.0.0:4096`。

---

#### 2.6 环境变量——贴便签

环境变量是用 `-e` 传给容器的键值对，相当于在门上贴便签，agent 一进门就能看到。

**`-e AGENT=$AGENT`**
- 🏠 门上贴便签告诉 agent："你是 opencode"（或 claude、copilot 等）。agent 看到后按规则行事。
- 🔧 entrypoint.sh:4 `AGENT="${AGENT:-opencode}"`，第 11 行 `case "$AGENT" in` 根据值选择初始化逻辑。

**`-e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY`**
- 🏠 门上贴便签写 API Key，agent 看到后拿去调用 AI 服务。
- 🔧 agent 进程运行时读取环境变量，用于 API 鉴权。同理还有 `OPENAI_API_KEY`、`GOOGLE_GENERATIVE_AI_API_KEY`。

---

### 四、速查表

| 参数 | 一句话 | 类比 | 权限 |
|------|--------|------|------|
| `--rm` | 退房自动拆 | — | — |
| `-it` | 开门+开窗 | — | — |
| `--init` | 管家 tini | — | — |
| `--cap-drop ALL` | 扔掉所有钥匙 | — | — |
| `--security-opt no-new-privileges` | 禁止攀爬翻墙 | — | — |
| `--tmpfs /var/tmp:size=64M` | 64MB 便签纸 | — | — |
| `--tmpfs /home/agent:size=512M` | 512MB 书桌 | — | — |
| `-v $WORKSPACE_DIR` | 代码目录 | 院子通车库 | ✏️ |
| `-v $CONFIG_DIR:/agent-config:ro` | 配置目录 | 只许看的说明书 | 📖 |
| `-v $DATA_DIR:/agent-data` | 数据目录 | 私人保险柜 | ✏️ |
| `-v entrypoint.sh:ro` | 启动脚本 | 使用手册替换 | 📖 |
| `-p 4096:4096` | Web 窗口 | 墙上开窗 | — |
| `-e AGENT` | 告诉 agent 你是谁 | 门贴便签 | — |
| `-e API_KEY` | 告诉 agent API Key | 门贴便签 | — |

## 常见问题

### Permission denied

容器以 UID 1001 (agent) 运行，宿主机目录需要 `o+w` 权限：

```bash
chmod 0777 ./sandbox/data
```

## 依赖

- Docker Engine 24+
- 国内网络需要配置镜像源（已在 `.env.example` 中预设）

## 作者

OpenCode (DeepSeek V4 Flash) + shuiruge@hotmail.com

## License

MIT

