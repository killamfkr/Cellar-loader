# Mycelium + Spore + Plex + *arr

TorBox media stack with separate compose files per container. No `.env` files.

## ZimaOS

Each app is imported individually as a ZimaOS Custom App.

| Folder | Service |
|--------|---------|
| [`zimaos/network/`](zimaos/network/) | Shared Docker network (install first) |
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

Same layout under [`unraid/`](unraid/) — see [`unraid/INSTALL.md`](unraid/INSTALL.md).

## Plex Spore image

Built from [`images/plex-spore/`](images/plex-spore/). Published as `ghcr.io/killamfkr/plex-spore:latest` via GitHub Actions. Spore wrapper is included in the image — no wget at startup.

## Notes

- Mycelium handles streaming; Radarr/Sonarr are for bulk import, not download clients.
- All containers join the external `mycelium-media` network.
- Stream only content you have the right to access.
