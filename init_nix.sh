#!/bin/bash
set -e

USER_HOME="/home/dev"
NIX_INSTALL_URL="https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install"

# 定义标准路径
PROFILE_DIR="/nix/var/nix/profiles/per-user/dev"
USER_PROFILE="$PROFILE_DIR/profile"
MANIFEST_FILE="$PROFILE_DIR/manifest.nix"

# ================= 步骤 1：安装/恢复 Nix 核心 =================
if [ ! -L "$USER_PROFILE" ]; then
    echo ">>> [Install] Setting up Nix Profile..."
    mkdir -p "$PROFILE_DIR"

    # 尝试寻找 Store 里已有的 Nix 包
    NIX_STORE_PATH=$(ls -d /nix/store/*-nix-2.* 2>/dev/null | grep -v '\.patch' | grep -v 'nixpkgs' | head -n 1)

    if [ ! -z "$NIX_STORE_PATH" ] && [ -d "$NIX_STORE_PATH" ]; then
        # === 情况 A：Store 有数据，恢复链接和账本 ===
        echo ">>> Found existing Nix in store, restoring profile..."

        # 1. 创建 Generation 链接
        ln -sf "$NIX_STORE_PATH" "$USER_PROFILE-1-link"
        ln -sf "$USER_PROFILE-1-link" "$USER_PROFILE"

        # 2. 【关键步骤】生成 manifest.nix (账本)
        # 这会让 'nix profile list' 能够识别出已安装的 nix 包
        echo "[{ outPath = \"$NIX_STORE_PATH\"; attrPath = [\"nix\"]; }]" > "$MANIFEST_FILE"

    else
        # === 情况 B：全新安装 ===
        echo ">>> Performing fresh installation..."
        curl -L $NIX_INSTALL_URL | sh -s -- --no-daemon

        # 官方安装脚本会把 profile 放在家目录，我们把它移到 /nix 下统一管理
        if [ -L "$USER_HOME/.nix-profile" ]; then
            mv "$USER_HOME/.nix-profile" "$USER_PROFILE"
            # 如果官方脚本生成了 manifest，也一并移过来（如果有）
            if [ -f "$USER_HOME/.nix-profile/manifest.nix" ]; then
                mv "$USER_HOME/.nix-profile/manifest.nix" "$MANIFEST_FILE"
            fi
        fi
    fi
else
    echo ">>> [Restore] Nix profile found."
fi

# ================= 步骤 2：配置用户环境 =================
# 确保家目录的链接始终指向 /nix 下的持久化 Profile
ln -sf "$USER_PROFILE" "$USER_HOME/.nix-profile"

# 加载环境变量
if [ -e "$USER_HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$USER_HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# ================= 步骤 3：配置软件源 (Channel) =================
if ! nix-channel --list | grep -q "nixpkgs"; then
    echo ">>> Adding nixpkgs channel..."
    # 使用清华镜像加速
    nix-channel --add https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixpkgs-unstable nixpkgs
    nix-channel --update
fi

# ================= 步骤 4：配置 Flake (可选) =================
mkdir -p "$USER_HOME/.config/nix"
if [ ! -f "$USER_HOME/.config/nix/nix.conf" ]; then
    cat > "$USER_HOME/.config/nix/nix.conf" << EOF
experimental-features = nix-command flakes
substituters = https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org
EOF
fi

# ================= 步骤 5：写入 .bashrc =================
if ! grep -q "Nix Profile" "$USER_HOME/.bashrc" 2>/dev/null; then
    echo "" >> "$USER_HOME/.bashrc"
    echo "# Nix Profile" >> "$USER_HOME/.bashrc"
    echo "if [ -e $USER_HOME/.nix-profile/etc/profile.d/nix.sh ]; then . $USER_HOME/.nix-profile/etc/profile.d/nix.sh; fi" >> "$USER_HOME/.bashrc"
fi

exec "$@"

