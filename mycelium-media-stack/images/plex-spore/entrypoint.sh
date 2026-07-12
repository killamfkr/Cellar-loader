#!/bin/bash
set -euo pipefail

if [[ ! -f '/usr/lib/plexmediaserver/Plex Transcoder.real' ]]; then
  mv '/usr/lib/plexmediaserver/Plex Transcoder' '/usr/lib/plexmediaserver/Plex Transcoder.real'
fi
cp /opt/spore/plex_transcoder_wrapper.sh '/usr/lib/plexmediaserver/Plex Transcoder'
chmod +x '/usr/lib/plexmediaserver/Plex Transcoder'
exec /init "$@"
