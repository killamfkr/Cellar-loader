#!/usr/bin/env bash
# Install Mycelium + Spore + Plex + *arr on Unraid.
#
# Usage (from Unraid terminal / User Scripts):
#   bash install-unraid.sh
#
# With API keys:
#   TORBOX_API_KEY=xxx TMDB_API_KEY=yyy bash install-unraid.sh
#
# Optional env:
#   INSTALL_DIR=/mnt/user/appdata/mycelium-media-stack
#   INSTALL_USER_SCRIPT=true   # drop a helper into User Scripts plugin
#   EXPOSE_LAN=true|false
#   PUID=99 PGID=100           # Unraid defaults

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

INSTALL_DIR="${INSTALL_DIR:-/mnt/user/appdata/mycelium-media-stack}"
CONFIG_DIR="${INSTALL_DIR}/config"
DATA_DIR="${INSTALL_DIR}/data"
EXPOSE_LAN="${EXPOSE_LAN:-true}"
INSTALL_USER_SCRIPT="${INSTALL_USER_SCRIPT:-true}"

install_user_script() {
  local target="/boot/config/plugins/user.scripts/scripts/mycelium-media-stack"
  if [[ ! -d /boot/config/plugins/user.scripts/scripts ]]; then
    log_warn "User Scripts plugin not found; skipping helper script install."
    return 0
  fi
  mkdir -p "${target}"
  cat >"${target}/script" <<EOF
#!/bin/bash
cd "${INSTALL_DIR}" || exit 1
./manage.sh status
./manage.sh urls
EOF
  chmod +x "${target}/script"
  cat >"${target}/description" <<'EOF'
Mycelium media stack — show status and URLs
EOF
  log_info "Installed User Script: mycelium-media-stack"
}

install_compose_manager_hint() {
  local cmp_dir="/boot/config/plugins/compose.manager/projects/${STACK_NAME}"
  if [[ -d /boot/config/plugins/compose.manager/projects ]]; then
    log_info "Docker Compose Manager detected."
    log_info "Optional: symlink ${INSTALL_DIR} -> ${cmp_dir}"
    log_info "  ln -sfn ${INSTALL_DIR} ${cmp_dir}"
  fi
}

main() {
  log_step "Mycelium media stack installer (Unraid)"

  require_cmd docker curl sed awk

  if [[ ! -d /mnt/user ]]; then
    log_error "/mnt/user not found — run this script on Unraid."
    exit 1
  fi

  # Unraid convention: nobody:users unless overridden
  PUID="${PUID:-99}"
  PGID="${PGID:-100}"
  export PUID PGID CONFIG_DIR DATA_DIR EXPOSE_LAN

  local host_ip webhook_secret
  host_ip="$(detect_host_ip)"
  webhook_secret="$(random_secret)"

  log_step "Creating directories under ${INSTALL_DIR}"
  mkdir -p \
    "${CONFIG_DIR}/plex" \
    "${CONFIG_DIR}/prowlarr" \
    "${CONFIG_DIR}/radarr" \
    "${CONFIG_DIR}/sonarr" \
    "${CONFIG_DIR}/seerr" \
    "${DATA_DIR}/mycelium" \
    "${DATA_DIR}/plex-media/movies" \
    "${DATA_DIR}/plex-media/tv"

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

  if [[ "${INSTALL_USER_SCRIPT}" == "true" ]]; then
    install_user_script
  fi
  install_compose_manager_hint

  print_post_install "${INSTALL_DIR}" "${host_ip}"

  cat <<EOF
Unraid tips:
  - Appdata lives on the array/cache: ${INSTALL_DIR}
  - Manage from terminal: cd ${INSTALL_DIR} && ./manage.sh <command>
  - For GPU transcoding in Plex, add /dev/dri to the Plex container in the UI
  - Spore is experimental on Apple TV / Android TV clients
EOF
}

main "$@"
