IMAGE_NAME="nix-flake:latest"
NIX_STORE_VOLUME="nix-store"
WORKSPACE_DIR="$(pwd)/workspace"

echo $WORKSPACE_DIR
mkdir -p $WORKSPACE_DIR

docker run -it --rm \
  -v $NIX_STORE_VOLUME:/nix \
  -v $WORKSPACE_DIR:/home/dev/workspace \
  $IMAGE_NAME
