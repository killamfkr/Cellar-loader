# ZimaOS install guide — Mycelium media stack

Each container is a **separate Custom App**. No `.env` files — set variables in the ZimaOS UI when you install each app.

Plex uses a pre-built image (`ghcr.io/killamfkr/plex-spore`) with Spore baked in — nothing downloads at container start.

---

## Before you start

| Item | Where |
|------|-------|
| TorBox API key | [torbox.app](https://torbox.app) → Settings → API |
| TMDB token | [themoviedb.org/settings/api](https://www.themoviedb.org/settings/api) (starts with `eyJ`) |
| ZimaOS IP | e.g. `192.168.1.50` |
| Webhook secret | Any random string you choose |

---

## Step 0 — Prepare folders (optional, SSH)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/zimaos/prepare.sh)"
```

---

## Step 1 — Import each compose (in order)

For every app: **+** → **Install a customized app** → **Import** → **Docker Compose** → paste file → **Submit** → **Install**.

| Order | Compose file | Port | Notes |
|-------|--------------|------|-------|
| 1 | [`network/docker-compose.yml`](network/docker-compose.yml) | — | Creates shared `mycelium-media` network |
| 2 | [`mycelium/docker-compose.yml`](mycelium/docker-compose.yml) | 8088 | Set `TORBOX_API_KEY`, `TMDB_API_KEY`, `CATBOX_HOST`, `WEBHOOK_SECRET` |
| 3 | [`plex/docker-compose.yml`](plex/docker-compose.yml) | 32400 | Uses `ghcr.io/killamfkr/plex-spore` image |
| 4 | [`byparr/docker-compose.yml`](byparr/docker-compose.yml) | 8191 | Optional but recommended |
| 5 | [`prowlarr/docker-compose.yml`](prowlarr/docker-compose.yml) | 9696 | |
| 6 | [`radarr/docker-compose.yml`](radarr/docker-compose.yml) | 7878 | |
| 7 | [`sonarr/docker-compose.yml`](sonarr/docker-compose.yml) | 8989 | |
| 8 | [`seerr/docker-compose.yml`](seerr/docker-compose.yml) | 5055 | Install after Plex + *arr |

Raw URLs (replace path as needed):

```
https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/zimaos/network/docker-compose.yml
https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/zimaos/mycelium/docker-compose.yml
https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/zimaos/plex/docker-compose.yml
...
```

### Mycelium variables (set in ZimaOS UI)

| Variable | Example |
|----------|---------|
| `TORBOX_API_KEY` | your key |
| `TMDB_API_KEY` | `eyJhbGciOi...` |
| `CATBOX_HOST` | `http://192.168.1.50:8088` |
| `WEBHOOK_SECRET` | `my-random-secret` |

---

## Step 2 — Mycelium wizard

Open `http://<ZIMAOS-IP>:8088` and complete the setup wizard.

---

## Step 3 — Plex

1. Optional: set `PLEX_CLAIM` in the Plex app settings, restart container.
2. Open `http://<ZIMAOS-IP>:32400/web`.
3. Add libraries: `/plex-media/movies` and `/plex-media/tv`.

---

## Step 4 — Seerr

1. Open `http://<ZIMAOS-IP>:5055`.
2. Connect Plex: `http://plex:32400`
3. Connect Radarr: `http://radarr:7878` + API key
4. Connect Sonarr: `http://sonarr:8989` + API key
5. Webhook: `http://mycelium:8088/webhook` + header `X-Webhook-Secret: <your secret>`
6. Copy Seerr API key → add to Mycelium app settings as `SEERR_API_KEY` → restart Mycelium

---

## Step 5 — Mycelium ↔ Radarr/Sonarr

In Mycelium Admin → Integrations, add Radarr/Sonarr URLs for **bulk import only** (not download clients).

---

## Plex Spore image

Plex pulls `ghcr.io/killamfkr/plex-spore:latest` — Spore wrapper is pre-installed in the image.

If the image is not available yet, build locally:

```bash
git clone https://github.com/killamfkr/Cellar-loader.git
cd Cellar-loader/mycelium-media-stack/images/plex-spore
docker build -t ghcr.io/killamfkr/plex-spore:latest .
```

---

## Troubleshooting

**Containers can't reach each other** — install the Network app first, or run `docker network create mycelium-media`.

**Import fails** — use Compose Toolbox to validate YAML (spaces only, no tabs).

**Permission errors** — `sudo chown -R 1000:1000 /DATA/AppData/mycelium-media-stack`

---

## Legal

Stream only content you have the right to access.
