# Unraid — Ollama Cursor Agent

Two **Community Applications**–style XML templates (Ollama + agent). No `docker compose` on the host required.

## 1. Add templates (Private Apps)

Unraid terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/ollama-agent/unraid/install-templates.sh | bash
```

Or manually:

1. **Apps** → **Docker Repositories** is not required for private templates.
2. Run the script above (it writes to `/boot/config/plugins/community.applications/private/cellar-loader/`).
3. **Apps** → **Private Apps** → install **ollama**, then **ollama-cursor-agent**.

## 2. Install Ollama

1. **Private Apps** → **ollama** → **Install**.
2. **Models** path: e.g. `/mnt/user/appdata/ollama`.
3. **Ollama Host** must be `0.0.0.0:11434` (default in the template).
4. GPU (optional): **Show more settings** → **Extra Parameters** → `--gpus all` (NVIDIA driver + toolkit on Unraid).
5. After start, container **Console**:

   ```bash
   ollama pull qwen2.5-coder:7b
   ```

## 3. Install the agent

1. **Private Apps** → **ollama-cursor-agent** → **Install**.
2. **Ollama Base URL**: `http://<UNRAID-IP>:11434` (replace with your server’s LAN IP — not `127.0.0.1`).
3. **Workspace**: path to a **git clone** the agent may edit, e.g. `/mnt/user/data/my-repo`.
4. **Web UI** port: default `8080` → open `http://<UNRAID-IP>:8080`.

Image: `ghcr.io/killamfkr/ollama-cursor-agent:latest` (built from this repo on push to `main`). If pull fails, make the package public under **GitHub → Packages**, or build locally:

```bash
git clone https://github.com/killamfkr/Cellar-loader.git
cd Cellar-loader/ollama-agent/agent
docker build -t ghcr.io/killamfkr/ollama-cursor-agent:latest .
```

Then set **Repository** on the template to your local tag when adding the container.

## 4. GitHub (optional)

In the agent template **Advanced View**, set:

| Variable | Purpose |
|----------|---------|
| `AGENT_GITHUB_TOKEN` | PAT with `repo` scope |
| `AGENT_GITHUB_REPO` | `owner/repo` |
| `AGENT_GITHUB_WEBHOOK_SECRET` | Webhook secret |

Repo webhook: `https://<public-host>/api/github/webhook` → events **Issues** and **Issue comments**.

Forward **port 8080** (reverse proxy, Tailscale, etc.) if the webhook must be reachable from GitHub.

## 5. Verify

```bash
curl -s "http://<UNRAID-IP>:8080/api/health"
```

## Files

| File | Role |
|------|------|
| [`ollama.xml`](ollama.xml) | Ollama runtime |
| [`ollama-cursor-agent.xml`](ollama-cursor-agent.xml) | Agent UI + API |
| [`install-templates.sh`](install-templates.sh) | Copy XML to Private Apps |
