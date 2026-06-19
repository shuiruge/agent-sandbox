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
├── run.sh                   ← Run script template
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

### 2. Build

```bash
docker build \
  --build-arg BASE_IMAGE=$DOCKER_BASE_IMAGE \
  --build-arg PREINSTALL_AGENTS=$PREINSTALL_AGENT \
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

See `run.sh` for a template.

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

## Custom Paths

Paths in `.env` can point to any absolute path on the host:

```bash
WORKSPACE_DIR=/home/user/projects/my-app
CONFIG_DIR=/home/user/.config/opencode
DATA_DIR=/mnt/ssd/opencode-data
```

> **Note**: The container runs as a non-root user (UID 1001), so `DATA_DIR` needs `0777` permissions
> to be writable. `./run.sh` handles this automatically; if configuring paths manually, run `chmod 0777 $DATA_DIR`.

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

## FAQ

### Permission denied

The container runs as UID 1001 (agent). Host directories need `o+w` permission:

```bash
chmod 0777 ./sandbox/data
```

## Dependencies

- Docker Engine 24+
