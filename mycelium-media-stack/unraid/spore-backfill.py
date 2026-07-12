#!/usr/bin/env python3
"""Generate Plex Spore stubs from Mycelium library state.

Mycelium's UI library lists requests from the DB — not necessarily files on
disk. This script diagnoses that gap and writes .mkv stubs into SPORE_MEDIA_PATH.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import config
import db
import settings
import strm_generator

TOKEN_RE = re.compile(r"/stream/([^/?#\s]+)")


def _spore_enabled() -> bool:
    return bool(settings.get("SPORE_ENABLED", config.SPORE_ENABLED))


def _spore_root() -> Path:
    return Path(settings.get("SPORE_MEDIA_PATH", config.SPORE_MEDIA_PATH))


def _token_from_strm(path: Path) -> str | None:
    try:
        text = path.read_text(encoding="utf-8").strip()
    except OSError:
        return None
    match = TOKEN_RE.search(text)
    return match.group(1) if match else None


def _strm_path_for_item(item: dict) -> Path | None:
    raw = (item.get("strm_path") or "").strip()
    if raw:
        path = Path(raw)
        if path.exists():
            return path

    token = item.get("token")
    if token:
        media = Path(config.MEDIA_PATH)
        for strm in media.rglob("*.strm"):
            found = _token_from_strm(strm)
            if found == token:
                return strm

    title = item.get("title") or ""
    imdb_id = item.get("imdb_id")
    year = item.get("year")
    media_type = item.get("media_type") or "movie"

    if media_type == "movie" and (title or imdb_id):
        folder = (
            strm_generator._canonical_movie_folder(imdb_id, title, year)
            if imdb_id
            else strm_generator._safe(title)
        )
        if folder:
            return Path(config.MEDIA_PATH) / "movies" / folder / f"{folder}.strm"

    if media_type == "series" and title:
        safe = strm_generator._safe(title)
        season = item.get("season")
        episode = item.get("episode")
        if safe and season and episode:
            ep_name = f"{safe} S{int(season):02d}E{int(episode):02d}"
            return (
                Path(config.MEDIA_PATH)
                / "series"
                / safe
                / f"Season {int(season):02d}"
                / f"{ep_name}.strm"
            )
    return None


def _stub_exists(strm_path: Path) -> bool:
    stub_dir = strm_generator._spore_stub_dir(strm_path)
    mkv = stub_dir / (strm_path.stem + ".mkv")
    minfo = stub_dir / (strm_path.stem + ".minfo")
    return mkv.exists() and minfo.exists()


def diagnose() -> None:
    media = Path(config.MEDIA_PATH)
    strms = list(media.rglob("*.strm")) if media.is_dir() else []
    virtual = db.get_all_virtual_items()
    movies = [r for r in db.get_recent(10000) if r.get("media_type") == "movie"]
    success = [r for r in movies if r.get("status") == "success"]

    print("=== Mycelium Spore diagnose ===")
    print(f"SPORE_ENABLED (effective): {_spore_enabled()}")
    print(f"SPORE_MEDIA_PATH: {_spore_root()}")
    print(f"MEDIA_PATH: {config.MEDIA_PATH}")
    print(f".strm files on disk: {len(strms)}")
    print(f"virtual_items in DB: {len(virtual)}")
    print(f"movie requests (all): {len(movies)}")
    print(f"movie requests (success): {len(success)}")
    print(f"existing stubs in plex-media: {len(list(_spore_root().rglob('*.mkv'))) if _spore_root().is_dir() else 0}")

    if not _spore_enabled():
        print("\nERROR: SPORE_ENABLED is false.")
        print("Fix: Mycelium Admin → Settings → enable Spore, or set SPORE_ENABLED=true in compose and restart.")

    if not strms and success:
        print("\nWARN: Requests show success but no .strm files exist.")
        print("Try: Mycelium Admin → Maintenance → TorBox library scan")
        print("Or request the title again after enabling CATBOX_LAZY_ADD=true")

    if not virtual and success:
        print("\nWARN: No virtual_items — catbox tokens missing. Stubs need tokens from the DB.")

    for label, path in [("movies strm dir", media / "movies"), ("plex-media movies", _spore_root() / "movies")]:
        print(f"{label}: {path} ({'exists' if path.is_dir() else 'MISSING'})")


def create_stub(strm_path: Path, item: dict) -> bool:
    token = item.get("token")
    if not token:
        token = _token_from_strm(strm_path)
    if not token:
        print(f"skip (no token): {strm_path}")
        return False
    if _stub_exists(strm_path):
        return False
    strm_generator._write_spore_stubs(
        strm_path,
        token,
        item.get("title") or strm_path.stem,
        item.get("quality"),
        item.get("size_gb"),
    )
    stub = strm_generator._spore_stub_dir(strm_path) / (strm_path.stem + ".mkv")
    if stub.exists():
        print(f"created: {stub}")
        return True
    print(f"failed (no file after write): {stub}")
    return False


def main() -> int:
    diagnose()
    print()

    if not _spore_enabled():
        return 1

    created = 0
    seen: set[str] = set()

    print("=== Phase 1: official backfill ===")
    print(strm_generator.backfill_spore_stubs())
    print()

    print("=== Phase 2: all virtual_items ===")
    for item in db.get_all_virtual_items():
        strm_path = _strm_path_for_item(item)
        if not strm_path:
            print(f"skip virtual_item (no path): token={item.get('token')} title={item.get('title')!r}")
            continue
        key = f"{item.get('token')}:{strm_path}"
        if key in seen:
            continue
        seen.add(key)
        if create_stub(strm_path, item):
            created += 1

    print()
    print("=== Phase 3: scan .strm files for tokens ===")
    media = Path(config.MEDIA_PATH)
    for strm in sorted(media.rglob("*.strm")) if media.is_dir() else []:
        token = _token_from_strm(strm)
        if not token:
            continue
        key = f"{token}:{strm}"
        if key in seen:
            continue
        seen.add(key)
        item = db.get_virtual_item(token) or {"token": token, "title": strm.stem}
        if create_stub(strm, item):
            created += 1

    print()
    print("=== Phase 4: successful movie requests ===")
    for req in db.get_recent(10000):
        if req.get("media_type") != "movie" or req.get("status") != "success":
            continue
        imdb_id = req.get("imdb_id")
        if not imdb_id:
            continue
        items = db.get_virtual_items_by_imdb(imdb_id, media_type="movie")
        if items:
            for item in items:
                strm_path = _strm_path_for_item(item)
                if not strm_path:
                    continue
                key = f"{item.get('token')}:{strm_path}"
                if key in seen:
                    continue
                seen.add(key)
                if create_stub(strm_path, item):
                    created += 1
            continue

        info_hash = (req.get("info_hash") or "").lower()
        if info_hash:
            for item in db.get_virtual_items_by_hash(info_hash):
                strm_path = _strm_path_for_item(item)
                if not strm_path:
                    continue
                key = f"{item.get('token')}:{strm_path}"
                if key in seen:
                    continue
                seen.add(key)
                if create_stub(strm_path, item):
                    created += 1

    print()
    print(f"=== Done: {created} stub(s) created ===")
    print(f"Stubs now in: {_spore_root()}")
    return 0 if created > 0 or list(_spore_root().rglob("*.mkv")) else 1


if __name__ == "__main__":
    sys.exit(main())
