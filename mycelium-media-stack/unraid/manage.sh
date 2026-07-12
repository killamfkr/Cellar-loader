#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[[ -f .stack-env ]] && source .stack-env
REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack}"
COMPOSE=(docker compose)
usage() {
  echo "Usage: ./manage.sh {start|stop|restart|status|logs|urls|update|claim-plex|test-webhook|plex-scan|check-media|check-spore|test-playback|fix-plex-network|rebuild-catbox|spore-backfill|sync-plex|sync-strm-fallback|fix-perms}"
}
pref_file() {
  echo "$(pwd)/plex/Library/Application Support/Plex Media Server/Preferences.xml"
}
cmd="${1:-}"
case "${cmd}" in
  start)   docker compose up -d ;;
  stop)    docker compose stop ;;
  restart) docker compose restart ;;
  status)  docker compose ps ;;
  logs)    docker compose logs -f --tail=100 "${2:-}" ;;
  update)  docker compose pull && docker compose up -d ;;
  claim-plex)
    echo "1. Open https://www.plex.tv/claim/ and copy the token (expires in ~4 minutes)"
    read -r -p "2. Paste PLEX_CLAIM token: " token
    [[ -n "${token}" ]] || { echo "No token entered."; exit 1; }
    docker stop plex 2>/dev/null || true
    pref="$(pref_file)"
    if [[ -f "${pref}" ]]; then
      echo "Clearing old Plex account link from Preferences.xml ..."
      sed -i \
        -e 's/ PlexOnlineToken="[^"]*"//g' \
        -e 's/ PlexOnlineUsername="[^"]*"//g' \
        -e 's/ PlexOnlineEmail="[^"]*"//g' \
        -e 's/ PlexOnlineHome="[^"]*"//g' \
        "${pref}"
    fi
    echo "Claiming server and starting Plex ..."
    PLEX_CLAIM="${token}" docker compose up -d plex
    echo "Wait ~30s, then open: http://${HOST_IP:-192.168.0.100}:32400/web"
    echo "Sign in with the SAME Plex account you used for the claim token."
    ;;
  urls)
    ip="${HOST_IP:-192.168.0.100}"
    secret=""
    [[ -f .stack-env ]] && secret="$(grep '^WEBHOOK_SECRET=' .stack-env | cut -d= -f2-)"
    cat <<EOF
