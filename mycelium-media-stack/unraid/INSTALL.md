# Unraid install — Mycelium media stack

Separate compose files per container. No `.env` files — edit values in each `docker-compose.yml`.

No network holder container — each app uses `network_mode: bridge`.

## Prepare

```bash
mkdir -p /mnt/user/appdata/mycelium-media-stack/{mycelium,plex-media/movies,plex-media/tv,plex,prowlarr,radarr,sonarr,seerr}
```

Edit `mycelium/docker-compose.yml` and `plex/docker-compose.yml` — replace `192.168.1.50` with your Unraid IP.

## Start

```bash
cd /path/to/Cellar-loader/mycelium-media-stack/unraid

docker compose -f mycelium/docker-compose.yml up -d
docker compose -f plex/docker-compose.yml up -d
docker compose -f byparr/docker-compose.yml up -d
docker compose -f prowlarr/docker-compose.yml up -d
docker compose -f radarr/docker-compose.yml up -d
docker compose -f sonarr/docker-compose.yml up -d
docker compose -f seerr/docker-compose.yml up -d
```

Use **LAN IPs** for Seerr/Plex/Mycelium connections — see [ZimaOS guide](../zimaos/INSTALL.md).
