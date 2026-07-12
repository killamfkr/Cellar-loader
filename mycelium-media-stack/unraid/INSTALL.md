# Unraid — one-script setup

Preconfigured for **192.168.0.100**. Installs Mycelium, Plex Spore, Seerr, Radarr, Sonarr, Prowlarr, and Byparr in one command.

## Run

Unraid terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/unraid/setup.sh | \
  TORBOX_API_KEY="your-torbox-key" \
  TMDB_API_KEY="your-tmdb-token" \
  bash
```

Or from a cloned repo:

```bash
cd /mnt/user/appdata
git clone https://github.com/killamfkr/Cellar-loader.git
TORBOX_API_KEY="your-key" TMDB_API_KEY="your-token" bash Cellar-loader/mycelium-media-stack/unraid/setup.sh
```

## What it does

1. Creates `/mnt/user/appdata/mycelium-media-stack/`
2. Writes `docker-compose.yml` with `192.168.0.100` baked in
3. Pulls (or builds) the Plex Spore image
4. Starts all containers
5. Writes `manage.sh` for day-to-day control

## After install

```bash
cd /mnt/user/appdata/mycelium-media-stack
./manage.sh urls
./manage.sh status
```

### Refresh `manage.sh` (existing installs)

If `./manage.sh` only shows `{start|stop|restart|status|logs|urls|update}`, update it:

```bash
cd /mnt/user/appdata/mycelium-media-stack
curl -fsSL https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/unraid/manage.sh -o manage.sh
chmod +x manage.sh
```

Or:

```bash
curl -fsSL https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/unraid/setup.sh | bash -s -- --refresh-scripts
```

Then run `./manage.sh sync-plex`.

1. Open **Mycelium** — finish the wizard at `http://192.168.0.100:8088`
2. Open **Plex** — `http://192.168.0.100:32400/web`, add libraries at `/plex-media/movies` and `/plex-media/tv`
3. Configure **Radarr** — `http://192.168.0.100:7878`
   - Settings → Media Management → add root folder **`/movies`**
   - Do **not** add a download client — Mycelium handles grabs
4. Configure **Sonarr** — `http://192.168.0.100:8989`
   - Settings → Media Management → add root folder **`/tv`**
   - Do **not** add a download client
5. **Mycelium Admin → Integrations** — connect Radarr and Sonarr (bulk import from lists)
6. Configure **Seerr** — use `http://192.168.0.100` for all service URLs; webhook secret is in `.stack-env`

### Seerr webhook (request → Mycelium)

In Seerr: **Settings → Notifications → Webhook**

| Field | Value |
|-------|-------|
| Webhook URL | `http://192.168.0.100:8088/webhook?secret=YOUR_SECRET` |
| Triggers | Enable **Request Approved** (minimum) |

Get `YOUR_SECRET` from either:

```bash
cd /mnt/user/appdata/mycelium-media-stack
grep WEBHOOK_SECRET .stack-env
```

or **Mycelium Admin → Settings → Integration Endpoints** (must match).

Verify from Unraid terminal:

```bash
cd /mnt/user/appdata/mycelium-media-stack
./manage.sh test-webhook
```

A successful test returns HTTP 200 with `"status":"ignored"` (Mycelium ignores test pings — that is normal).

Also in **Mycelium Admin → Settings**, set:

- `SEERR_URL` = `http://192.168.0.100:5055`
- `SEERR_API_KEY` = from Seerr → Settings → General → API Key

Restart Mycelium after changing those.

### After requesting in Seerr

The webhook only **notifies** Mycelium. A movie appears in Plex only after the full chain below.

| Step | What happens | You check |
|------|----------------|-----------|
| 1 | Seerr approves request → webhook fires `MEDIA_APPROVED` | Seerr webhook has **Request Approved** enabled |
| 2 | Mycelium fetches request details from Seerr API | `SEERR_API_KEY` set in Mycelium Settings |
| 3 | Mycelium finds a TorBox-cached release and writes a Spore stub `.mkv` | `./manage.sh check-media` |
| 4 | Plex scans `/plex-media/movies` | `./manage.sh plex-scan` or Scan in Plex UI |
| 5 | Seerr syncs Plex libraries | Seerr → Settings → Plex → **Sync Libraries** |

