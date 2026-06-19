#!/bin/bash
set -e

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
