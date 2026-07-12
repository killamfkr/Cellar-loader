# Plex + Mycelium Spore image

Extends `lscr.io/linuxserver/plex` with the Spore transcoder wrapper pre-installed.
No runtime downloads — the wrapper is copied into the image at build time.

## Build

```bash
docker build -t ghcr.io/killamfkr/plex-spore:latest .
```

## Publish

GitHub Actions builds and pushes to `ghcr.io/killamfkr/plex-spore:latest` on changes to this folder.

## How it works

On container start, `entrypoint.sh` replaces Plex Transcoder with the patched Spore wrapper
that redirects playback to `http://mycelium:8088/spore-stream/<token>`.
