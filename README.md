# Agent Sandbox

Run coding agents (opencode / Claude Code / Copilot / aider, etc.) inside a Docker sandbox,
restricting them to only access the specified working directory, unable to touch other files on the host.

## Design Principles

- **Generic**: Sandbox decoupled from specific agents — just change `AGENT=` in `.env`
- **Secure**: Container root filesystem read-only, all Linux capabilities dropped
- **Persistent**: Agent data and auth state persisted in `DATA_DIR`, not lost when container is destroyed
- **Zero rebuild**: `entrypoint.sh` injected via mount — modify it without `docker compose build`

## Directory Structure

```
opencode-sandbox/
├── .env                     ← All configuration (agent, paths, API keys)
├── .env.example             ← Distribution template
├── Dockerfile               ← Common runtime + pre-installed agents
├── entrypoint.sh            ← Smart routing, injected via mount
├── README-zh.md             ← Chinese README
└── README.md                ← English README (this file)
```

## Quick Start

### 1. Configuration

```bash
cp .env.example .env
```

Edit `.env`. Field reference:

| Variable | Description |
|----------|-------------|
| `AGENT` | Agent to run (opencode, claude, copilot, aider) |
| `PREINSTALL_AGENTS` | Agents to pre-install during image build |
| `WORKSPACE_DIR` | Working directory mounted into container |
| `CONFIG_DIR` | Agent configuration directory (mounted read-only) |
| `DATA_DIR` | Persistent agent data directory |
| `DOCKER_BASE_IMAGE` | Base Docker image |
| `NPM_REGISTRY` | npm registry |
| `PIP_INDEX_URL` | PyPI index URL |
| `OPENCODE_INSTALL_URL` | opencode install script URL |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `OPENAI_API_KEY` | OpenAI API key |
| `GOOGLE_GENERATIVE_AI_API_KEY` | Google Generative AI API key |
| `GITHUB_TOKEN` | GitHub token |

Load environment

```bash
source .env
```

### 2. Build

```bash
docker build \
  --build-arg BASE_IMAGE=$DOCKER_BASE_IMAGE \
  --build-arg PREINSTALL_AGENTS=$PREINSTALL_AGENTS \
  -t agent-sandbox:latest .
```

## Running

entrypoint only handles environment setup (config/data directory initialization); the startup command is passed by you.

Step 1: Source environment variables
```bash
source .env
```

Step 2: Ensure directories exist
```bash
mkdir -p $WORKSPACE_DIR $CONFIG_DIR $DATA_DIR
```

Step 3: Ensure DATA_DIR permissions are correct
```bash
chmod 0777 $DATA_DIR 2>/dev/null || true
```

Step 4: Run Docker

TUI mode:
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

Web mode:
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

## Switching Agents

Change two lines in `.env`:

```bash
AGENT=claude
CONFIG_DIR=./sandbox/claude-config
DATA_DIR=./sandbox/claude-data
```

Make sure the corresponding `case` branch exists in `entrypoint.sh` (opencode / claude / copilot / aider are built-in),
and the agent is included in `PREINSTALL_AGENTS` (otherwise a rebuild is needed).

## When to Rebuild

**Changes that do NOT require a rebuild (all in `.env`, take effect immediately):**

| Variable | Reason |
|----------|--------|
| `WORKSPACE_DIR` / `CONFIG_DIR` / `DATA_DIR` | volume mount, resolved at runtime |
| `AGENT` | environment variable, read by entrypoint.sh at runtime |
| `ANTHROPIC_API_KEY` etc. | API keys, used at runtime |
| `DOCKER_BASE_IMAGE` | only a tag change requires a re-pull; no rebuild needed if the tag stays the same |

**The only scenario that requires a rebuild:**

```
Adding a new agent to PREINSTALL_AGENTS that wasn't installed before
```

## Adding a New Agent

1. Add a branch to the `case` statement in `entrypoint.sh` (mounted as a volume, no rebuild needed)
2. Add the new agent name to `PREINSTALL_AGENTS` in `.env`
3. Create the config and data directories under `sandbox/`, then update `.env`

## Security Hardening

| Measure | Effect |
|---------|--------|
| `read_only: true` | Container root filesystem read-only (optional — opencode TUI is incompatible with this mode, currently disabled) |
| `cap_drop: ALL` | All Linux capabilities dropped |
| Only mount `WORKSPACE_DIR` / `CONFIG_DIR` / `DATA_DIR` | Cannot access other host files |
| Docker socket not mounted | Cannot escape container |

## Docker Parameters Explained

