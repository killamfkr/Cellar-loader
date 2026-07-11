#!/usr/bin/env bash
# Install Mycelium + Spore + Plex + *arr on ZimaOS (CasaOS-based).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/<your-repo>/main/mycelium-media-stack/install-zimaos.sh | bash
#   # or with keys:
#   TORBOX_API_KEY=xxx TMDB_API_KEY=yyy bash install-zimaos.sh
#
# Optional env:
#   INSTALL_DIR=/DATA/AppData/mycelium-media-stack
#   EXPOSE_LAN=true|false
#   PUID / PGID

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

INSTALL_DIR="${INSTALL_DIR:-/DATA/AppData/mycelium-media-stack}"
CONFIG_DIR="${INSTALL_DIR}/config"
DATA_DIR="${INSTALL_DIR}/data"
EXPOSE_LAN="${EXPOSE_LAN:-true}"

main() {
  log_step "Mycelium media stack installer (ZimaOS)"

  require_cmd docker curl sed awk

  if ! docker compose version &>/dev/null && ! command -v docker-compose &>/dev/null; then
    log_error "Docker Compose v2 is required on ZimaOS."
    exit 1
  fi

  if [[ ! -d /DATA ]]; then
    log_warn "/DATA not found — are you on ZimaOS/CasaOS? Continuing with ${INSTALL_DIR}."
  fi

  IFS=: read -r PUID PGID <<<"$(detect_puid_pgid)"
  export PUID PGID CONFIG_DIR DATA_DIR EXPOSE_LAN

  local host_ip webhook_secret
  host_ip="$(detect_host_ip)"
  webhook_secret="$(random_secret)"

  log_step "Creating directories under ${INSTALL_DIR}"
  ensure_dir "${CONFIG_DIR}/plex"
  ensure_dir "${CONFIG_DIR}/prowlarr"
  ensure_dir "${CONFIG_DIR}/radarr"
  ensure_dir "${CONFIG_DIR}/sonarr"
  ensure_dir "${CONFIG_DIR}/seerr"
  ensure_dir "${DATA_DIR}/mycelium"
  ensure_dir "${DATA_DIR}/plex-media/movies"
  ensure_dir "${DATA_DIR}/plex-media/tv"

  log_step "Downloading Spore Plex transcoder wrapper"
  download_spore_wrapper "${DATA_DIR}/spore"

  log_step "Writing docker-compose.yml and .env"
  write_compose_file "${INSTALL_DIR}/docker-compose.yml"
  write_env_file "${INSTALL_DIR}/.env" "${host_ip}" "${webhook_secret}"
  apply_bind_addresses "${INSTALL_DIR}/.env"

  cp "${SCRIPT_DIR}/manage.sh" "${INSTALL_DIR}/manage.sh"
  chmod +x "${INSTALL_DIR}/manage.sh"

  log_step "Starting containers (first pull may take several minutes)"
  cd "${INSTALL_DIR}"
  docker compose pull
  docker compose up -d

  print_post_install "${INSTALL_DIR}" "${host_ip}"

  cat <<EOF
ZimaOS tips:
  - Containers are managed via SSH: cd ${INSTALL_DIR} && ./manage.sh status
  - To import as a Compose Toolbox project, use ${INSTALL_DIR}/docker-compose.yml
  - If permissions fail, run: sudo chown -R ${PUID}:${PGID} ${INSTALL_DIR}
EOF
}

main "$@"
