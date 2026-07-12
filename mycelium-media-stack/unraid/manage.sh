#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[[ -f .stack-env ]] && source .stack-env
REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack}"
COMPOSE=(docker compose)
usage() {
  echo "Usage: ./manage.sh {start|stop|restart|status|logs|urls|update|claim-plex|test-webhook|plex-scan|check-media|check-spore|spore-backfill|sync-plex|sync-strm-fallback|fix-perms}"
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
