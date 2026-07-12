#!/usr/bin/env python3
"""Rebuild Catbox virtual_items + proxy .strm URLs from legacy TorBox CDN strms.

Use when .strm files exist but virtual_items is empty (DB reset) or strms contain
direct CDN URLs instead of http://host:8088/stream/<token>.

Run inside Mycelium:
  docker compose exec -T -w /app mycelium python3 /app/catbox-rebuild.py
"""
from __future__ import annotations

import sys
from pathlib import Path

import config
import db
import settings
import strm_generator
import torbox as torbox_mod

TOKEN_MARKERS = ("/stream/", "/spore-stream/")


def _is_proxy_strm(path: Path) -> bool:
    try:
        text = path.read_text(encoding="utf-8").strip().lower()
    except OSError:
        return False
    return any(m in text for m in TOKEN_MARKERS)


def _classify_strms(media: Path) -> tuple[int, int]:
    proxy = cdn = 0
    for strm in media.rglob("*.strm"):
        if _is_proxy_strm(strm):
            proxy += 1
        else:
            cdn += 1
    return proxy, cdn


def _rewrite_strms_via_torbox() -> dict:
    """Force process_torrent to rewrite existing .strm files with Catbox proxy URLs."""
    settings.set("CATBOX_MODE", True)
    config.CATBOX_MODE = True

    orig_exists = Path.exists

    def _strm_missing(self: Path) -> bool:
        if str(self).endswith(".strm") and str(self).startswith(str(config.MEDIA_PATH)):
            return False
        return orig_exists(self)

    Path.exists = _strm_missing  # type: ignore[method-assign]

    scanned = imported = failed = 0
    try:
        items = torbox_mod.list_torrents(force_refresh=True)
        for item in items:
            if not torbox_mod._is_ready(item):
                continue
            scanned += 1
            try:
                n = strm_generator.process_torrent(item)
                if n:
                    imported += n
            except Exception as exc:
                print(f"WARN torrent {item.get('id')} {item.get('name')!r}: {exc}")
                failed += 1
    finally:
        Path.exists = orig_exists  # type: ignore[method-assign]

    return {"scanned": scanned, "imported": imported, "failed": failed}


def main() -> int:
    media = Path(config.MEDIA_PATH)
    if not media.is_dir():
        print(f"MEDIA_PATH missing: {media}")
        return 1

    proxy_before, cdn_before = _classify_strms(media)
    virtual_before = len(db.get_all_virtual_items())

    print("=== Catbox rebuild ===")
    print(f"MEDIA_PATH: {media}")
    print(f"virtual_items before: {virtual_before}")
    print(f".strm with proxy token URL: {proxy_before}")
    print(f".strm with legacy CDN URL: {cdn_before}")

    if cdn_before == 0 and virtual_before > 0:
        print("Nothing to rebuild — strms already use Catbox proxy URLs.")
        return 0

    if cdn_before == 0 and virtual_before == 0:
        print("No legacy CDN strms and no virtual_items — run TorBox library scan in Mycelium Admin.")
        return 1

    print("\nRewriting .strm files from TorBox library (registers virtual_items) ...")
    stats = _rewrite_strms_via_torbox()
    print(stats)

    proxy_after, cdn_after = _classify_strms(media)
    virtual_after = len(db.get_all_virtual_items())

    print(f"\nvirtual_items after: {virtual_after}")
    print(f".strm with proxy token URL: {proxy_after}")
    print(f".strm with legacy CDN URL: {cdn_after}")

    if virtual_after == 0:
        print("ERROR: still no virtual_items — check TorBox API key and Mycelium logs.")
        return 1

    if cdn_after > 0:
        print(f"WARNING: {cdn_after} .strm still on CDN URLs (no TorBox match).")

    print("\nNext: python3 /app/spore-backfill.py  (or ./manage.sh sync-plex)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
