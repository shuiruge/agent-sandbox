#!/bin/bash
set -e

# Phase 1: root initialization — fix bind-mounted volume permissions,
#           then drop privileges to agent for the rest
if [ "$(id -u)" = "0" ]; then
    HOST_UID="${HOST_UID:-1000}"

    userdel -r agent 2>/dev/null || true
    userdel -r ubuntu 2>/dev/null || true
    groupadd -f agent
    useradd -m -u "$HOST_UID" -g agent -s /bin/bash agent
    chown -R agent:agent /workspace /agent-data /home/agent
    exec sudo -E -u agent -H "$0" "$@"
fi

AGENT="${AGENT:-opencode}"
export HOME="/home/agent"

if [ ! -f "$HOME/.bashrc" ]; then
    cp -r /etc/skel/. "$HOME/" 2>/dev/null || true
fi

case "$AGENT" in
    opencode)
        mkdir -p "$HOME/.config/opencode" "$HOME/.local/share"
        cp -r /agent-config/. "$HOME/.config/opencode/" 2>/dev/null || true
        rm -rf "$HOME/.local/share/opencode"
        ln -sfT /agent-data "$HOME/.local/share/opencode"
        BIN=$(command -v opencode || echo "$HOME/.opencode/bin/opencode")
        exec "$BIN" "$@"
        ;;

    claude)
        mkdir -p "$HOME/.config"
        ln -sfT /agent-config "$HOME/.config/claude"
        ln -sfT /agent-data "$HOME/.claude"
        exec claude "$@"
        ;;

    copilot)
        mkdir -p "$HOME/.config"
        ln -sfT /agent-config "$HOME/.config/github-copilot"
        ln -sfT /agent-data "$HOME/.config/github-copilot"
        exec github-copilot-cli "$@"
        ;;

    aider)
        ln -sfT /agent-config "$HOME/.aider"
        ln -sfT /agent-data "$HOME/.aider"
        exec aider "$@"
        ;;

    *)
        echo "Unknown agent: $AGENT"
        echo "Supported: opencode, claude, copilot, aider"
        exit 1
        ;;
esac
