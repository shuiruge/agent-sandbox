ARG BASE_IMAGE=ubuntu:24.04
FROM $BASE_IMAGE

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git jq unzip \
    openssh-client sudo \
    nodejs npm python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash agent

ARG PREINSTALL_AGENTS=""
ARG NPM_REGISTRY
ARG PIP_INDEX_URL
ARG OPENCODE_INSTALL_URL

RUN npm config set registry "$NPM_REGISTRY" && \
    pip config set global.index-url "$PIP_INDEX_URL" && \
    if echo "$PREINSTALL_AGENTS" | grep -q "opencode"; then \
        npm install -g opencode-ai || \
        curl -fsSL --connect-timeout 10 --retry 2 "$OPENCODE_INSTALL_URL" | bash || \
        echo "Warning: opencode install failed, skipping"; \
    fi && \
    if echo "$PREINSTALL_AGENTS" | grep -q "claude"; then \
        npm install -g @anthropic-ai/claude-code || true; \
    fi && \
    if echo "$PREINSTALL_AGENTS" | grep -q "copilot"; then \
        npm install -g @githubnext/github-copilot-cli || true; \
    fi

WORKDIR /workspace

ENTRYPOINT ["/entrypoint.sh"]
