#!/usr/bin/env bash
# Create ZimaOS folder layout for the Mycelium Media Stack compose app.
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

cat <<EOF
Done.

Next:
  1. ZimaOS → + → Install a customized app → Import
  2. Paste docker-compose.yml from mycelium-media-stack/zimaos/
  3. Set TORBOX_API_KEY, TMDB_API_KEY, CATBOX_HOST, WEBHOOK_SECRET
  4. Install

Full guide: mycelium-media-stack/zimaos/INSTALL.md
EOF