Mycelium: http://${ip}:8088
Plex:     http://${ip}:32400/web
Seerr:    http://${ip}:5055
Radarr:   http://${ip}:7878
Sonarr:   http://${ip}:8989
Prowlarr: http://${ip}:9696
EOF
    if [[ -n "${secret}" ]]; then
      echo "Seerr webhook URL:"
      echo "  http://${ip}:8088/webhook?secret=${secret}"
    fi
    [[ -f .stack-env ]] && echo "Webhook secret: ${secret:-$(grep WEBHOOK_SECRET .stack-env | cut -d= -f2-)}"
    ;;
  test-webhook)
    ip="${HOST_IP:-192.168.0.100}"
    secret=""
    [[ -f .stack-env ]] && secret="$(grep '^WEBHOOK_SECRET=' .stack-env | cut -d= -f2-)"
    if [[ -z "${secret}" ]]; then
      echo "No WEBHOOK_SECRET in .stack-env — copy it from Mycelium Admin → Settings → Integration Endpoints"
      exit 1
    fi
    echo "POST http://${ip}:8088/webhook?secret=..."
    resp="$(curl -sS -w '\n%{http_code}' -X POST \
      "http://${ip}:8088/webhook?secret=${secret}" \
      -H 'Content-Type: application/json' \
      -d '{"notification_type":"TEST_NOTIFICATION"}')"
    body="${resp%$'\n'*}"
    code="${resp##*$'\n'}"
    echo "HTTP ${code}"
    echo "${body}"
    if [[ "${code}" == "200" || "${code}" == "202" ]]; then
      echo "OK — use this URL in Seerr: http://${ip}:8088/webhook?secret=${secret}"
    else
      echo "Failed — compare secret with Mycelium Admin → Settings → Integration Endpoints"
      exit 1
    fi
    ;;
  plex-scan)
    ip="${HOST_IP:-192.168.0.100}"
    pref="$(pref_file)"
    token=""
    if [[ -f "${pref}" ]]; then
      token="$(grep -oP 'PlexOnlineToken="\K[^"]+' "${pref}" 2>/dev/null || true)"
    fi
    if [[ -z "${token}" ]]; then
      echo "No Plex token found — claim Plex first: ./manage.sh claim-plex"
      exit 1
    fi
    echo "Refreshing Plex libraries on http://${ip}:32400 ..."
    sections="$(curl -sS "http://${ip}:32400/library/sections?X-Plex-Token=${token}")"
    while IFS= read -r id; do
      [[ -z "${id}" ]] && continue
      title="$(echo "${sections}" | grep -oP "(?<=<Directory )[^>]*key=\"${id}\"[^>]*title=\"\K[^\"]+" | head -1)"
      curl -sS -X GET "http://${ip}:32400/library/sections/${id}/refresh?X-Plex-Token=${token}" >/dev/null
      echo "  scanned: ${title:-section ${id}}"
    done < <(echo "${sections}" | grep -oP '(?<=<Directory )[^>]*key="\K[0-9]+')
    echo "Done — wait ~30s, then check Plex and run Sync Libraries in Seerr."
    ;;
  check-media)
    media_dir="$(pwd)/plex-media/movies"
    strm_dir="$(pwd)/mycelium/media/movies"
    echo "=== Spore stubs (what Plex scans) ==="
    echo "Path: ${media_dir}"
    if [[ -d "${media_dir}" ]]; then
      find "${media_dir}" -name '*.mkv' 2>/dev/null | head -20 || echo "(no .mkv stubs yet — run ./manage.sh sync-plex)"
      count="$(find "${media_dir}" -name '*.mkv' 2>/dev/null | wc -l | tr -d ' ')"
      echo "Total movie stubs: ${count}"
    else
      echo "Missing ${media_dir}"
    fi
    echo ""
    echo "=== Mycelium .strm library (internal, not Plex) ==="
    echo "Path: ${strm_dir}"
    if [[ -d "${strm_dir}" ]]; then
      find "${strm_dir}" -name '*.strm' 2>/dev/null | head -10 || echo "(no .strm files)"
      strm_count="$(find "${strm_dir}" -name '*.strm' 2>/dev/null | wc -l | tr -d ' ')"
      echo "Total movie .strm files: ${strm_count}"
    else
      echo "Missing ${strm_dir}"
    fi
    echo ""
    echo "=== Recent Mycelium activity ==="
    docker compose logs mycelium --tail=80 2>/dev/null | grep -iE 'webhook|Added|Failed|wanted|process|Seerr|Spore|error' || true
    echo ""
    echo "Mycelium library != Plex library. Run ./manage.sh sync-plex"
    ;;
  check-spore)
    compose="$(pwd)/docker-compose.yml"
    echo "=== Spore configuration (not in Mycelium Settings UI) ==="
    echo "Spore is enabled via docker-compose environment variables only."
    echo ""
    if [[ -f "${compose}" ]]; then
      echo "docker-compose.yml:"
      grep -E 'SPORE_ENABLED|SPORE_MEDIA_PATH|CATBOX_MODE|CATBOX_LAZY_ADD' "${compose}" || echo "  (missing Spore/Catbox env — add manually or re-run setup.sh --refresh-scripts)"
    else
      echo "Missing ${compose}"
    fi
    echo ""
    echo "Inside Mycelium container:"
    docker compose exec -T -w /app mycelium python3 - <<'PY' || true
