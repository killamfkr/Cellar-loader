#!/usr/bin/env bash
# ZimaOS helper — prepares folders, then points you at the Custom App compose import.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> ZimaOS Mycelium Media Stack"
echo ""

if [[ -f "${SCRIPT_DIR}/zimaos/prepare.sh" ]]; then
  bash "${SCRIPT_DIR}/zimaos/prepare.sh"
else
  bash "${SCRIPT_DIR}/prepare.sh" 2>/dev/null || true
fi

HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[[ -n "${HOST_IP}" ]] || HOST_IP="<ZIMAOS-IP>"

cat <<EOF

==> Install via ZimaOS UI (recommended)

1. Open ZimaOS → click **+** → **Install a customized app**
2. Click **Import** → **Docker Compose** tab
3. Paste the file: ${SCRIPT_DIR}/zimaos/docker-compose.yml
   Or raw URL:
   https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/mycelium-media-stack/zimaos/docker-compose.yml
4. Before Install, set:
   - TORBOX_API_KEY
   - TMDB_API_KEY
   - CATBOX_HOST=http://${HOST_IP}:8088
   - WEBHOOK_SECRET=(any random string)
5. Click **Install** → open Mycelium on port 8088

Full guide: ${SCRIPT_DIR}/zimaos/INSTALL.md

EOF
