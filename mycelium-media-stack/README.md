# Mycelium + Spore + Plex + *arr stack

Self-hosted TorBox media stack using [Mycelium](https://github.com/corveck79/mycelium) Catbox mode and Spore Plex integration.

## ZimaOS (recommended — Custom App import)

**Easiest path:** one compose file + UI import.

| File | Purpose |
|------|---------|
| [`zimaos/docker-compose.yml`](zimaos/docker-compose.yml) | Paste into ZimaOS **Install a customized app → Import** |
| [`zimaos/INSTALL.md`](zimaos/INSTALL.md) | Step-by-step setup guide |
| [`zimaos/prepare.sh`](zimaos/prepare.sh) | Creates `/DATA/AppData/mycelium-media-stack` folders |

### Quick start

```bash
# Optional: create folders first
bash mycelium-media-stack/zimaos/prepare.sh
```

Then in ZimaOS:

1. **+** → **Install a customized app** → **Import** → **Docker Compose**
2. Paste [`zimaos/docker-compose.yml`](zimaos/docker-compose.yml)
3. Set `TORBOX_API_KEY`, `TMDB_API_KEY`, `CATBOX_HOST`, `WEBHOOK_SECRET`
4. **Install** → open Mycelium on port **8088**

Or run the helper:

```bash
bash mycelium-media-stack/install-zimaos.sh
```

## Unraid

| File | Purpose |
|------|---------|
| [`unraid/docker-compose.yml`](unraid/docker-compose.yml) | Standard compose for Docker Compose Manager / terminal |
| [`unraid/.env.example`](unraid/.env.example) | Environment template |
| [`unraid/INSTALL.md`](unraid/INSTALL.md) | Unraid notes |
| [`install-unraid.sh`](install-unraid.sh) | Automated installer |

```bash
TORBOX_API_KEY=xxx TMDB_API_KEY=yyy bash install-unraid.sh
```

## Stack

| Service | Port | Role |
|---------|------|------|
| Mycelium | 8088 | TorBox pipeline, Catbox + Spore |
| Plex | 32400 | Media server (Spore wrapper auto-installed) |
| Seerr | 5055 | Requests |
| Radarr | 7878 | Bulk import / list management |
| Sonarr | 8989 | Bulk import / list management |
| Prowlarr | 9696 | Indexers |
| Byparr | 8191 | Cloudflare bypass |

**Note:** Mycelium is the download/stream engine. Radarr/Sonarr are not qBittorrent clients in this stack.

## Management (script install only)

If you used `install-unraid.sh` or an older script-based ZimaOS install:

```bash
cd <install-dir> && ./manage.sh start|stop|status|logs|urls
```

## Legal

Stream only content you have the right to access. Comply with TorBox terms and copyright law.
