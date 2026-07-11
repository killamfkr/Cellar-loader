#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

COMPOSE=(docker compose)
if ! docker compose version &>/dev/null; then
  if command -v docker-compose &>/dev/null; then
    COMPOSE=(docker-compose)
  else
    echo "Docker Compose v2 is required." >&2
    exit 1
  fi
fi

usage() {
  cat <<'EOF'
Usage: ./manage.sh <command> [service]

Commands:
  start [svc]     Start all services (or one service)
  stop [svc]      Stop all services (or one service)
  restart [svc]   Restart all services (or one service)
  status          Show container status
  logs [svc]      Follow logs (default: all)
  pull            Pull newer images
  update          Pull images and recreate containers
  urls            Print service URLs
  claim-plex      Print Plex claim instructions
  uninstall       Stop stack and remove containers (keeps data)

EOF
}

host_ip() {
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')" || true
  [[ -n "${ip}" ]] || ip="127.0.0.1"
  echo "${ip}"
}

cmd="${1:-}"
svc="${2:-}"

case "${cmd}" in
  start)
    if [[ -n "${svc}" ]]; then
      "${COMPOSE[@]}" up -d "${svc}"
    else
      "${COMPOSE[@]}" up -d
    fi
    ;;
  stop)
    if [[ -n "${svc}" ]]; then
      "${COMPOSE[@]}" stop "${svc}"
    else
      "${COMPOSE[@]}" stop
    fi
    ;;
  restart)
    if [[ -n "${svc}" ]]; then
      "${COMPOSE[@]}" restart "${svc}"
    else
      "${COMPOSE[@]}" restart
    fi
    ;;
  status)
    "${COMPOSE[@]}" ps
    ;;
  logs)
    if [[ -n "${svc}" ]]; then
      "${COMPOSE[@]}" logs -f --tail=200 "${svc}"
    else
      "${COMPOSE[@]}" logs -f --tail=100
    fi
    ;;
  pull)
    "${COMPOSE[@]}" pull
    ;;
  update)
    "${COMPOSE[@]}" pull
    "${COMPOSE[@]}" up -d
    ;;
  urls)
    ip="$(host_ip)"
    cat <<EOF
Mycelium: http://${ip}:8088
Plex:     http://${ip}:32400/web
Seerr:    http://${ip}:5055
Radarr:   http://${ip}:7878
Sonarr:   http://${ip}:8989
Prowlarr: http://${ip}:9696
EOF
    ;;
  claim-plex)
    cat <<'EOF'
1. Open https://www.plex.tv/claim/ and copy the claim token (expires in ~4 minutes).
2. Edit .env and set PLEX_CLAIM=your-token
3. Run: ./manage.sh restart plex
EOF
    ;;
  uninstall)
    read -r -p "Remove containers for mycelium-media-stack? Data in CONFIG_DIR/DATA_DIR is kept. [y/N] " ans
    if [[ "${ans}" =~ ^[Yy]$ ]]; then
      "${COMPOSE[@]}" down
      echo "Containers removed. Delete ${SCRIPT_DIR} manually to remove configs."
    fi
    ;;
  ""|-h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: ${cmd}" >&2
    usage
    exit 1
    ;;
esac
