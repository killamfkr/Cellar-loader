# Publishing as its own GitHub repository

Canonical home: **[killamfkr/ollama-cursor-agent](https://github.com/killamfkr/ollama-cursor-agent)**.

The full project **already lives on this git branch** (`ollama-cursor-agent`) at the repository root — not under a subfolder.

## Fastest: push from your PC (empty repo must exist)

```bash
git clone --branch ollama-cursor-agent --single-branch \
  https://github.com/killamfkr/Cellar-loader.git ollama-cursor-agent
cd ollama-cursor-agent
git remote set-url origin https://github.com/killamfkr/ollama-cursor-agent.git
git push -u origin HEAD:main
```

GitHub may ask you to sign in (HTTPS) or use SSH:

```bash
git remote set-url origin git@github.com:killamfkr/ollama-cursor-agent.git
git push -u origin HEAD:main
```

## Or: GitHub Action on Cellar-loader

1. Cellar-loader → **Settings → Secrets → Actions** → new secret `OLLAMA_CURSOR_AGENT_PUSH_TOKEN` (PAT with `repo` scope).
2. Merge `.github/workflows/publish-ollama-cursor-agent.yml` into **Cellar-loader `main`**.
3. **Actions → Publish ollama-cursor-agent repo → Run workflow**.

## After push

1. On **ollama-cursor-agent**, set default branch to **main**.
2. Enable **Actions** (`build-image.yml` → `ghcr.io/killamfkr/ollama-cursor-agent:latest`).
3. Make the GHCR package **public** for Unraid pulls.
