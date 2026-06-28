FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 安装基础依赖
RUN apt-get update && apt-get install -y \
    curl git xz-utils ca-certificates locales \
    && rm -rf /var/lib/apt/lists/*

# 配置编码
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# 创建 dev 用户并授权
# 预创建 /nix 目录并授权给 dev，确保 Volume 挂载后 dev 用户有写权限
RUN useradd -m -s /bin/bash dev && \
    mkdir -m 0755 /nix && \
    chown dev:dev /nix

# 复制初始化脚本 (放在切换用户之前，方便直接设置所有权)
COPY init_nix.sh /home/dev/init_nix.sh
RUN chown dev:dev /home/dev/init_nix.sh && chmod +x /home/dev/init_nix.sh

# 切换到普通用户环境
USER dev
ENV USER=dev
WORKDIR /home/dev

# 配置 Git 全局设置 (关键步骤)
# 必须在切换到 USER dev 之后执行，这样配置才会写入 /home/dev/.gitconfig
#RUN git config --global user.email "dev@container.local" && \
#    git config --global user.name "Dev User" && \
#    git config --global init.defaultBranch main

# 预配置 Nix (加速源 + Flakes)
RUN mkdir -p /home/dev/.config/nix && \
    echo "experimental-features = nix-command flakes" > /home/dev/.config/nix/nix.conf && \
    echo "substituters = https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org" >> /home/dev/.config/nix/nix.conf

# 设置环境变量
ENV PATH=/home/dev/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

ENTRYPOINT ["/bin/bash", "/home/dev/init_nix.sh"]
CMD ["bash"]