> Not familiar with Docker? No problem. Each parameter is first explained with a 🏠 plain-language analogy, then with 🔧 technical details. This way everyone can understand.

### 📌 Two Key Symbols

| Symbol | Meaning | Everyday Analogy |
|--------|---------|-----------------|
| 📖 Read-only | Container can **see but not modify** | A notice on the school bulletin board — you can read it, but can't tear it down or change it |
| ✏️ Read-write | Container can **see and modify** | Your own notebook — you can read what's written and write new things in it |

All volume mount tables use 📖 (view only) or ✏️ (view and edit). Keep an eye out.

---

### 一、Building the Image: `docker build` (≈ Building a House)

An image is a **reusable template** — like a furnished house with the OS and necessary software installed. Build once, run many times.

```bash
docker build \
  --build-arg BASE_IMAGE=$DOCKER_BASE_IMAGE \
  --build-arg PREINSTALL_AGENTS=$PREINSTALL_AGENTS \
  --build-arg NPM_REGISTRY=$NPM_REGISTRY \
  --build-arg PIP_INDEX_URL=$PIP_INDEX_URL \
  --build-arg OPENCODE_INSTALL_URL=$OPENCODE_INSTALL_URL \
  -t agent-sandbox:latest .
```

| Parameter | 🏠 Plain Language | 🔧 Technical Details |
|-----------|-------------------|---------------------|
| `--build-arg BASE_IMAGE=...` | Choose the house model — what materials to build with (Ubuntu 24.04) | Dockerfile:1 `FROM $BASE_IMAGE`, default `ubuntu:24.04`, swappable for mirror acceleration |
| `--build-arg PREINSTALL_AGENTS=...` | Install appliances during construction, ready to use on move-in | Dockerfile:25-35 `npm install -g` installs agents into the image layer |
| `--build-arg NPM_REGISTRY=...` | Set the courier station (where npm packages download from) | Dockerfile:23 `npm config set registry` |
| `--build-arg PIP_INDEX_URL=...` | Set another courier station (where Python packages download from) | Dockerfile:24 `pip config set global.index-url` |
| `--build-arg OPENCODE_INSTALL_URL=...` | Backup courier station (fallback if npm install fails) | Dockerfile:27 fallback curl installation |

---

### 二、Running the Container: `docker run` (≈ Moving In)

#### 2.1 Lifecycle — How the House Opens and Closes

**`--rm`**
- 🏠 Auto-demolish on checkout — no garbage left behind. Your belongings (data in `DATA_DIR`) are kept in a separate safe that survives demolition.
- 🔧 Container filesystem layer is automatically `docker rm`'d when the main process exits. Volume-mounted data is unaffected.

**`-it`**
- 🏠 `-i` = door open so you can shout in; `-t` = window clear so you can see inside. Both needed to interact with the agent.
- 🔧 `--interactive` keeps stdin open; `--tty` allocates a pseudo-terminal. Neither works alone.

**`--init`**
- 🏠 A butler named tini lives in the house. Without a butler, when you shout "stop" (Ctrl+C), the signal may not reach the person working. The butler relays your message correctly and cleans up leftover mess (zombie processes).
- 🔧 tini runs as PID 1, responsible for forwarding SIGTERM/SIGINT to child processes and calling `wait()` after they exit, preventing zombie process accumulation.

---

#### 2.2 Security — Locks and Fences

**`--cap-drop ALL`**
- 🏠 Throw away all the toolbox keys. Even if someone inside has "admin" status, they can't turn a screw, connect a network cable, or change a lock — they can only move around the designated living room.
- 🔧 Linux capabilities are fine-grained system privileges (~40 types, e.g. `CAP_NET_ADMIN` for network config, `CAP_SYS_ADMIN` for system management, `CAP_SYS_MODULE` for loading kernel modules). `--cap-drop ALL` removes all capabilities — even root cannot perform privileged operations.

**`--security-opt no-new-privileges:true`**
- 🏠 No climbing over the wall — a small person can't stand on someone else's shoulders to jump out. Even if `sudo` (a ladder) exists in the house, it can't be used.
- 🔧 Prevents container processes from gaining privileges via suid binaries or `setuid()`/`setgid()` syscalls. Once set, privileges can only decrease, never increase.

---

#### 2.3 Temporary Storage — Sticky Notes and a Desk

These two parameters provide **writable temporary space** for the container. The container root filesystem may be read-only, so temporary files need a place to go.

**`--tmpfs /var/tmp:size=64M`**
- 🏠 A pad of 64MB sticky notes — write and discard. When the house is demolished, the notes auto-destruct — no disk usage, no residue.
- 🔧 Mounts a 64MB in-memory filesystem (tmpfs) at `/var/tmp`. Data lives in RAM, not on disk, and is freed when the container stops.

