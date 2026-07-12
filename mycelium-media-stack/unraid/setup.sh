#!/usr/bin/env bash
# One-script Unraid setup — Mycelium + Plex Spore + *arr stack
# Preconfigured for 192.168.0.100
#
# Usage:
#   TORBOX_API_KEY=your-key TMDB_API_KEY=your-tmdb-token bash setup.sh
#
# Or from GitHub:
#   curl -fsSL https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/unraid/setup.sh | \
#     TORBOX_API_KEY=your-key TMDB_API_KEY=your-tmdb-token bash
#
# Optional:
#   HOST_IP=192.168.0.100  PUID=99  PGID=100  TZ=America/New_York
#   PLEX_CLAIM=claim-token  WEBHOOK_SECRET=your-secret

set -euo pipefail

HOST_IP="${HOST_IP:-192.168.0.100}"
INSTALL_DIR="${INSTALL_DIR:-/mnt/user/appdata/mycelium-media-stack}"
PUID="${PUID:-99}"
PGID="${PGID:-100}"
TZ="${TZ:-UTC}"
REPO_RAW="https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[setup]${NC} $*"; }
warn() { echo -e "${YELLOW}[setup]${NC} $*"; }
err()  { echo -e "${RED}[setup]${NC} $*" >&2; }

random_secret() {
  if command -v openssl &>/dev/null; then
    openssl rand -hex 16
  else
    tr -dc 'a-f0-9' </dev/urandom | head -c 32
  fi
}

require_docker() {
  if ! command -v docker &>/dev/null; then
    err "Docker not found. Run this on your Unraid terminal."
    exit 1
  fi
  if ! docker compose version &>/dev/null 2>&1; then
    err "Docker Compose v2 required (docker compose)."
    exit 1
  fi
}

check_keys() {
  if [[ -z "${TORBOX_API_KEY:-}" || "${TORBOX_API_KEY}" == "replace-me" ]]; then
    err "Set TORBOX_API_KEY before running."
    err "Example: TORBOX_API_KEY=xxx TMDB_API_KEY=yyy bash setup.sh"
    exit 1
  fi
  if [[ -z "${TMDB_API_KEY:-}" || "${TMDB_API_KEY}" == "replace-me" ]]; then
    err "Set TMDB_API_KEY before running (Read Access Token from themoviedb.org)."
    exit 1
  fi
}

create_dirs() {
  log "Creating directories under ${INSTALL_DIR} ..."
  mkdir -p \
    "${INSTALL_DIR}/mycelium" \
    "${INSTALL_DIR}/plex" \
    "${INSTALL_DIR}/plex-media/movies" \
    "${INSTALL_DIR}/plex-media/tv" \
    "${INSTALL_DIR}/prowlarr" \
    "${INSTALL_DIR}/radarr" \
    "${INSTALL_DIR}/sonarr" \
    "${INSTALL_DIR}/seerr"
  chown -R "${PUID}:${PGID}" "${INSTALL_DIR}" 2>/dev/null || true
}

