#!/usr/bin/env bash
# Create folders for the Mycelium media stack on ZimaOS.
set -euo pipefail

BASE="/DATA/AppData/mycelium-media-stack"

echo "Creating ${BASE} ..."
mkdir -p \
  "${BASE}/mycelium" \
  "${BASE}/plex-media/movies" \
  "${BASE}/plex-media/tv" \
  "${BASE}/plex" \
  "${BASE}/prowlarr" \
  "${BASE}/radarr" \
  "${BASE}/sonarr" \
  "${BASE}/seerr"

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
chown -R "${PUID}:${PGID}" "${BASE}" 2>/dev/null || sudo chown -R "${PUID}:${PGID}" "${BASE}" || true

HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[[ -n "${HOST_IP}" ]] || HOST_IP="192.168.1.50"

cat <<EOF
Done. Folders created at ${BASE}

Import each compose in ZimaOS (+ → Install a customized app → Import):

  1. zimaos/mycelium/docker-compose.yml   (set API keys + CATBOX_HOST=http://${HOST_IP}:8088)
  2. zimaos/plex/docker-compose.yml       (set MYCELIUM_URL=http://${HOST_IP}:8088)
  3. zimaos/byparr/docker-compose.yml
  4. zimaos/prowlarr/docker-compose.yml
  5. zimaos/radarr/docker-compose.yml
  6. zimaos/sonarr/docker-compose.yml
  7. zimaos/seerr/docker-compose.yml

No network app needed. No .env files.

Guide: zimaos/INSTALL.md
EOF
