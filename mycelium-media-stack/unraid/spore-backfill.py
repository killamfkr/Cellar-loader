#!/usr/bin/env python3
"""Generate Plex Spore stubs from Mycelium .strm files.

Mycelium keeps .strm files in /data/media. Plex reads Spore stub .mkv files
from /data/plex-media. This script mirrors the folder layout and writes stubs.

Run inside the Mycelium container:
  docker compose exec -T -w /app mycelium python3 /app/spore-backfill.py
"""
from __future__ import annotations

import os
import re
import sys
import traceback
from pathlib import Path

import config
import db
import settings
import strm_generator

# Match /stream/<token> and /spore-stream/<token> in .strm URLs.
TOKEN_RE = re.compile(
    r"/(?:stream|spore-stream)/([0-9a-f]{8,32})",
    re.IGNORECASE,
)

# Plex libraries in this stack use /plex-media/movies and /plex-media/tv.
# Mycelium stores TV under media/series — remap on write.
PLEX_TV_DIR = "tv"
MYCELIUM_TV_DIR = "series"
SPORE_ROOT = Path("/data/plex-media")


def force_spore_settings() -> None:
    """Ensure Spore writes to the shared plex-media volume."""
    spore = str(SPORE_ROOT)
    settings.set("SPORE_ENABLED", True)
    settings.set("SPORE_MEDIA_PATH", spore)
    settings.set("CATBOX_MODE", True)
    # strm_generator reads module-level constants, not only settings DB.
    config.SPORE_MEDIA_PATH = spore
    config.SPORE_ENABLED = True
    strm_generator.SPORE_MEDIA_PATH = spore


def _spore_enabled() -> bool:
    return bool(settings.get("SPORE_ENABLED", config.SPORE_ENABLED))


def _spore_root() -> Path:
    return SPORE_ROOT


def _remap_plex_parts(parts: tuple[str, ...]) -> tuple[str, ...]:
    if parts and parts[0] == MYCELIUM_TV_DIR:
        return (PLEX_TV_DIR, *parts[1:])
    return parts


def _spore_stub_dir(strm_path: Path) -> Path:
    """Mirror strm path into plex-media, mapping series/ -> tv/ for Plex."""
    media_root = Path(config.MEDIA_PATH)
    spore_root = _spore_root()
    try:
        rel = strm_path.parent.relative_to(media_root)
        return spore_root / Path(*_remap_plex_parts(rel.parts))
    except ValueError:
        parts = strm_path.parts
        for anchor in ("movies", MYCELIUM_TV_DIR, "series"):
            if anchor in parts:
                idx = parts.index(anchor)
                sub = parts[idx:-1]
                if sub and sub[0] == MYCELIUM_TV_DIR:
                    sub = (PLEX_TV_DIR, *sub[1:])
                return spore_root / Path(*sub)
        return spore_root / strm_path.parent.name


def _stub_paths(strm_path: Path) -> tuple[Path, Path]:
    stub_dir = _spore_stub_dir(strm_path)
    return stub_dir / (strm_path.stem + ".mkv"), stub_dir / (strm_path.stem + ".minfo")


def _token_from_strm_silent(path: Path) -> str | None:
    try:
        text = path.read_text(encoding="utf-8").strip()
    except OSError:
        return None
    match = TOKEN_RE.search(text)
    return match.group(1) if match else None


def _token_from_strm(path: Path) -> str | None:
    token = _token_from_strm_silent(path)
    if token:
        return token
    try:
        text = path.read_text(encoding="utf-8").strip()
    except OSError as exc:
        print(f"read error {path}: {exc}")
        return None
    print(f"no stream token in {path}: {text[:120]!r}")
    return None


def _build_item_index() -> dict[str, dict]:
    """Index virtual_items by strm path and token."""
    by_path: dict[str, dict] = {}
    by_token: dict[str, dict] = {}
    for item in db.get_all_virtual_items():
        token = (item.get("token") or "").strip()
        if token:
            by_token[token] = item
        raw = (item.get("strm_path") or "").strip()
        if not raw:
            continue
        by_path[raw] = item
        by_path[str(Path(raw))] = item
    return {"path": by_path, "token": by_token}


def _item_for_strm(strm: Path, index: dict[str, dict]) -> dict:
    for key in (str(strm), str(strm.resolve())):
        if key in index["path"]:
            return index["path"][key]
    token = _token_from_strm(strm)
    if token and token in index["token"]:
        return index["token"][token]
    if token:
        return db.get_virtual_item(token) or {"token": token, "title": strm.parent.name}
    return {"title": strm.parent.name}


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
            candidate = media / MYCELIUM_TV_DIR / safe / f"Season {int(season):02d}" / f"{ep_name}.strm"
            if candidate.exists():
                return candidate
            return candidate
    return None


