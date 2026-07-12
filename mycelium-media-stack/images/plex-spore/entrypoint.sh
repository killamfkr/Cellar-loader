#!/bin/bash
set -euo pipefail

MYCELIUM_URL="${MYCELIUM_URL:-http://172.17.0.1:8088}"
WRAPPER="/tmp/plex_transcoder_wrapper.sh"

sed "s|http://mycelium:8088|${MYCELIUM_URL}|g" /opt/spore/plex_transcoder_wrapper.sh > "${WRAPPER}"
chmod +x "${WRAPPER}"

if [[ ! -f '/usr/lib/plexmediaserver/Plex Transcoder.real' ]]; then
  mv '/usr/lib/plexmediaserver/Plex Transcoder' '/usr/lib/plexmediaserver/Plex Transcoder.real'
fi
cp "${WRAPPER}" '/usr/lib/plexmediaserver/Plex Transcoder'
chmod +x '/usr/lib/plexmediaserver/Plex Transcoder'
exec /init "$@"
