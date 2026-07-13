#!/usr/bin/env python3
"""Process approved Seerr requests that are not yet in the Mycelium library.

Use when Seerr webhooks were missed, SEERR_API_KEY was added late, or requests
show in Seerr but not in Mycelium Admin.

Run inside Mycelium:
  docker compose exec -T -w /app mycelium python3 /app/sync-seerr-requests.py
"""
from __future__ import annotations

import sys

import catchup
import db
import processor
import seerr


def diagnose() -> bool:
    url = seerr._seerr_url()
    key = seerr._seerr_api_key()
    print("=== Seerr → Mycelium diagnose ===")
    print(f"SEERR_URL: {url or '(not set)'}")
    print(f"SEERR_API_KEY: {'set (' + str(len(key)) + ' chars)' if key else 'MISSING'}")
    if not url:
        print("Set SEERR_URL in Mycelium Admin → Settings (http://192.168.0.100:5055)")
        return False
    if not key:
        print("Set SEERR_API_KEY in Mycelium Admin → Settings")
        print("  Seerr → Settings → General → copy API Key")
        return False
    try:
        items = seerr.list_approved_requests(take=5)
        print(f"Seerr API OK — sample approved requests: {len(items)}")
        for item in items[:3]:
            media = item.get("media") or {}
            print(f"  - {media.get('title')!r} ({media.get('mediaType')}) request id={item.get('id')}")
    except Exception as exc:
        print(f"Seerr API FAILED: {exc}")
        return False
    recent = db.get_recent(10)
    print(f"Mycelium requests in DB (recent): {len(recent)}")
    for row in recent[:5]:
        print(f"  - {row.get('title')!r} status={row.get('status')} imdb={row.get('imdb_id')}")
    return True


def sync_approved(take: int = 50) -> dict:
    processed = skipped = failed = 0
    try:
        items = seerr.list_approved_requests(take=take)
    except Exception as exc:
        print(f"ERROR fetching Seerr requests: {exc}")
        return {"error": str(exc)}

    print(f"\n=== Processing up to {take} approved Seerr requests ===")
    print(f"Found {len(items)} approved in Seerr")

    for item in items:
        req = catchup._build_request(item)
        if req is None:
            skipped += 1
            continue

        existing = db.get_request_by_imdb(req.imdb_id)
        if existing and existing.get("status") == "success":
            print(f"skip (already success): {req.title}")
            skipped += 1
            continue

        print(f"process: {req.title} ({req.imdb_id})")
        try:
            processor.process(req)
            processed += 1
        except Exception as exc:
            print(f"ERROR {req.title}: {exc}")
            failed += 1

    return {"processed": processed, "skipped": skipped, "failed": failed, "total": len(items)}


def main() -> int:
    if not diagnose():
        print("\nFix settings above, then: docker compose restart mycelium")
        return 1
    print()
    stats = sync_approved()
    print(f"\n=== Done: {stats} ===")
    if stats.get("processed", 0) > 0:
        print("Check Mycelium Admin → Library in ~30s. Then: ./manage.sh sync-plex")
    elif stats.get("total", 0) == 0:
        print("No approved requests in Seerr — approve the request first.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
