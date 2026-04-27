# avfk-portfolio

[![CI/CD](https://github.com/FKAV64/Web_Taban-_Dersi_Portfolio/actions/workflows/deploy.yml/badge.svg)](https://github.com/FKAV64/Web_Taban-_Dersi_Portfolio/actions/workflows/deploy.yml)

Personal portfolio of **Abdou Valerio Foma Kenfack** — Computer Engineering student at Bitlis Eren University and backend developer focused on containerized systems.

Built with **Astro 4** (static site generation), served by **nginx**, containerized with **Docker**, and deployed to **Fly.io** through a DevSecOps-hardened GitHub Actions pipeline.

---

## Architecture & CI/CD Pipeline

```mermaid
flowchart TD
    dev([Local Development])
    push[git push → main]

    subgraph gate["① DevSecOps Quality Gate"]
        direction LR
        gl[Gitleaks\nSecret Detection]
        sg[Semgrep\nSAST]
        tf[Trivy\nFilesystem Scan]
    end

    subgraph build_job["② Build Job"]
        direction LR
        lint[astro check\nType-check]
        bld[npm run build\nAstro SSG]
        img[Docker Buildx\nBuild Image]
        ti[Trivy\nImage Scan]
        lint --> bld --> img --> ti
    end

    subgraph push_job["③ Push Job  ·  main only"]
        ghcr[(GHCR\nghcr.io/fkav64/avfk-portfolio)]
    end

    subgraph fly["④ Fly.io"]
        edge[Edge Proxy\nTLS Termination]
        vm[nginx VM\nport 80]
        health[/health\nLiveness Probe]
        edge --> vm --> health
    end

    dev --> push --> gate
    gate -->|all checks pass| build_job
    build_job -->|no CRITICAL CVEs| push_job
    push_job --> ghcr --> fly

    style gate    fill:#1e1e2e,stroke:#f38ba8,color:#cdd6f4
    style build_job fill:#1e1e2e,stroke:#fab387,color:#cdd6f4
    style push_job  fill:#1e1e2e,stroke:#89b4fa,color:#cdd6f4
    style fly       fill:#1e1e2e,stroke:#a6e3a1,color:#cdd6f4
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Astro 4, Tailwind CSS 3 |
| Server | nginx 1.27-alpine |
| Container | Docker (multi-stage build, ~20 MB image) |
| Registry | GitHub Container Registry (GHCR) |
| Hosting | Fly.io (shared-cpu-1x, 256 MB, scales to zero) |
| CI/CD | GitHub Actions |
| Security | Gitleaks · Semgrep · Trivy (FS + image) |

---

## Local Setup

### Option A — Docker Compose (recommended)

Requires: [Docker Desktop](https://www.docker.com/products/docker-desktop/)

```bash
# Clone
git clone https://github.com/FKAV64/Web_Taban-_Dersi_Portfolio.git
cd Web_Taban-_Dersi_Portfolio

# Build and start
docker compose up --build

# Open http://localhost:8080
```

The container runs in hardened mode (`read_only`, dropped capabilities, tmpfs mounts). Use `docker compose down` to stop.

### Option B — Node dev server

Requires: Node 20+

```bash
npm install
npm run dev        # http://localhost:4321
```

---

## CI/CD Pipeline

Every push to `main` and every pull request runs the three-job pipeline defined in [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml).

### Job 1 — DevSecOps Quality Gate
Blocks everything downstream if any check fails.

| Tool | What it checks | Fail condition |
|---|---|---|
| **Gitleaks** | Full git history for secrets, tokens, API keys | Any secret found |
| **Semgrep** | JS/TS/Docker SAST using community rules | Any finding at ERROR severity |
| **Trivy (FS)** | `package-lock.json`, Dockerfile, IaC config | Any CRITICAL CVE with a fix available |

### Job 2 — Build
Runs only if Job 1 passes.

1. `npm run check` — Astro TypeScript type-check (`@astrojs/check`)
2. `npm run build` — Astro SSG compiles to `dist/`
3. Docker Buildx builds the image and writes the GitHub Actions layer cache
4. **Trivy (image)** — scans the built image for OS-level CVEs; fails on CRITICAL

### Job 3 — Push to GHCR
Runs only on direct pushes to `main` (not pull requests).

Logs in to `ghcr.io` using `GITHUB_TOKEN` (no extra secrets required), rebuilds from cache (effectively instant), and pushes two tags:

```
ghcr.io/fkav64/avfk-portfolio:latest
ghcr.io/fkav64/avfk-portfolio:sha-<short-sha>
```

---

## Fly.io Deployment

Prerequisites: [flyctl](https://fly.io/docs/hands-on/install-flyctl/) installed and authenticated.

```bash
# First deploy — creates the app on Fly.io
fly launch --no-deploy   # review fly.toml, then:
fly deploy

# Subsequent deploys (also handled automatically by the CI/CD push job)
fly deploy

# Useful commands
fly logs          # tail live logs
fly status        # machine health and region
fly ssh console   # shell into the running VM
```

The app is configured to **scale to zero** when idle (`auto_stop_machines = true`, `min_machines_running = 0`), which keeps it within Fly.io's free allowance for a portfolio.

The `/health` endpoint (`{"status":"ok"}`) is used as the liveness probe by Fly.io, Docker Compose, and the Dockerfile `HEALTHCHECK`.

---

## Project Structure

```
.
├── src/
│   ├── components/       # Hero, Projects, Skills, Experience, Education, Hobbies, Contact
│   ├── layouts/          # Layout.astro — HTML shell, SEO meta, async font loading
│   └── pages/
│       └── index.astro   # Single-page composition + scroll-animation script
├── public/
│   └── favicon.svg
├── Dockerfile            # Multi-stage: node:20-alpine build → nginx:1.27-alpine serve
├── docker-compose.yml    # Hardened local runtime (read-only FS, tmpfs, cap_drop)
├── nginx.conf            # Structured JSON logs, /health probe, asset caching, security headers
├── fly.toml              # Fly.io deployment config
└── .github/
    └── workflows/
        └── deploy.yml    # DevSecOps Gate → Build → Push to GHCR
```

---

## AI Usage Declaration

AI assistance (Claude, Anthropic) was used in the development of this project to **accelerate boilerplate generation and deployment configuration**. Specifically, AI was used to:

- Scaffold the Astro component structure and Tailwind CSS styling
- Generate the multi-stage `Dockerfile`, `nginx.conf`, and `docker-compose.yml` following SRE best practices (structured logging, graceful shutdown, hardened runtime)
- Author the GitHub Actions CI/CD pipeline with the DevSecOps quality gate
- Generate the `fly.toml` deployment configuration

All AI-generated output was reviewed, tested, and validated by the author. The content of every portfolio section (projects, skills, experience, education) reflects the author's real background and was not fabricated.
