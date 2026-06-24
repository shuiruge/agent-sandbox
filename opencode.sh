# This is a helper script that runs opencode web UI in docker in one line.
# Copied from README.md
AGENT=opencode

# Users shall adjust these variables for his usage
WORKSPACE_DIR=./sandbox/workspace
DATA_DIR=./sandbox/data
CONFIG_DIR=~/.config/opencode

# Then, in his terminal, run `sh opencode.sh` will start up a web UI in docker.

# Users shall not modify this part
docker rm -f $(docker ps -q --filter publish=4096) 2>/dev/null
docker run --rm -it --init \
  --cap-drop ALL --cap-add CHOWN --cap-add FOWNER --cap-add DAC_OVERRIDE --cap-add SETUID --cap-add SETGID --cap-add AUDIT_WRITE \
  -v $WORKSPACE_DIR:/workspace \
  -v $CONFIG_DIR:/agent-config:ro \
  -v $DATA_DIR:/agent-data \
  -e HOST_UID=$(id -u) \
  -p 4096:4096 \
  -e AGENT=$AGENT \
  agent-sandbox:latest web --hostname 0.0.0.0 --port 4096