import config
import settings
print(f"  config.SPORE_ENABLED = {config.SPORE_ENABLED}")
print(f"  config.SPORE_MEDIA_PATH = {config.SPORE_MEDIA_PATH}")
print(f"  settings SPORE_ENABLED = {settings.get('SPORE_ENABLED', config.SPORE_ENABLED)}")
print(f"  settings SPORE_MEDIA_PATH = {settings.get('SPORE_MEDIA_PATH', config.SPORE_MEDIA_PATH)}")
PY
    echo ""
    echo "If SPORE_ENABLED is false, add to docker-compose.yml under mycelium:"
    echo '  SPORE_ENABLED: "true"'
    echo '  SPORE_MEDIA_PATH: /data/plex-media'
    echo "Then: docker compose up -d mycelium"
    echo "Populate Plex: ./manage.sh sync-plex"
    ;;
  test-playback)
    ip="${HOST_IP:-192.168.0.100}"
    echo "=== Plex Spore playback diagnostics ==="
    echo ""
    echo "1) How are you opening Plex?"
    echo "   LAN (recommended on home network): http://${ip}:32400/web"
    echo "   Remote (app.plex.tv / plex.direct) needs Remote Access configured."
    echo "   Your error with location=wan usually means remote URL failed — try LAN first."
    echo ""
    echo "2) Plex container -> Mycelium:"
    mycelium_urls=("http://mycelium:8088/" "http://host.docker.internal:8088/" "http://${ip}:8088/")
    reached=0
    for url in "${mycelium_urls[@]}"; do
      if docker compose exec -T plex curl -sf --max-time 5 "${url}" >/dev/null 2>&1; then
        echo "   OK — plex can reach ${url}"
        reached=1
      else
        echo "   FAIL — ${url}"
      fi
    done
    if [[ "${reached}" == "0" ]]; then
      echo "   Run: ./manage.sh fix-plex-network"
    fi
    echo ""
    echo "3) Stub files (.mkv + .minfo required for Spore):"
    mkv_count="$(find "$(pwd)/plex-media" -name '*.mkv' 2>/dev/null | wc -l | tr -d ' ')"
    minfo_count="$(find "$(pwd)/plex-media" -name '*.minfo' 2>/dev/null | wc -l | tr -d ' ')"
    echo "   .mkv stubs: ${mkv_count}   .minfo sidecars: ${minfo_count}"
    if [[ "${mkv_count}" != "0" && "${minfo_count}" == "0" ]]; then
      echo "   WARNING: .mkv without .minfo — run ./manage.sh sync-plex"
    fi
    sample_minfo="$(find "$(pwd)/plex-media" -name '*.minfo' 2>/dev/null | head -1)"
    if [[ -n "${sample_minfo}" ]]; then
      token="$(grep '^token=' "${sample_minfo}" | head -1 | cut -d= -f2-)"
      echo "   Sample token: ${token}"
      echo "4) spore-stream from inside Plex container:"
      code="$(docker compose exec -T plex curl -sS -o /dev/null -w '%{http_code}' --max-time 15 \
        "http://host.docker.internal:8088/spore-stream/${token}" 2>/dev/null || echo "000")"
      if [[ "${code}" == "000" ]]; then
        code="$(docker compose exec -T plex curl -sS -o /dev/null -w '%{http_code}' --max-time 15 \
          "http://mycelium:8088/spore-stream/${token}" 2>/dev/null || echo "000")"
      fi
      echo "   HTTP ${code} for /spore-stream/${token}"
      if [[ "${code}" != "200" && "${code}" != "206" ]]; then
        echo "   Stream failed — check: docker compose logs mycelium --tail=50"
      fi
    else
      echo "4) No .minfo found — run ./manage.sh sync-plex first"
    fi
    echo ""
    echo "5) Spore transcoder wrapper log (last 15 lines):"
    wrap_log="$(pwd)/plex/spore-wrap-debug.log"
    if [[ -f "${wrap_log}" ]]; then
      tail -15 "${wrap_log}" || true
    else
      echo "   (no ${wrap_log} yet — try playing once from http://${ip}:32400/web)"
    fi
    echo ""
    echo "6) Plex Remote Access:"
    echo "   Settings → Remote Access — if red/unavailable, use http://${ip}:32400/web on LAN"
    echo "   Or forward TCP 32400 to ${ip} for remote play outside home."
    ;;
  fix-plex-network)
    ip="${HOST_IP:-192.168.0.100}"
    compose="$(pwd)/docker-compose.yml"
    [[ -f "${compose}" ]] || { echo "Missing ${compose}"; exit 1; }
    echo "Patching Plex to reach Mycelium via host gateway (fixes s1001 on Unraid) ..."
    if grep -q 'MYCELIUM_URL:' "${compose}"; then
      sed -i 's|MYCELIUM_URL:.*|MYCELIUM_URL: http://host.docker.internal:8088|' "${compose}"
    else
      echo "Add under plex environment: MYCELIUM_URL: http://host.docker.internal:8088"
      exit 1
    fi
    if ! grep -q 'host.docker.internal:host-gateway' "${compose}"; then
      # Insert extra_hosts after MYCELIUM_URL line inside plex service
      sed -i '/MYCELIUM_URL: http:\/\/host.docker.internal:8088/a\    extra_hosts:\n      - "host.docker.internal:host-gateway"' "${compose}"
    fi
    echo "Recreating Plex (rebuilds Spore transcoder wrapper) ..."
    docker compose up -d --force-recreate plex
    echo "Done. Test: ./manage.sh test-playback"
    echo "Play from LAN: http://${ip}:32400/web"
    ;;
  rebuild-catbox)
    script="$(pwd)/catbox-rebuild.py"
    if [[ ! -f "${script}" ]]; then
      echo "Downloading catbox-rebuild.py ..."
      curl -fsSL "${REPO_RAW}/unraid/catbox-rebuild.py" -o "${script}" || \
        curl -fsSL "https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/unraid/catbox-rebuild.py" -o "${script}"
    fi
    echo "Rebuilding Catbox tokens for legacy CDN .strm files ..."
    docker compose cp "${script}" mycelium:/app/catbox-rebuild.py
    docker compose exec -T -w /app mycelium python3 /app/catbox-rebuild.py
    "${BASH_SOURCE[0]:-$0}" spore-backfill
    ;;
  spore-backfill)
    script="$(pwd)/spore-backfill.py"
    if [[ ! -f "${script}" ]]; then
      echo "Downloading spore-backfill.py ..."
      curl -fsSL "${REPO_RAW}/unraid/spore-backfill.py" -o "${script}" || \
        curl -fsSL "https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/unraid/spore-backfill.py" -o "${script}"
      chmod +x "${script}"
    fi
    echo "Generating Spore .mkv stubs in plex-media ..."
    docker compose cp "${script}" mycelium:/app/spore-backfill.py
    if ! docker compose exec -T -w /app mycelium python3 /app/spore-backfill.py; then
      echo "Retrying as root (permission fix) ..."
      docker compose exec -T -u root -w /app mycelium python3 /app/spore-backfill.py || true
    fi
    ;;
  fix-perms)
    puid="${PUID:-99}"
    pgid="${PGID:-100}"
    echo "Fixing ownership on plex-media and mycelium data (${puid}:${pgid}) ..."
    chown -R "${puid}:${pgid}" "$(pwd)/plex-media" "$(pwd)/mycelium" 2>/dev/null || true
    echo "Done."
    ;;
  sync-strm-fallback)
    src="$(pwd)/mycelium/media"
    dst="$(pwd)/plex-media"
    if [[ ! -d "${src}/movies" ]]; then
      echo "No mycelium/media/movies — nothing to mirror"
      exit 1
    fi
    echo "Mirroring movie .strm files into plex-media/movies ..."
    find "${src}/movies" -name '*.strm' | while IFS= read -r strm; do
      rel="${strm#${src}/}"
      out="${dst}/${rel}"
      mkdir -p "$(dirname "${out}")"
      cp -f "${strm}" "${out}"
    done
    if [[ -d "${src}/series" ]]; then
      echo "Mirroring series .strm files into plex-media/tv ..."
      find "${src}/series" -name '*.strm' | while IFS= read -r strm; do
        rel="${strm#${src}/series/}"
        out="${dst}/tv/${rel}"
        mkdir -p "$(dirname "${out}")"
        cp -f "${strm}" "${out}"
      done
    fi
    ;;
  sync-plex)
    # Legacy CDN strms need Catbox tokens before Spore stubs can be created.
    if docker compose exec -T -w /app mycelium python3 - <<'PY' 2>/dev/null | grep -q NEED_REBUILD; then
