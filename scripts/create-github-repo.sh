#!/usr/bin/env bash
# Creates the missler-media repository on GitHub and pushes this project to it.
# Requires: GitHub CLI (gh) authenticated with repo creation permissions.

set -euo pipefail

REPO_OWNER="${REPO_OWNER:-killamfkr}"
REPO_NAME="missler-media"

echo "Creating GitHub repository ${REPO_OWNER}/${REPO_NAME}..."
gh repo create "${REPO_OWNER}/${REPO_NAME}" \
  --description "Missler Media" \
  --public \
  --source . \
  --remote missler-media \
  --push

echo "Done! Repository available at: https://github.com/${REPO_OWNER}/${REPO_NAME}"
