#!/usr/bin/env python3
"""Generate Plex Spore stubs from Mycelium .strm files.

Mycelium keeps .strm files in /data/media. Plex reads Spore stub .mkv files
from /data/plex-media. This script mirrors the folder layout and writes stubs.

Run inside the Mycelium container:
  docker compose exec -T -w /app mycelium python3 /app/spore-backfill.py
"""
from __future__ import annotations

import re
import sys
import traceback
from pathlib import Path

import config
import db
import settings
import strm_generator

TOKEN_RE = re.compile(r"/stream/([0-9a-f]{8,32})", re.IGNORECASE)


def force_spore_settings() -> None:
    """Ensure Spore writes to the shared plex-media volume."""
    settings.set("SPORE_ENABLED", True)
    settings.set("SPORE_MEDIA_PATH", config.SPORE_MEDIA_PATH or "/data/plex-media")


def _spore_enabled() -> bool:
    return bool(settings.get("SPORE_ENABLED", config.SPORE_ENABLED))


def _spore_root() -> Path:
    return Path(settings.get("SPORE_MEDIA_PATH", config.SPORE_MEDIA_PATH))


def _token_from_strm(path: Path) -> str | None:
    try:
        text = path.read_text(encoding="utf-8").strip()
    except OSError as exc:
        print(f"read error {path}: {exc}")
        return None
    match = TOKEN_RE.search(text)
    if match:
        return match.group(1)
    print(f"no /stream/<token> in {path}: {text[:120]!r}")
    return None


def _strm_path_for_item(item: dict) -> Path | None:
    media = Path(config.MEDIA_PATH)

    raw = (item.get("strm_path") or "").strip()
    if raw:
        path = Path(raw)
        if path.exists():
            return path

    token = item.get("token")
    if token:
        for strm in media.rglob("*.strm"):
            if _token_from_strm(strm) == token:
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
            candidate = media / "movies" / folder / f"{folder}.strm"
            if candidate.exists():
                return candidate
            return candidate

    if media_type == "series" and title:
        safe = strm_generator._safe(title)
        season = item.get("season")
        episode = item.get("episode")
        if safe and season and episode:
            ep_name = f"{safe} S{int(season):02d}E{int(episode):02d}"
            candidate = media / "series" / safe / f"Season {int(season):02d}" / f"{ep_name}.strm"
            if candidate.exists():
                return candidate
            return candidate
    return None


def _stub_paths(strm_path: Path) -> tuple[Path, Path]:
    stub_dir = strm_generator._spore_stub_dir(strm_path)
    return stub_dir / (strm_path.stem + ".mkv"), stub_dir / (strm_path.stem + ".minfo")


def diagnose() -> list[Path]:
    media = Path(config.MEDIA_PATH)
    strms = list(media.rglob("*.strm")) if media.is_dir() else []
    virtual = db.get_all_virtual_items()
    movies = [r for r in db.get_recent(10000) if r.get("media_type") == "movie"]
    success = [r for r in movies if r.get("status") == "success"]
    spore_root = _spore_root()

    print("=== Mycelium Spore diagnose ===")
    print(f"SPORE_ENABLED (effective): {_spore_enabled()}")
    print(f"SPORE_MEDIA_PATH (effective): {spore_root}")
    print(f"MEDIA_PATH: {config.MEDIA_PATH}")
    print(f".strm files on disk: {len(strms)}")
    print(f"virtual_items in DB: {len(virtual)}")
    print(f"movie requests (success): {len(success)}")
    stubs = list(spore_root.rglob("*.mkv")) if spore_root.is_dir() else []
    print(f"existing stubs in plex-media: {len(stubs)}")

    for label, path in [("movies strm dir", media / "movies"), ("plex-media root", spore_root)]:
        print(f"{label}: {path} ({'exists' if path.is_dir() else 'MISSING'})")

    if strms:
        print("\nSample .strm files:")
        for strm in strms[:5]:
            print(f"  {strm}")
            try:
                print(f"    -> {strm.read_text(encoding='utf-8').strip()[:100]}")
            except OSError as exc:
                print(f"    -> read error: {exc}")

    missing = []
    for strm in strms:
        mkv, _ = _stub_paths(strm)
        if not mkv.exists():
            missing.append(strm)
    print(f"\n.strm without matching stub: {len(missing)}")
    return missing


def create_stub(strm_path: Path, item: dict) -> bool:
    token = item.get("token") or _token_from_strm(strm_path)
    if not token:
        return False

    mkv_path, minfo_path = _stub_paths(strm_path)
    if mkv_path.exists() and minfo_path.exists():
        return False

    try:
        strm_generator._write_spore_stubs(
            strm_path,
            token,
            item.get("title") or strm_path.stem,
            item.get("quality"),
            item.get("size_gb"),
        )
    except Exception as exc:
        print(f"ERROR writing stub for {strm_path}: {exc}")
        traceback.print_exc()
        return False

    if mkv_path.exists():
        print(f"created: {mkv_path}")
        return True

    print(f"FAILED (no file after write): {mkv_path}")
    return False


def backfill_all() -> int:
    created = 0
    seen: set[str] = set()

    print("=== Phase 1: official backfill ===")
    print(strm_generator.backfill_spore_stubs())
    print()

    print("=== Phase 2: every .strm on disk ===")
    media = Path(config.MEDIA_PATH)
    for strm in sorted(media.rglob("*.strm")) if media.is_dir() else []:
        token = _token_from_strm(strm)
        if not token:
            continue
        key = f"{token}:{strm}"
        if key in seen:
            continue
        seen.add(key)
        item = db.get_virtual_item(token) or {"token": token, "title": strm.parent.name}
        if create_stub(strm, item):
            created += 1

    print()
    print("=== Phase 3: virtual_items missing stubs ===")
    for item in db.get_all_virtual_items():
        strm_path = _strm_path_for_item(item)
        if not strm_path:
            print(f"skip virtual_item: token={item.get('token')} title={item.get('title')!r}")
            continue
        key = f"{item.get('token')}:{strm_path}"
        if key in seen:
            continue
        seen.add(key)
        if create_stub(strm_path, item):
            created += 1

    return created


def main() -> int:
    force_spore_settings()
    missing = diagnose()
    print()

    if not missing and not list(_spore_root().rglob("*.mkv")):
        print("No .strm files found under MEDIA_PATH.")
        print("Request media in Seerr or run TorBox library scan in Mycelium Admin.")
        return 1

    created = backfill_all()
    stubs = list(_spore_root().rglob("*.mkv"))
    print()
    print(f"=== Done: {created} new stub(s); {len(stubs)} total in {_spore_root()} ===")
    if stubs:
        print("Next: ./manage.sh plex-scan")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
