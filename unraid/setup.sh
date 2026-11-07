#!/usr/bin/env bash
# Unraid one-script install — Ollama + Ollama Cursor Agent
#
# Usage (Unraid terminal):
#   curl -fsSL https://raw.githubusercontent.com/killamfkr/ollama-cursor-agent/main/unraid/setup.sh | bash
#
# With GitHub agent workflow:
#   GITHUB_TOKEN=ghp_xxx GITHUB_REPO=you/repo bash setup.sh
#
# Optional: HOST_IP AGENT_PORT TZ INSTALL_DIR

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/mnt/user/appdata/ollama-cursor-agent}"
AGENT_PORT="${AGENT_PORT:-8080}"
TZ="${TZ:-UTC}"
HOST_IP="${HOST_IP:-}"
REPO_RAW="https://raw.githubusercontent.com/killamfkr/ollama-cursor-agent/main/unraid"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[ollama-agent]${NC} $*"; }
warn() { echo -e "${YELLOW}[ollama-agent]${NC} $*"; }
err() { echo -e "${RED}[ollama-agent]${NC} $*" >&2; }

require_docker() {
  if ! command -v docker &>/dev/null; then
    err "Docker not found — run on Unraid."
    exit 1
  fi
  if ! docker compose version &>/dev/null 2>&1; then
    err "Docker Compose v2 required."
    exit 1
  fi
}

create_dirs() {
  log "Creating ${INSTALL_DIR} ..."
  mkdir -p \
    "${INSTALL_DIR}/ollama" \
    "${INSTALL_DIR}/workspace" \
    "${INSTALL_DIR}/agent-data" \
    "${INSTALL_DIR}/templates"
}

fetch_compose() {
  log "Downloading compose files ..."
  curl -fsSL "${REPO_RAW}/compose.yaml" -o "${INSTALL_DIR}/compose.yaml"
  curl -fsSL "${REPO_RAW}/docker-compose.yml" -o "${INSTALL_DIR}/docker-compose.yml"
}

write_env() {
  log "Writing .env ..."
  cat >"${INSTALL_DIR}/.env" <<EOF
TZ=${TZ}
AGENT_PORT=${AGENT_PORT}
AGENT_DEFAULT_MODEL=${AGENT_DEFAULT_MODEL:-qwen2.5-coder:7b}
AGENT_MAX_AGENT_STEPS=${AGENT_MAX_AGENT_STEPS:-40}
GITHUB_TOKEN=${GITHUB_TOKEN:-}
GITHUB_REPO=${GITHUB_REPO:-}
GITHUB_DEFAULT_BRANCH=${GITHUB_DEFAULT_BRANCH:-main}
GITHUB_BRANCH_PREFIX=${GITHUB_BRANCH_PREFIX:-cursor/}
GITHUB_BRANCH_SUFFIX=${GITHUB_BRANCH_SUFFIX:-local}
GITHUB_WEBHOOK_SECRET=${GITHUB_WEBHOOK_SECRET:-}
GITHUB_TRIGGER_LABEL=${GITHUB_TRIGGER_LABEL:-agent}
GITHUB_COMMENT_TRIGGER=${GITHUB_COMMENT_TRIGGER:-@agent}
PUBLIC_BASE_URL=${PUBLIC_BASE_URL:-}
EOF
}

install_templates() {
  log "Installing Docker XML templates to templates-user ..."
  local dest="/boot/config/plugins/dockerMan/templates-user"
  if [[ ! -d "$dest" ]]; then
    warn "templates-user not found — skip XML install (use manual download from unraid/templates/)"
    return 0
  fi
  curl -fsSL "${REPO_RAW}/ollama.xml" -o "${dest}/my-ollama.xml"
  curl -fsSL "${REPO_RAW}/ollama-cursor-agent.xml" -o "${dest}/my-ollama-cursor-agent.xml"
  log "Templates saved to ${dest}"
}

write_manage() {
  cat >"${INSTALL_DIR}/manage.sh" <<'MEOF'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
cmd="${1:-status}"
case "$cmd" in
  up) docker compose -f compose.yaml up -d ;;
  down) docker compose -f compose.yaml down ;;
  pull) docker compose -f compose.yaml pull && docker compose -f compose.yaml up -d ;;
  status) docker compose -f compose.yaml ps ;;
  logs) docker compose -f compose.yaml logs -f "${2:-agent}" ;;
  model) docker exec -it ollama ollama pull "${2:-qwen2.5-coder:7b}" ;;
  urls)
    ip="${HOST_IP:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
    port="${AGENT_PORT:-8080}"
    echo "Agent UI:  http://${ip}:${port}/"
    echo "Ollama API: http://${ip}:11434/"
    ;;
  *) echo "Usage: $0 {up|down|pull|status|logs|model|urls}" ;;
esac
MEOF
  chmod +x "${INSTALL_DIR}/manage.sh"
}

ensure_agent_image() {
  local img="ghcr.io/killamfkr/ollama-cursor-agent:latest"
  if docker image inspect "$img" &>/dev/null; then
    return 0
  fi
  log "Pulling ${img} ..."
  if docker pull "$img" 2>/dev/null; then
    return 0
  fi
  warn "GHCR image not available yet — building agent from GitHub source ..."
  local build_dir
  build_dir="$(mktemp -d)"
  git clone --depth 1 https://github.com/killamfkr/ollama-cursor-agent.git "${build_dir}/repo"
  docker build -t "$img" "${build_dir}/repo/agent"
  rm -rf "${build_dir}"
}

start_stack() {
  log "Starting stack ..."
  cd "${INSTALL_DIR}"
  docker pull ollama/ollama:latest
  ensure_agent_image
  docker compose -f compose.yaml up -d
}

clone_hint() {
  if [[ -z "$(ls -A "${INSTALL_DIR}/workspace" 2>/dev/null)" ]]; then
    warn "Workspace is empty. Clone your repo, e.g.:"
    echo "  git clone https://github.com/you/your-repo.git ${INSTALL_DIR}/workspace"
  fi
}

main() {
  require_docker
  create_dirs
  fetch_compose
  write_env
  write_manage
  install_templates
  start_stack
  clone_hint
  ip="${HOST_IP:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
  log "Done. Agent UI: http://${ip}:${AGENT_PORT}/"
  log "Pull a model: ${INSTALL_DIR}/manage.sh model qwen2.5-coder:7b"
  log "Control: ${INSTALL_DIR}/manage.sh status"
}

main "$@"
