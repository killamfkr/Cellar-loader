# Install Mycelium + Spore + Plex + *arr on ZimaOS

This guide installs the full stack as a **ZimaOS Custom App** using one Docker Compose file. No SSH required unless you prefer the terminal helper script.

## What you get

| App | Port | URL |
|-----|------|-----|
| **Mycelium** (main) | 8088 | `http://<ZIMAOS-IP>:8088` |
| Plex | 32400 | `http://<ZIMAOS-IP>:32400/web` |
| Seerr | 5055 | `http://<ZIMAOS-IP>:5055` |
| Radarr | 7878 | `http://<ZIMAOS-IP>:7878` |
| Sonarr | 8989 | `http://<ZIMAOS-IP>:8989` |
| Prowlarr | 9696 | `http://<ZIMAOS-IP>:9696` |

Mycelium handles TorBox grabs and streaming (Catbox mode). Radarr/Sonarr are for list management and bulk import — not download clients.

---

## Before you start

Gather these:

| Item | Where to get it |
|------|-----------------|
| **TorBox API key** | [torbox.app](https://torbox.app) → Settings → API (Essential or Pro) |
| **TMDB token** | [themoviedb.org/settings/api](https://www.themoviedb.org/settings/api) → API Read Access Token (starts with `eyJ`) |
| **ZimaOS IP** | ZimaOS dashboard or your router — e.g. `192.168.1.50` |
| **Webhook secret** | Any random string you make up — e.g. `my-secret-abc123` |

Optional later:

| Item | Where to get it |
|------|-----------------|
| **Plex claim token** | [plex.tv/claim](https://www.plex.tv/claim) (expires in ~4 minutes) |

---

## Step 1 — Prepare folders (recommended)

SSH into ZimaOS **or** use the terminal app, then run:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/killamfkr/Cellar-loader/cursor/mycelium-spore-install-scripts-e843/mycelium-media-stack/zimaos/prepare.sh)"
```

Or create folders manually:

```bash
mkdir -p /DATA/AppData/mycelium-media-stack/{mycelium,plex-media/movies,plex-media/tv,plex,prowlarr,radarr,sonarr,seerr}
```

---

## Step 2 — Import the Compose file

1. Sign in to **ZimaOS**.
2. Click the **+** icon (top right) → **Install a customized app**.
3. Click **Import** (top right of the popup).
4. Open the **Docker Compose** tab.
5. Paste the contents of [`docker-compose.yml`](./docker-compose.yml) from this folder.

   **Or** open the raw file from GitHub:

   ```
   https://raw.githubusercontent.com/killamfkr/Cellar-loader/cursor/mycelium-spore-install-scripts-e843/mycelium-media-stack/zimaos/docker-compose.yml
   ```

6. Click **Submit**.

> **Tip:** If validation fails, open **Zima Apps → Compose Toolbox**, paste the YAML there first — it shows syntax errors (common issue: tabs instead of spaces).

---

## Step 3 — Set environment variables

Before clicking **Install**, review these fields in the app settings:

| Variable | Example | Required |
|----------|---------|----------|
| `TORBOX_API_KEY` | `your-torbox-key` | Yes |
| `TMDB_API_KEY` | `eyJhbGciOi...` | Yes |
| `CATBOX_HOST` | `http://192.168.1.50:8088` | Yes — use **your** ZimaOS IP |
| `WEBHOOK_SECRET` | `my-random-secret` | Yes |
| `PLEX_CLAIM` | *(leave blank initially)* | No |
| `SEERR_API_KEY` | *(leave blank initially)* | No |
| `PUID` / `PGID` | Usually `1000` / `1000` | Auto-filled |

Check volume paths all point under `/DATA/AppData/mycelium-media-stack/`.

---

## Step 4 — Install

1. Click **Install**.
2. Wait for images to download (first install can take 5–15 minutes).
3. Open **Mycelium** from the dashboard tile (port 8088).

---

## Step 5 — Mycelium setup wizard

1. Go to `http://<ZIMAOS-IP>:8088`.
2. Complete the wizard:
   - TorBox API key → **Test**
   - TMDB token → **Test**
   - Enable **Catbox mode**
   - Set Catbox host to `http://<ZIMAOS-IP>:8088`
3. Create your admin account.

---

## Step 6 — Plex + Spore

1. Get a claim token from [plex.tv/claim](https://www.plex.tv/claim).
2. In ZimaOS, edit the app → set `PLEX_CLAIM` → save → restart the **plex** container.
3. Open `http://<ZIMAOS-IP>:32400/web` and sign in.
4. Add libraries:
   - **Movies** → folder `/plex-media/movies` (or `/plex-media`)
   - **TV Shows** → folder `/plex-media/tv`

Spore writes stub files into `/plex-media` when Mycelium adds content.

> Spore is **experimental**. Best on Linux/desktop Plex. Android TV / Shield may not work.

---

## Step 7 — Seerr (requests)

1. Open `http://<ZIMAOS-IP>:5055`.
2. Connect **Plex**: URL `http://plex:32400` (Docker name, not your LAN IP).
3. Connect **Radarr**: `http://radarr:7878` + API key from Radarr → Settings → General.
4. Connect **Sonarr**: `http://sonarr:8989` + API key.
5. **Webhook** (Settings → Notifications → Webhook):
   - URL: `http://mycelium:8088/webhook`
   - Header: `X-Webhook-Secret: <your WEBHOOK_SECRET>`
6. Copy Seerr API key → add to `SEERR_API_KEY` in ZimaOS app settings → restart **mycelium**.

---

## Step 8 — Radarr / Sonarr (bulk import)

In **Mycelium Admin** → Integrations:

- Radarr URL: `http://radarr:7878` + API key
- Sonarr URL: `http://sonarr:8989` + API key

Use **Bulk import** to pull existing monitored libraries into Mycelium.

For ongoing requests, use Mycelium Discover or Seerr — not Radarr/Sonarr download clients.

---

## Step 9 — Prowlarr (optional indexers)

1. Open `http://<ZIMAOS-IP>:9696`.
2. Add indexers; Byparr (port 8191) handles Cloudflare-protected sites automatically.
3. Mycelium primarily uses Torrentio/Zilean — Prowlarr is optional for manual/advanced use.

---

## Troubleshooting

### Import / Submit does nothing

- Use **Compose Toolbox** to validate YAML (no tabs — only spaces).
- Delete stale folder: `/DATA/AppData/compose/mycelium-media-stack` via File Manager, then retry.

### Mycelium won't start

```bash
docker logs mycelium --tail 50
```

Check `CATBOX_HOST` uses your real LAN IP, not `localhost`.

### Plex library empty

- Confirm Mycelium has added content (check Admin → Library).
- Plex library path must be `/plex-media` inside the container.
- Restart plex after first Mycelium add.

### Permission errors

```bash
sudo chown -R 1000:1000 /DATA/AppData/mycelium-media-stack
```

Match PUID/PGID in the app settings (`id` in terminal shows your values).

### Edit compose after install

App Store installs limit editing. For full control, re-import via **Compose Toolbox** or **Dockge** using the same `/DATA/AppData/mycelium-media-stack` paths.

---

## Uninstall

1. ZimaOS → remove the **Mycelium Media Stack** app.
2. Optionally delete data: `/DATA/AppData/mycelium-media-stack`

---

## Legal

Only stream content you have the right to access. Comply with TorBox terms and applicable copyright law.
