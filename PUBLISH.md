# Publishing as its own GitHub repository

This project lives in **Cellar-loader** during development; the canonical home is **[killamfkr/ollama-cursor-agent](https://github.com/killamfkr/ollama-cursor-agent)**.

## One-time: create the repo and push

1. Create an empty repository on GitHub: **killamfkr/ollama-cursor-agent** (public).

2. From a machine with git, either use the **orphan branch** this project publishes:

```bash
git clone --branch ollama-cursor-agent --single-branch \
  https://github.com/killamfkr/Cellar-loader.git /tmp/oc-import
cd /tmp/oc-import
git remote remove origin
git remote add origin https://github.com/killamfkr/ollama-cursor-agent.git
git push -u origin HEAD:main
```

Or export from this folder:

```bash
git clone https://github.com/killamfkr/Cellar-loader.git
cd Cellar-loader/ollama-agent
# ensure you are on a branch that includes this directory, then:
git subtree split --prefix=ollama-agent -b ollama-cursor-agent-export
git push https://github.com/killamfkr/ollama-cursor-agent.git ollama-cursor-agent-export:main
```

3. Enable **Actions** on the new repo so `build-image.yml` publishes `ghcr.io/killamfkr/ollama-cursor-agent:latest`.

4. Make the GHCR package public (or allow anonymous pull) for Unraid template installs.

## After the split

Remove `ollama-agent/` from Cellar-loader and link to the new repository from the root README.
