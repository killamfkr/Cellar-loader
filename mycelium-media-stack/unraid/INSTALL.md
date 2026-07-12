# Unraid install — Mycelium media stack

Separate compose files per container. **No `.env` files** — edit values directly in each `docker-compose.yml` before starting.

Plex uses `ghcr.io/killamfkr/plex-spore` (Spore pre-baked in the image, no runtime downloads).

## Prepare

```bash
mkdir -p /mnt/user/appdata/mycelium-media-stack/{mycelium,plex-media/movies,plex-media/tv,plex,prowlarr,radarr,sonarr,seerr}
docker network create mycelium-media 2>/dev/null || true
```

## Start (in order)

Edit `mycelium/docker-compose.yml` first — set `TORBOX_API_KEY`, `TMDB_API_KEY`, `CATBOX_HOST`, `WEBHOOK_SECRET`.

```bash
cd /path/to/Cellar-loader/mycelium-media-stack/unraid

docker compose -f network/docker-compose.yml up -d
docker compose -f mycelium/docker-compose.yml up -d
docker compose -f plex/docker-compose.yml up -d
docker compose -f byparr/docker-compose.yml up -d
docker compose -f prowlarr/docker-compose.yml up -d
docker compose -f radarr/docker-compose.yml up -d
docker compose -f sonarr/docker-compose.yml up -d
docker compose -f seerr/docker-compose.yml up -d
```

Or import each file into **Docker Compose Manager** on Unraid.

## Service URLs

| Service | URL |
|---------|-----|
| Mycelium | `http://<IP>:8088` |
| Plex | `http://<IP>:32400/web` |
| Seerr | `http://<IP>:5055` |
| Radarr | `http://<IP>:7878` |
| Sonarr | `http://<IP>:8989` |
| Prowlarr | `http://<IP>:9696` |

Post-install steps match the [ZimaOS guide](../zimaos/INSTALL.md).

## Build Plex Spore image locally (if needed)

```bash
cd mycelium-media-stack/images/plex-spore
docker build -t ghcr.io/killamfkr/plex-spore:latest .
```
