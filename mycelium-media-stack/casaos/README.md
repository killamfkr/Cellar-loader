# Mycelium — ZimaOS / CasaOS single-file install

One self-contained compose for [corveck79/mycelium](https://github.com/corveck79/mycelium). No `.env` file required.

## Install

1. SSH (optional) — create folders:
   ```bash
   mkdir -p /DATA/AppData/mycelium /DATA/Media/mycelium
   ```

2. ZimaOS or CasaOS → **+** → **Install a customized app** → **Import** → **Docker Compose**

3. Paste [`docker-compose.yml`](./docker-compose.yml) or this URL:
   ```
   https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/casaos/docker-compose.yml
   ```

4. Set before **Install**:

   | Variable | Example |
   |----------|---------|
   | `TORBOX_API_KEY` | your TorBox key |
   | `TMDB_API_KEY` | `eyJhbGciOi...` |
   | `CATBOX_HOST` | `http://192.168.1.50:8088` |

5. Open `http://<NAS-IP>:8088` and finish the setup wizard.

## Jellyfin

Add libraries pointing at the container path `/data/media` (host: `/DATA/Media/mycelium`).

## Optional — Seerr webhook

| Variable | Value |
|----------|-------|
| `SEERR_URL` | `http://<NAS-IP>:5055` |
| `WEBHOOK_SECRET` | any random string |

In Seerr: webhook `http://<NAS-IP>:8088/webhook` with header `X-Webhook-Secret`.

## Troubleshooting

- **Failed to start** — validate YAML in Compose Toolbox; ensure folders exist; `sudo chown -R 1000:1000 /DATA/AppData/mycelium /DATA/Media/mycelium`
- **Catbox streaming fails** — `CATBOX_HOST` must be your real LAN IP, not `localhost`

Upstream project: https://github.com/corveck79/mycelium
