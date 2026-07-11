# Mycelium + Spore + Plex + *arr stack

Self-hosted installer scripts for [Mycelium](https://github.com/corveck79/mycelium) with **Spore** (Plex), plus Radarr, Sonarr, Prowlarr, Byparr, and Seerr.

Inspired by the [ElfHosted Plex + TorBox + *arr guide](https://docs.elfhosted.com/guides/media/plex-torbox-aars/), but runs on your own hardware using Mycelium's Catbox-style lazy TorBox materialization instead of proprietary CatBox.

## What you get

| Service | Port | Role |
|---------|------|------|
| Mycelium | 8088 | TorBox pipeline, Catbox mode, Spore stub library |
| Plex | 32400 | Media server (Spore transcoder wrapper) |
| Seerr | 5055 | Request UI |
| Radarr | 7878 | Movie list management / bulk import into Mycelium |
| Sonarr | 8989 | TV list management / bulk import into Mycelium |
| Prowlarr | 9696 | Indexer manager |
| Byparr | 8191 | Cloudflare bypass for Prowlarr |

**Important:** Mycelium is the download/stream engine. Radarr and Sonarr are **not** qBittorrent download clients here — connect them in Mycelium Admin for bulk import, and use Seerr webhooks for ongoing requests.

## Requirements

- Docker + Docker Compose v2
- TorBox Essential or Pro API key
- TMDB Read Access Token (free)
- Legal content only; comply with TorBox terms

## ZimaOS install

SSH into your ZimaOS box:

```bash
git clone <this-repo>
cd mycelium-media-stack
TORBOX_API_KEY="your-key" TMDB_API_KEY="your-tmdb-token" bash install-zimaos.sh
```

Default install path: `/DATA/AppData/mycelium-media-stack`

## Unraid install

Open the Unraid terminal (or User Scripts):

```bash
git clone <this-repo>
cd mycelium-media-stack
TORBOX_API_KEY="your-key" TMDB_API_KEY="your-tmdb-token" bash install-unraid.sh
```

Default install path: `/mnt/user/appdata/mycelium-media-stack`

The Unraid installer also adds a **User Scripts** helper if that plugin is installed.

## Management

```bash
cd <install-dir>
./manage.sh start|stop|restart|status|logs|update|urls|claim-plex
```

## Post-install checklist

1. Open `http://<your-ip>:8088` and complete the Mycelium setup wizard.
2. Claim Plex: get a token from https://www.plex.tv/claim/, set `PLEX_CLAIM` in `.env`, run `./manage.sh restart plex`.
3. In Plex, add libraries pointing at `/plex-media` (Movies and TV).
4. Configure Seerr:
   - Connect Plex at `http://plex:32400`
   - Connect Radarr `http://radarr:7878` and Sonarr `http://sonarr:8989`
   - Webhook: `http://mycelium:8088/webhook` with header `X-Webhook-Secret: <from .env>`
5. In Mycelium Admin → Integration, add Radarr/Sonarr for bulk library import.

## Spore notes

- Spore is **experimental**. Best results on Linux/desktop Plex clients.
- Android TV / Shield often bypass the transcoder wrapper (see [Mycelium discussion #37](https://github.com/corveck79/mycelium/discussions/37)).
- The installer patches the upstream Spore wrapper to call `http://mycelium:8088` instead of `127.0.0.1` so Plex can reach Mycelium on a Docker bridge network.

## Uninstall

```bash
cd <install-dir>
./manage.sh uninstall
rm -rf <install-dir>   # optional: removes configs and library stubs
```

## Files

```
mycelium-media-stack/
├── install-zimaos.sh
├── install-unraid.sh
├── manage.sh
├── lib/common.sh
└── README.md
```

`docker-compose.yml` and `.env` are generated in the install directory at install time.