def _check_writable(path: Path) -> bool:
    try:
        path.mkdir(parents=True, exist_ok=True)
        probe = path / ".spore-write-test"
        probe.write_text("ok", encoding="utf-8")
        probe.unlink(missing_ok=True)
        return True
    except OSError as exc:
        print(f"NOT WRITABLE {path}: {exc}")
        return False


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
    print(f"config.SPORE_MEDIA_PATH: {config.SPORE_MEDIA_PATH}")
    print(f"plex-media writable: {_check_writable(spore_root)}")
    print(f".strm files on disk: {len(strms)}")
    with_token = sum(1 for s in strms if _token_from_strm_silent(s))
    print(f".strm with /stream/ token URL: {with_token}")
    print(f".strm with legacy CDN URL (need rebuild-catbox): {len(strms) - with_token}")
    print(f"virtual_items in DB: {len(virtual)}")
    print(f"movie requests (success): {len(success)}")
    stubs = list(spore_root.rglob("*.mkv")) if spore_root.is_dir() else []
    print(f"existing stubs in plex-media: {len(stubs)}")

    for label, path in [
        ("movies strm dir", media / "movies"),
        ("series strm dir", media / MYCELIUM_TV_DIR),
        ("plex movies dir", spore_root / "movies"),
        ("plex tv dir", spore_root / PLEX_TV_DIR),
    ]:
        print(f"{label}: {path} ({'exists' if path.is_dir() else 'MISSING'})")

    if strms:
        print("\nSample .strm files:")
        for strm in strms[:5]:
            mkv, _ = _stub_paths(strm)
            print(f"  {strm}")
            print(f"    stub target: {mkv}")
            try:
                print(f"    url: {strm.read_text(encoding='utf-8').strip()[:100]}")
            except OSError as exc:
                print(f"    url read error: {exc}")

    missing = []
    for strm in strms:
        mkv, _ = _stub_paths(strm)
        if not mkv.exists():
            missing.append(strm)
    print(f"\n.strm without matching stub: {len(missing)}")
    return missing, len(strms), with_token


def write_stub_direct(strm_path: Path, token: str, item: dict) -> bool:
    """Write stub .mkv + .minfo directly (bypasses silent no-ops in _write_spore_stubs)."""
    mkv_path, minfo_path = _stub_paths(strm_path)
    if mkv_path.exists() and minfo_path.exists():
        return False

    stub_dir = mkv_path.parent
    if not _check_writable(stub_dir):
        return False

    title = item.get("title") or strm_path.stem
    quality = item.get("quality")
    size_gb = item.get("size_gb")
    duration_sec = 7200.0

    imdb_id = item.get("imdb_id")
    if imdb_id:
        try:
            import tmdb as _tmdb

            season = item.get("season")
            episode = item.get("episode")
            if season and episode:
                dur = _tmdb.get_episode_runtime_sec(imdb_id, season, episode)
            else:
                dur = _tmdb.get_movie_runtime_sec(imdb_id)
            if dur and dur > 60:
                duration_sec = dur
        except Exception:
            pass

    try:
        if not mkv_path.exists():
            stub = strm_generator.make_stub_mkv(title, quality, duration_sec=duration_sec)
            mkv_path.write_bytes(stub)
        if not minfo_path.exists():
            size_bytes = int((size_gb or 0.0) * 1_000_000_000)
            minfo_path.write_text(f"token={token}\nsize={size_bytes}\n", encoding="utf-8")
    except Exception as exc:
        print(f"ERROR writing stub for {strm_path}: {exc}")
        traceback.print_exc()
        return False

    if mkv_path.exists() and minfo_path.exists():
        print(f"created: {mkv_path}")
        return True

    print(f"FAILED (no file after write): {mkv_path}")
    return False


def create_stub(strm_path: Path, item: dict, index: dict[str, dict]) -> bool:
    token = item.get("token") or _token_from_strm(strm_path)
    if not token:
        # Re-read without printing twice: look up by path only.
        for key in (str(strm_path), str(strm_path.resolve())):
            if key in index["path"]:
                token = index["path"][key].get("token")
                item = index["path"][key]
                break
    if not token:
        return False

    mkv_path, minfo_path = _stub_paths(strm_path)
    if mkv_path.exists() and minfo_path.exists():
        return False

    # Try Mycelium's writer first, then direct write if it no-ops.
    try:
        strm_generator._write_spore_stubs(
            strm_path,
            token,
            item.get("title") or strm_path.stem,
            item.get("quality"),
            item.get("size_gb"),
        )
    except Exception as exc:
        print(f"Mycelium stub writer error for {strm_path}: {exc}")

    if mkv_path.exists() and minfo_path.exists():
        print(f"created: {mkv_path}")
        return True

    return write_stub_direct(strm_path, token, item)


def backfill_all(index: dict[str, dict]) -> int:
    created = 0
    seen: set[str] = set()

    print("=== Phase 1: official backfill ===")
    print(strm_generator.backfill_spore_stubs())
    print()

    print("=== Phase 2: every .strm on disk ===")
    media = Path(config.MEDIA_PATH)
    for strm in sorted(media.rglob("*.strm")) if media.is_dir() else []:
        item = _item_for_strm(strm, index)
        token = item.get("token") or _token_from_strm(strm)
        if not token:
            continue
        key = f"{token}:{strm}"
        if key in seen:
            continue
        seen.add(key)
        if create_stub(strm, item, index):
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
        if create_stub(strm_path, item, index):
            created += 1

    return created


def main() -> int:
    force_spore_settings()
    index = _build_item_index()
    missing, strm_count, with_token = diagnose()
    print()

    if not missing and not list(_spore_root().rglob("*.mkv")):
        if strm_count == 0:
            print("No .strm files found under MEDIA_PATH.")
            print("Request media in Seerr or run TorBox library scan in Mycelium Admin.")
            return 1

    if os.geteuid() != 0 and not _check_writable(_spore_root()):
        print("plex-media is not writable — re-run as root:")
        print("  docker compose exec -T -u root -w /app mycelium python3 /app/spore-backfill.py")
        return 1

    created = backfill_all(index)
    stubs = list(_spore_root().rglob("*.mkv"))
    print()
    print(f"=== Done: {created} new stub(s); {len(stubs)} total in {_spore_root()} ===")
    if stubs:
        print("Next: ./manage.sh plex-scan")
        return 0
    print("No stubs created. Check diagnose output above (token URLs, permissions, writable path).")
    if strm_count > 0 and with_token == 0:
        print("All .strm files use legacy CDN URLs — run: ./manage.sh rebuild-catbox")
    return 1


if __name__ == "__main__":
    sys.exit(main())