write_compose() {
  log "Writing docker-compose.yml (host ${HOST_IP}) ..."
  WEBHOOK_SECRET="${WEBHOOK_SECRET:-$(random_secret)}"

  cat >"${INSTALL_DIR}/docker-compose.yml" <<EOF
name: mycelium-media-stack

services:
  mycelium:
    image: ghcr.io/corveck79/mycelium:latest
    container_name: mycelium
    restart: unless-stopped
    ports:
      - "8088:8088"
    environment:
      PUID: ${PUID}
      PGID: ${PGID}
      TZ: ${TZ}
      LISTEN_HOST: 0.0.0.0
      LISTEN_PORT: 8088
      DB_PATH: /data/requests.db
      MEDIA_PATH: /data/media
      TORBOX_API_KEY: ${TORBOX_API_KEY}
      TORBOX_BASE_URL: https://api.torbox.app/v1/api
      TMDB_API_KEY: ${TMDB_API_KEY}
      CATBOX_MODE: "true"
      CATBOX_HOST: http://${HOST_IP}:8088
      CATBOX_IDLE_MINUTES: "43200"
      SPORE_ENABLED: "true"
      SPORE_MEDIA_PATH: /data/plex-media
      WEBHOOK_SECRET: ${WEBHOOK_SECRET}
      SEERR_URL: http://${HOST_IP}:5055
      SEERR_API_KEY: ${SEERR_API_KEY:-}
      QUALITY_PREFERENCE: 1080p,2160p,720p
      ALLOW_4K: "true"
      EXCLUDE_REMUX: "true"
      EXCLUDE_CAM: "true"
      PREFER_WEBDL: "true"
      PREFER_HEVC: "true"
      MIN_SEEDERS: "3"
      AUTO_UPGRADE_ENABLED: "true"
      LOG_LEVEL: INFO
    volumes:
      - ${INSTALL_DIR}/mycelium:/data
      - ${INSTALL_DIR}/plex-media:/data/plex-media

  plex:
    image: ghcr.io/killamfkr/plex-spore:latest
    container_name: plex
    restart: unless-stopped
    depends_on:
      - mycelium
    ports:
      - "32400:32400"
    environment:
      PUID: ${PUID}
      PGID: ${PGID}
      TZ: ${TZ}
      VERSION: docker
      PLEX_CLAIM: \${PLEX_CLAIM:-}
      MYCELIUM_URL: http://mycelium:8088
    volumes:
      - ${INSTALL_DIR}/plex:/config
      - ${INSTALL_DIR}/plex-media:/plex-media

  byparr:
    image: ghcr.io/thephaseless/byparr:latest
    container_name: byparr
    restart: unless-stopped
    ports:
      - "8191:8191"
    environment:
      LOG_LEVEL: info
      LOG_HTML: "false"
      TZ: ${TZ}

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    restart: unless-stopped
    depends_on:
      - byparr
    ports:
      - "9696:9696"
    environment:
      PUID: ${PUID}
      PGID: ${PGID}
      TZ: ${TZ}
    volumes:
      - ${INSTALL_DIR}/prowlarr:/config

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    restart: unless-stopped
    ports:
      - "7878:7878"
    environment:
      PUID: ${PUID}
      PGID: ${PGID}
      TZ: ${TZ}
    volumes:
      - ${INSTALL_DIR}/radarr:/config
      - ${INSTALL_DIR}/plex-media/movies:/movies

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    restart: unless-stopped
    ports:
      - "8989:8989"
    environment:
      PUID: ${PUID}
      PGID: ${PGID}
      TZ: ${TZ}
    volumes:
      - ${INSTALL_DIR}/sonarr:/config
      - ${INSTALL_DIR}/plex-media/tv:/tv

  seerr:
    image: ghcr.io/seerr-team/seerr:latest
    container_name: seerr
    restart: unless-stopped
    depends_on:
      - plex
      - radarr
      - sonarr
    ports:
      - "5055:5055"
    environment:
      TZ: ${TZ}
    volumes:
      - ${INSTALL_DIR}/seerr:/app/config
EOF

  cat >"${INSTALL_DIR}/.stack-env" <<EOF
# Generated by setup.sh — used by manage.sh
HOST_IP=${HOST_IP}
WEBHOOK_SECRET=${WEBHOOK_SECRET}
INSTALL_DIR=${INSTALL_DIR}
EOF
  chmod 600 "${INSTALL_DIR}/.stack-env"
}

write_manage() {
  cat >"${INSTALL_DIR}/manage.sh" <<'MANAGE'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[[ -f .stack-env ]] && source .stack-env
COMPOSE=(docker compose)
usage() {
  echo "Usage: ./manage.sh {start|stop|restart|status|logs|urls|update|claim-plex}"
}
pref_file() {
  echo "$(pwd)/plex/Library/Application Support/Plex Media Server/Preferences.xml"
}
cmd="${1:-}"
case "${cmd}" in
  start)   docker compose up -d ;;
  stop)    docker compose stop ;;
  restart) docker compose restart ;;
  status)  docker compose ps ;;
  logs)    docker compose logs -f --tail=100 "${2:-}" ;;
  update)  docker compose pull && docker compose up -d ;;
  claim-plex)
    echo "1. Open https://www.plex.tv/claim/ and copy the token (expires in ~4 minutes)"
    read -r -p "2. Paste PLEX_CLAIM token: " token
    [[ -n "${token}" ]] || { echo "No token entered."; exit 1; }
    docker stop plex 2>/dev/null || true
    pref="$(pref_file)"
    if [[ -f "${pref}" ]]; then
      echo "Clearing old Plex account link from Preferences.xml ..."
      sed -i \
        -e 's/ PlexOnlineToken="[^"]*"//g' \
        -e 's/ PlexOnlineUsername="[^"]*"//g' \
        -e 's/ PlexOnlineEmail="[^"]*"//g' \
        -e 's/ PlexOnlineHome="[^"]*"//g' \
        "${pref}"
    fi
    echo "Claiming server and starting Plex ..."
    PLEX_CLAIM="${token}" docker compose up -d plex
    echo "Wait ~30s, then open: http://${HOST_IP:-192.168.0.100}:32400/web"
    echo "Sign in with the SAME Plex account you used for the claim token."
    ;;
  urls)
    ip="${HOST_IP:-192.168.0.100}"
    cat <<EOF
