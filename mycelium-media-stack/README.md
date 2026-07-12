# Mycelium + Spore + Plex + *arr

## Mycelium + Plex (ZimaOS / CasaOS)

**Single-file install** — Mycelium and Plex Spore in one compose:

| File | Purpose |
|------|---------|
| [`casaos/docker-compose.plex.yml`](casaos/docker-compose.plex.yml) | Mycelium + Plex — paste into Custom App import |
| [`casaos/docker-compose.yml`](casaos/docker-compose.yml) | Mycelium only (Jellyfin) |
| [`casaos/README.md`](casaos/README.md) | Install guide |

```
https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/casaos/docker-compose.plex.yml
```

## Full stack (ZimaOS)

Each app is imported individually as a ZimaOS Custom App.

| Folder | Service |
|--------|---------|
| [`zimaos/mycelium/`](zimaos/mycelium/) | Mycelium (Catbox + Spore) |
| [`zimaos/plex/`](zimaos/plex/) | Plex Spore image |
| [`zimaos/byparr/`](zimaos/byparr/) | Cloudflare bypass |
| [`zimaos/prowlarr/`](zimaos/prowlarr/) | Indexers |
| [`zimaos/radarr/`](zimaos/radarr/) | Movies |
| [`zimaos/sonarr/`](zimaos/sonarr/) | TV |
| [`zimaos/seerr/`](zimaos/seerr/) | Requests |

**Guide:** [`zimaos/INSTALL.md`](zimaos/INSTALL.md)

```bash
bash mycelium-media-stack/zimaos/prepare.sh   # optional folder setup
```

## Unraid

**One-script setup** (preconfigured for `192.168.0.100`):

```bash
curl -fsSL https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/unraid/setup.sh | \
  TORBOX_API_KEY="your-key" TMDB_API_KEY="your-token" bash
```

See [`unraid/INSTALL.md`](unraid/INSTALL.md).

## Plex Spore image

Built from [`images/plex-spore/`](images/plex-spore/). Published as `ghcr.io/killamfkr/plex-spore:latest` via GitHub Actions. Spore wrapper is included in the image — no wget at startup.

## Notes

- Mycelium handles streaming; Radarr/Sonarr are for bulk import, not download clients.
- Each app uses `network_mode: bridge` — use your LAN IP (not container names) for cross-service URLs.
- Stream only content you have the right to access.
