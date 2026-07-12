#!/usr/bin/env bash
set -euo pipefail
BASE="/mnt/user/appdata/mycelium-media-stack"
mkdir -p "${BASE}"/{mycelium,plex-media/movies,plex-media/tv,plex,prowlarr,radarr,sonarr,seerr}
echo "Ready. See unraid/INSTALL.md — edit compose files then docker compose up -d each one."
