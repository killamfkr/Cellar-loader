# Mycelium — ZimaOS / CasaOS installs

Self-contained compose files for [corveck79/mycelium](https://github.com/corveck79/mycelium). No `.env` files.

## Mycelium + Plex (recommended)

One import — Mycelium and Plex Spore together.

```
https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/casaos/docker-compose.plex.yml
```

### Install

1. Create folders:
   ```bash
   mkdir -p /DATA/AppData/mycelium-plex/{mycelium,plex,plex-media/movies,plex-media/tv}
   ```

2. **+** → **Install a customized app** → **Import** → paste `docker-compose.plex.yml`

3. Set before **Install**:

   | Variable | Example |
   |----------|---------|
   | `TORBOX_API_KEY` | your TorBox key |
   | `TMDB_API_KEY` | `eyJhbGciOi...` |
   | `CATBOX_HOST` | `http://192.168.1.50:8088` |

4. **Mycelium:** `http://<NAS-IP>:8088` — setup wizard
5. **Plex:** `http://<NAS-IP>:32400/web` — add libraries at `/plex-media/movies` and `/plex-media/tv`

Optional: set `PLEX_CLAIM` from [plex.tv/claim](https://www.plex.tv/claim) before first Plex start.

---

## Mycelium only (Jellyfin)

```
https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/casaos/docker-compose.yml
```

Point Jellyfin at `/DATA/AppData/mycelium-plex/plex-media` or `/DATA/Media/mycelium` depending on which compose you use.

---

## Plex image not found?

```bash
git clone https://github.com/killamfkr/Cellar-loader.git
cd Cellar-loader/mycelium-media-stack/images/plex-spore
docker build -t ghcr.io/killamfkr/plex-spore:latest .
```

---

## Troubleshooting

- **Failed to start** — validate in Compose Toolbox; check folders exist
- **Plex empty library** — wait for Mycelium to add content; libraries must use `/plex-media` paths inside Plex
- **Permissions** — `sudo chown -R 1000:1000 /DATA/AppData/mycelium-plex`
