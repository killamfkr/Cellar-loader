#!/usr/bin/env bash
set -euo pipefail

BASE="/mnt/user/appdata/mycelium-media-stack"
mkdir -p "${BASE}"/{mycelium,plex-media/movies,plex-media/tv,plex,prowlarr,radarr,sonarr,seerr}
docker network create mycelium-media 2>/dev/null || true

cat <<EOF
Unraid folders ready at ${BASE}

Edit and start each compose in order — see unraid/INSTALL.md:

  docker compose -f unraid/network/docker-compose.yml up -d
  docker compose -f unraid/mycelium/docker-compose.yml up -d
  docker compose -f unraid/plex/docker-compose.yml up -d
  ...
EOF
