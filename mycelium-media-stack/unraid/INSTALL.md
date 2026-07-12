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
./manage.sh logs mycelium
```

1. Open **Mycelium** — finish the wizard at `http://192.168.0.100:8088`
2. Open **Plex** — `http://192.168.0.100:32400/web`, add libraries at `/plex-media/movies` and `/plex-media/tv`
3. Configure **Seerr** — use `http://192.168.0.100` for all service URLs; webhook secret is in `.stack-env`

## Optional env vars

| Variable | Default |
|----------|---------|
| `HOST_IP` | `192.168.0.100` |
| `PUID` / `PGID` | `99` / `100` |
| `PLEX_CLAIM` | empty |
| `WEBHOOK_SECRET` | auto-generated |

## Different IP?

```bash
HOST_IP=192.168.1.50 TORBOX_API_KEY=... TMDB_API_KEY=... bash setup.sh
```