import db
from pathlib import Path
media = Path("/data/media")
strms = list(media.rglob("*.strm")) if media.is_dir() else []
cdn = sum(1 for s in strms if "/stream/" not in s.read_text(encoding="utf-8", errors="ignore"))
if cdn and len(db.get_all_virtual_items()) == 0:
    print("NEED_REBUILD")
PY
      echo "Legacy CDN .strm detected with empty virtual_items — running rebuild-catbox first ..."
      "${BASH_SOURCE[0]:-$0}" rebuild-catbox
    fi
    "${BASH_SOURCE[0]:-$0}" spore-backfill
    stub_count="$(find "$(pwd)/plex-media" -name '*.mkv' 2>/dev/null | wc -l | tr -d ' ')"
    strm_count="$(find "$(pwd)/mycelium/media" -name '*.strm' 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${stub_count}" == "0" && "${strm_count}" != "0" ]]; then
      echo "No Spore stubs created but ${strm_count} .strm file(s) exist — mirroring .strm into plex-media ..."
      "${BASH_SOURCE[0]:-$0}" sync-strm-fallback
    fi
    "${BASH_SOURCE[0]:-$0}" fix-perms
    "${BASH_SOURCE[0]:-$0}" plex-scan
    echo "If Seerr still shows Processing: Settings → Plex → Sync Libraries"
    ;;
  *) usage; exit 1 ;;
esac