Radarr will stay on "missing" — that is normal. Mycelium does the grab, not Radarr.

### Mycelium library vs Plex library

Mycelium keeps `.strm` files internally at `mycelium/media/movies/` on the host. Plex cannot read those — it needs **Spore stub `.mkv` files** in `plex-media/movies/`.

If a title shows in Mycelium but `plex-media/movies/` is empty, generate the stubs:

```bash
cd /mnt/user/appdata/mycelium-media-stack
./manage.sh sync-plex
```

`sync-plex` runs spore-backfill, fixes permissions, mirrors `.strm` files as a fallback if stub creation fails, then triggers a Plex scan.

**Note:** Mycelium has **no “Spore enabled” toggle in Admin → Settings**. Spore is controlled by `docker-compose.yml` env vars. Run `./manage.sh check-spore` to verify.

```bash
cd /mnt/user/appdata/mycelium-media-stack
./manage.sh check-media    # compare strm vs stub counts
./manage.sh check-spore    # verify SPORE_ENABLED in compose + container
./manage.sh sync-plex      # backfill stubs + plex scan (preferred)
```

In **Mycelium Admin** (`http://192.168.0.100:8088/admin`), confirm the request shows as added (not failed/wanted).

## Request in Seerr but movie not in Plex

1. **Webhook triggers** — Seerr → Notifications → Webhook → enable **Request Approved** and **Request Auto-Approved** (not just Test).
2. **`SEERR_API_KEY` missing** — Mycelium cannot look up request details without it.
   - Seerr → Settings → General → copy API Key
   - Mycelium Admin → Settings → paste `SEERR_API_KEY`, set `SEERR_URL` = `http://192.168.0.100:5055`
   - `docker compose restart mycelium`
3. **In Mycelium but not in `plex-media/`** — run `./manage.sh spore-backfill` then `./manage.sh plex-scan`. Mycelium stores `.strm` files separately; Plex needs Spore `.mkv` stubs.
4. **No TorBox cached release** — Mycelium logs `wanted` or `failed`. Try another title or check TorBox API key.
5. **Wrong Plex library path** — libraries must point to `/plex-media/movies` and `/plex-media/tv` inside Plex.
6. **Seerr still shows "Processing"** — until Plex has the movie and you **Sync Libraries** in Seerr.

## Spore backfill created 0 stubs

The Mycelium **Library** page lists database requests — not files in `plex-media/`. Zero stubs usually means one of:

| Diagnose output | Fix |
|-----------------|-----|
| `config.SPORE_ENABLED = False` | Add `SPORE_ENABLED: "true"` to `docker-compose.yml` → `docker compose up -d mycelium`. There is **no Spore toggle in Mycelium Settings UI**. |
| `.strm files on disk: 0` | No media files yet. Mycelium Admin → **TorBox library scan**, or re-request the title |
| `virtual_items in DB: 0` | Request never fully processed — check Mycelium Admin for `failed` / `wanted` status |
| `plex-media writable: False` | Run `./manage.sh fix-perms` or `./manage.sh sync-plex` (retries as root) |

Verify Spore env:

```bash
cd /mnt/user/appdata/mycelium-media-stack
./manage.sh check-spore
```

Run the diagnostic backfill (prints counts before creating stubs):

```bash
cd /mnt/user/appdata/mycelium-media-stack
curl -fsSL https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/unraid/spore-backfill.py -o spore-backfill.py
docker compose cp spore-backfill.py mycelium:/app/spore-backfill.py
docker compose exec -T -w /app mycelium python3 /app/spore-backfill.py
```

Read the `=== Mycelium Spore diagnose ===` section — it tells you which step failed.

Required in `docker-compose.yml` under the `mycelium` service (not in the Settings UI):