**`--tmpfs /home/agent:size=512M,uid=1001,gid=1001`**
- 🏠 Agent's 512MB desk for work. `uid=1001` is the agent's employee badge number, ensuring this desk belongs to the agent.
- 🔧 Agent home directory (entrypoint.sh:5 `export HOME="/home/agent"`), 512MB tmpfs owned by UID/GID 1001 (matching Dockerfile:16 `useradd -m -s /bin/bash agent`). Used for shell history, session cache, and other runtime state.

---

#### 2.4 Volumes — Four Storage Cabinets

Volumes **map** host directories into the container. When a program in the container reads or writes these directories, it's actually reading or writing files on the host.

> Recall the 📖 (view only) and ✏️ (view and edit) symbols from earlier.

| Parameter | 🏠 Analogy | 🔧 Behavior | Permission |
|-----------|-----------|-------------|------------|
| `-v $WORKSPACE_DIR` | Yard connected to your garage — agent comes and goes in your code directory | bind mount, host path mounted to the **same absolute path** inside container | ✏️ read-write |
| `-v $CONFIG_DIR:/agent-config:ro` | A read-only instruction manual — agent reads the rules but can't change them | entrypoint.sh runs `cp` or `ln -sfT` per agent branch to read config | 📖 read-only |
| `-v $DATA_DIR:/agent-data` | Personal safe — stores chat history, login state; survives house demolition | entrypoint.sh `ln -sfT /agent-data` to agent's data directory (e.g. `~/.local/share/opencode`) | ✏️ read-write |
| `-v $PWD/entrypoint.sh:/entrypoint.sh:ro` | Replace the house manual — change the manual without rebuilding the house | Runtime mount overrides the image's `/entrypoint.sh`, takes effect on next start | 📖 read-only |

---

#### 2.5 Port — An Outside Window

**`-p 4096:4096`**
- 🏠 A window in the wall, numbered 4096. In web mode, you can type `http://localhost:4096` in your browser to access the agent's web interface.
- 🔧 Host port 4096 maps to container port 4096. The web-mode agent listens on `0.0.0.0:4096`.

---

#### 2.6 Environment Variables — Sticky Notes on the Door

Environment variables are key-value pairs passed to the container with `-e`. Think of them as sticky notes on the door — the agent reads them upon entry.

**`-e AGENT=$AGENT`**
- 🏠 A sticky note on the door tells the agent: "You are opencode" (or claude, copilot, etc.). The agent follows the instructions accordingly.
- 🔧 entrypoint.sh:4 `AGENT="${AGENT:-opencode}"`, line 11 `case "$AGENT" in` selects initialization logic.

**`-e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY`**
- 🏠 A sticky note with the API key. The agent reads it and uses it to call the AI service.
- 🔧 The agent process reads environment variables at runtime for API authentication. Same applies to `OPENAI_API_KEY` and `GOOGLE_GENERATIVE_AI_API_KEY`.

---

### 四、Quick Reference

| Parameter | One-liner | Analogy | Perm |
|-----------|-----------|---------|------|
| `--rm` | Auto-demolish on exit | — | — |
| `-it` | Open door + open window | — | — |
| `--init` | Butler tini | — | — |
| `--cap-drop ALL` | Throw away all keys | — | — |
| `--security-opt no-new-privileges` | No climbing over walls | — | — |
| `--tmpfs /var/tmp:size=64M` | 64MB sticky notes | — | — |
| `--tmpfs /home/agent:size=512M` | 512MB desk | — | — |
| `-v $WORKSPACE_DIR` | Code directory | Yard to garage | ✏️ |
| `-v $CONFIG_DIR:/agent-config:ro` | Config directory | Read-only manual | 📖 |
| `-v $DATA_DIR:/agent-data` | Data directory | Personal safe | ✏️ |
| `-v entrypoint.sh:ro` | Startup script | Manual replacement | 📖 |
| `-p 4096:4096` | Web window | Window in wall | — |
| `-e AGENT` | Tell agent its role | Sticky note | — |
| `-e API_KEY` | Tell agent the API key | Sticky note | — |

## FAQ

### Permission denied

The container runs as UID 1001 (agent). Host directories need `o+w` permission:

```bash
chmod 0777 ./sandbox/data
```

## Dependencies

- Docker Engine 24+

## Author

OpenCode (DeepSeek V4 Flash) + shuiruge@hotmail.com

## License

MIT

