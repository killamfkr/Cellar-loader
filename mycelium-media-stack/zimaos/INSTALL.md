# ZimaOS install guide — Mycelium media stack

Each container is a **separate Custom App**. No `.env` files — set variables in the ZimaOS UI.

> **No network app required.** Older guides used a `sleep infinity` holder container — that breaks on ZimaOS. Each app uses `network_mode: bridge` and your **LAN IP** for cross-service URLs.

---

## Step 0 — Prepare folders (SSH, once)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/zimaos/prepare.sh)"
```

---

## Step 1 — Import each compose

**+** → **Install a customized app** → **Import** → **Docker Compose** → paste → **Submit** → **Install**

| Order | File | Port |
|-------|------|------|
| 1 | [`mycelium/docker-compose.yml`](mycelium/docker-compose.yml) | 8088 |
| 2 | [`plex/docker-compose.yml`](plex/docker-compose.yml) | 32400 |
| 3 | [`byparr/docker-compose.yml`](byparr/docker-compose.yml) | 8191 |
| 4 | [`prowlarr/docker-compose.yml`](prowlarr/docker-compose.yml) | 9696 |
| 5 | [`radarr/docker-compose.yml`](radarr/docker-compose.yml) | 7878 |
| 6 | [`sonarr/docker-compose.yml`](sonarr/docker-compose.yml) | 8989 |
| 7 | [`seerr/docker-compose.yml`](seerr/docker-compose.yml) | 5055 |

### Required variables

**Mycelium:**

| Variable | Example |
|----------|---------|
| `TORBOX_API_KEY` | your TorBox key |
| `TMDB_API_KEY` | `eyJhbGciOi...` |
| `CATBOX_HOST` | `http://192.168.1.50:8088` |
| `WEBHOOK_SECRET` | any random string |
| `SEERR_URL` | `http://192.168.1.50:5055` |

**Plex Spore:**

| Variable | Example |
|----------|---------|
| `MYCELIUM_URL` | `http://192.168.1.50:8088` |

Use your real ZimaOS LAN IP everywhere — not `localhost`, not container names.

---

## Step 2 — Mycelium wizard

Open `http://<ZIMAOS-IP>:8088` and complete setup.

---

## Step 3 — Plex

1. Optional: set `PLEX_CLAIM` from [plex.tv/claim](https://www.plex.tv/claim), restart Plex.
2. Add libraries: `/plex-media/movies` and `/plex-media/tv`.

---

## Step 4 — Radarr & Sonarr

These are **list managers** for Mycelium bulk import — not download clients.

| App | Root folder | Download client |
|-----|-------------|-----------------|
| Radarr | `/movies` | None |
| Sonarr | `/tv` | None |

In each app: **Settings → Media Management → Root Folders → Add**.

Then in **Mycelium Admin → Integrations**, connect Radarr and Sonarr.

---

## Step 5 — Seerr

Use **LAN IPs** (not docker names) when connecting services:

| Setting | Value |
|---------|-------|
| Plex | `http://192.168.1.50:32400` |
| Radarr | `http://192.168.1.50:7878` |
| Sonarr | `http://192.168.1.50:8989` |

### Webhook → Mycelium

**Settings → Notifications → Webhook**

| Field | Value |
|-------|-------|
| Webhook URL | `http://192.168.1.50:8088/webhook?secret=YOUR_SECRET` |
| Triggers | Enable **Request Approved** |

`YOUR_SECRET` must match **Mycelium Admin → Settings → Integration Endpoints** (same value as `WEBHOOK_SECRET` in the Mycelium app).

Test from SSH:

```bash
curl -sS -X POST "http://192.168.1.50:8088/webhook?secret=YOUR_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"notification_type":"TEST_NOTIFICATION"}'
```

Expected: HTTP 200, `{"status":"ignored","reason":"test notification"}` — Seerr should then show the test as sent.

Also set in **Mycelium Admin → Settings**:

- `SEERR_URL` = `http://192.168.1.50:5055`
- `SEERR_API_KEY` = from Seerr → Settings → General

---

## Troubleshooting

### "Failed to start compose app"

1. Open **Compose Toolbox** — validate YAML (spaces only, no tabs).
2. Delete stale folder: `/DATA/AppData/compose/<app-name>` if a previous install failed.
3. Ensure bind paths exist — run `prepare.sh`.
4. Restart Docker: `sudo systemctl restart docker`

### Plex image not found

Build locally or wait for GitHub Actions to publish:

```bash
cd mycelium-media-stack/images/plex-spore
docker build -t ghcr.io/killamfkr/plex-spore:latest .
```

### Permission errors

```bash
sudo chown -R 1000:1000 /DATA/AppData/mycelium-media-stack
```

---

## Legal

Stream only content you have the right to access.
