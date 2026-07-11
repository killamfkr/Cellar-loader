# Unraid — Mycelium Media Stack

## Quick install (terminal)

```bash
mkdir -p /mnt/user/appdata/mycelium-media-stack/{mycelium,plex-media/movies,plex-media/tv,plex,prowlarr,radarr,sonarr,seerr}
cd /mnt/user/appdata/mycelium-media-stack
# copy docker-compose.yml and .env.example from this folder, then:
cp .env.example .env
# edit .env — set TORBOX_API_KEY, TMDB_API_KEY, CATBOX_HOST, WEBHOOK_SECRET
docker compose up -d
```

## Or use the installer script

```bash
git clone https://github.com/killamfkr/Cellar-loader.git
cd Cellar-loader/mycelium-media-stack
TORBOX_API_KEY=xxx TMDB_API_KEY=yyy bash install-unraid.sh
```

## Service URLs

| Service | URL |
|---------|-----|
| Mycelium | `http://<UNRAID-IP>:8088` |
| Plex | `http://<UNRAID-IP>:32400/web` |
| Seerr | `http://<UNRAID-IP>:5055` |
| Radarr | `http://<UNRAID-IP>:7878` |
| Sonarr | `http://<UNRAID-IP>:8989` |
| Prowlarr | `http://<UNRAID-IP>:9696` |

See the ZimaOS guide for post-install steps (Mycelium wizard, Plex libraries, Seerr webhook) — the flow is the same.
