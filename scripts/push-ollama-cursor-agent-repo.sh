#!/usr/bin/env bash
# Push branch ollama-cursor-agent from Cellar-loader to a new GitHub repo.
set -euo pipefail

TARGET_REPO="${TARGET_REPO:-git@github.com:killamfkr/ollama-cursor-agent.git}"
SOURCE_BRANCH="${SOURCE_BRANCH:-ollama-cursor-agent}"

echo "This pushes Cellar-loader:${SOURCE_BRANCH} to ${TARGET_REPO} (main)."
echo "Create the empty GitHub repo first."
read -r -p "Continue? [y/N] " ans
[[ "${ans}" =~ ^[yY] ]] || exit 0

git fetch origin "${SOURCE_BRANCH}"
git push "${TARGET_REPO}" "origin/${SOURCE_BRANCH}:main"

echo "Done. Set default branch to main on GitHub and enable Actions."