Mycelium: http://${ip}:8088
Plex:     http://${ip}:32400/web
Seerr:    http://${ip}:5055
Radarr:   http://${ip}:7878
Sonarr:   http://${ip}:8989
Prowlarr: http://${ip}:9696
EOF
    [[ -f .stack-env ]] && echo "Webhook secret: $(grep WEBHOOK_SECRET .stack-env | cut -d= -f2-)"
    ;;
  *) usage; exit 1 ;;
esac
MANAGE
  chmod +x "${INSTALL_DIR}/manage.sh"
}

ensure_plex_image() {
  if docker image inspect ghcr.io/killamfkr/plex-spore:latest &>/dev/null; then
    return 0
  fi
  log "Pulling Plex Spore image ..."
  if docker pull ghcr.io/killamfkr/plex-spore:latest 2>/dev/null; then
    return 0
  fi
  warn "Plex Spore image not on GHCR — building locally ..."
  local build_dir="${INSTALL_DIR}/.build/plex-spore"
  mkdir -p "${build_dir}"
  curl -fsSL "${REPO_RAW}/images/plex-spore/Dockerfile" -o "${build_dir}/Dockerfile"
  curl -fsSL "${REPO_RAW}/images/plex-spore/entrypoint.sh" -o "${build_dir}/entrypoint.sh"
  curl -fsSL "${REPO_RAW}/images/plex-spore/plex_transcoder_wrapper.sh" -o "${build_dir}/plex_transcoder_wrapper.sh"
  chmod +x "${build_dir}/entrypoint.sh"
  docker build -t ghcr.io/killamfkr/plex-spore:latest "${build_dir}"
}

start_stack() {
  log "Pulling images and starting stack ..."
  cd "${INSTALL_DIR}"
  docker compose pull
  docker compose up -d
}

print_done() {
  cat <<EOF

${GREEN}=== Mycelium media stack is running ===${NC}

Install dir: ${INSTALL_DIR}
Manage:      cd ${INSTALL_DIR} && ./manage.sh urls

${CYAN}Services (192.168.0.100)${NC}
  Mycelium  http://${HOST_IP}:8088   ← complete setup wizard first
  Plex      http://${HOST_IP}:32400/web
  Seerr     http://${HOST_IP}:5055
  Radarr    http://${HOST_IP}:7878
  Sonarr    http://${HOST_IP}:8989
  Prowlarr  http://${HOST_IP}:9696

${CYAN}Seerr webhook${NC}
  URL:    http://${HOST_IP}:8088/webhook
  Header: X-Webhook-Secret: ${WEBHOOK_SECRET:-see .stack-env}

${CYAN}Plex — claim your server${NC}
  If you see "You do not have access to this server":
    cd ${INSTALL_DIR} && ./manage.sh claim-plex
  Or open http://${HOST_IP}:32400/web from a device on your LAN and sign in.

${CYAN}Plex libraries${NC}
  Movies: /plex-media/movies
  TV:     /plex-media/tv

${CYAN}Radarr / Sonarr (list managers — Mycelium does the grabbing)${NC}
  Radarr root folder: /movies   (no download client)
  Sonarr root folder: /tv      (no download client)
  Mycelium Admin → Integrations → connect Radarr & Sonarr for bulk import

${CYAN}Seerr connections (use LAN IP)${NC}
  Plex:   http://${HOST_IP}:32400
  Radarr: http://${HOST_IP}:7878
  Sonarr: http://${HOST_IP}:8989

EOF
}

main() {
  echo -e "${CYAN}Mycelium media stack — Unraid setup (${HOST_IP})${NC}"
  require_docker
  check_keys
  create_dirs
  write_compose
  write_manage
  ensure_plex_image
  start_stack
  print_done
}

main "$@"
