IMAGE_NAME='nix-flake:latest'
NIX_STORE_VOLUME='nix-store'

# 1. 清理旧容器
docker ps -a | grep $IMAGE_NAME | awk '{print $1}' | xargs -r docker rm -f

# 2. 彻底删除旧 Volume (非常重要)
docker volume rm $NIX_STORE_VOLUME
