#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

if [ ! -f .env ]; then
    cp .env.example .env
    echo "============================================="
    echo "  Created .env from .env.example"
    echo "  Edit it with your settings, then re-run."
    echo "============================================="
    exit 1
fi

. ./.env

mkdir -p "${WORKSPACE_DIR:-./sandbox/workspace}" "${CONFIG_DIR:-./sandbox/config}" "${DATA_DIR:-./sandbox/data}"

chmod 0777 "${DATA_DIR:-./sandbox/data}" 2>/dev/null || true

# TUI:
docker run --rm -it --init \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --tmpfs /var/tmp:size=64M \
  --tmpfs /home/agent:size=512M,uid=1001,gid=1001 \
  -v "$WORKSPACE_DIR" \
  -v "$CONFIG_DIR:/agent-config:ro" \
  -v "$DATA_DIR:/agent-data" \
  -v "$PWD/entrypoint.sh:/entrypoint.sh:ro" \
  -p 4096:4096 \
  -e AGENT=$AGENT \
  -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  -e OPENAI_API_KEY=$OPENAI_API_KEY \
  -e GOOGLE_GENERATIVE_AI_API_KEY=$GOOGLE_GENERATIVE_AI_API_KEY \
  agent-sandbox:latest

# Web:
# docker rm -f $(docker ps -q --filter publish=4096) 2>/dev/null
# docker run --rm -it --init \
#   --cap-drop ALL \
#   --security-opt no-new-privileges:true \
#   --tmpfs /var/tmp:size=64M \
#   --tmpfs /home/agent:size=512M,uid=1001,gid=1001 \
#   -v "$WORKSPACE_DIR" \
#   -v "$CONFIG_DIR:/agent-config:ro" \
#   -v "$DATA_DIR:/agent-data" \
#   -v "$PWD/entrypoint.sh:/entrypoint.sh:ro" \
#   -p 4096:4096 \
#   -e AGENT=$AGENT \
#   -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
#   -e OPENAI_API_KEY=$OPENAI_API_KEY \
#   -e GOOGLE_GENERATIVE_AI_API_KEY=$GOOGLE_GENERATIVE_AI_API_KEY \
#   agent-sandbox:latest web --hostname 0.0.0.0 --port 4096