```yaml
SPORE_ENABLED: "true"
SPORE_MEDIA_PATH: /data/plex-media
CATBOX_MODE: "true"
CATBOX_LAZY_ADD: "true"
```

## Zilean is down

This stack does **not** run a separate Zilean container. If the dashboard shows **Zilean down**, external Zilean was enabled during setup with a URL that does not exist.

**Torrentio alone is enough.** Fix in Mycelium Admin → **Settings**:

1. **Zilean enabled** = off (or clear **Zilean URL**)
2. Save, then restart:

```bash
cd /mnt/user/appdata/mycelium-media-stack
docker compose restart mycelium
```

Or add to `docker-compose.yml` under `mycelium`: `ZILEAN_ENABLED: "false"`, then `docker compose up -d mycelium`.

**Optional — built-in Zilean (no extra container):** Settings → **Zilean mode** = `native`, enable Zilean, clear external URL, then Admin → **Zilean** → **Sync** (first sync can take several minutes).

## Webhook test failed in Seerr

1. **Secret missing or wrong** — most common. Use the full URL with `?secret=` (Seerr cannot rely on headers alone on all versions).
2. **Secret mismatch** — `.stack-env` must match Mycelium Admin → Integration Endpoints. If they differ, copy the value from Mycelium admin and update Seerr.
3. **Mycelium not reachable** — run `./manage.sh test-webhook` from the install dir. If that fails, check `docker compose ps` and `docker compose logs mycelium`.
4. **Wrong URL** — must be `http://192.168.0.100:8088/webhook` (not `/webhooks`, not `https://`, not `localhost` from another device).

Check Mycelium logs while testing in Seerr:

```bash
docker compose logs -f mycelium | grep -i webhook
```

`Rejected webhook with bad/missing secret` = fix the `?secret=` value.

## Plex: "You do not have access to this server"

Plex must be **claimed** to your Plex account. The setup script does not do this automatically.

### Quick fix (Unraid terminal)

```bash
cd /mnt/user/appdata/mycelium-media-stack
./manage.sh claim-plex
```

1. Open https://www.plex.tv/claim/ — copy the token (expires in ~4 minutes)
2. Paste it when prompted
3. Open **http://192.168.0.100:32400/web** from a device on your **same LAN**
4. Sign in with the **same Plex account** you used to get the claim token

### Manual fix

```bash
docker stop plex
# Edit and remove PlexOnlineToken, PlexOnlineUsername, PlexOnlineEmail, PlexOnlineHome from:
# /mnt/user/appdata/mycelium-media-stack/plex/Library/Application Support/Plex Media Server/Preferences.xml
PLEX_CLAIM=your-token-from-plex-tv-claim docker compose up -d plex
```

### Important

- Use **http://192.168.0.100:32400/web** directly — not app.plex.tv for first claim
- Claim token only works **once** and only if Preferences.xml has no valid token
- If still broken: `docker stop plex`, delete the `plex` config folder, re-run `./manage.sh claim-plex` (you will lose Plex settings)

## Radarr/Sonarr: "folder does not exist"

Older installs did not mount media paths into Radarr/Sonarr. Update and recreate:

```bash
cd /mnt/user/appdata/mycelium-media-stack
curl -fsSL https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/unraid/setup.sh -o /tmp/setup.sh
# Re-run only if you need a fresh compose — or edit docker-compose.yml manually:
#   radarr: add  - ./plex-media/movies:/movies
#   sonarr: add  - ./plex-media/tv:/tv
docker compose up -d radarr sonarr
```

Then add root folders **`/movies`** (Radarr) and **`/tv`** (Sonarr).

## Optional env vars

| Variable | Default |
|----------|---------|
| `HOST_IP` | `192.168.0.100` |
| `PUID` / `PGID` | `99` / `100` |
| `PLEX_CLAIM` | empty |
| `WEBHOOK_SECRET` | auto-generated |
| `SEERR_API_KEY` | empty (set from Seerr → General → API Key) |

## Different IP?

```bash
HOST_IP=192.168.1.50 TORBOX_API_KEY=... TMDB_API_KEY=... bash setup.sh
```
