#!/usr/bin/env bash
# Create folders (and shared network) for the Mycelium media stack on ZimaOS.
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

if command -v docker &>/dev/null; then
  docker network create mycelium-media 2>/dev/null || true
  echo "Docker network 'mycelium-media' ready."
fi

cat <<'EOF'
Folders ready.

Import each compose separately in ZimaOS (Install a customized app → Import):

  1. zimaos/network/docker-compose.yml
  2. zimaos/mycelium/docker-compose.yml   ← set API keys here
  3. zimaos/plex/docker-compose.yml
  4. zimaos/byparr/docker-compose.yml
  5. zimaos/prowlarr/docker-compose.yml
  6. zimaos/radarr/docker-compose.yml
  7. zimaos/sonarr/docker-compose.yml
  8. zimaos/seerr/docker-compose.yml

No .env files — edit variables in the ZimaOS app settings UI.

Full guide: zimaos/INSTALL.md
EOF
