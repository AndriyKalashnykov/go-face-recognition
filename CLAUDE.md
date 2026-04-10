# Go Face Recognition

Facial recognition system built in Go, based on FaceNet principles. Uses the go-face library (backed by dlib C++) for face detection and recognition. Dockerized for multi-architecture deployment (amd64, arm64, arm/v7).

## Tech Stack

- **Language**: Go 1.26.2 (CGO enabled)
- **Face Recognition**: go-face (fork of Kagami/go-face, dlib C++ bindings)
- **Image Processing**: golang.org/x/image (font/opentype for TTF rendering)
- **Container**: Docker with multi-arch buildx (amd64, arm64, arm/v7)
- **Registry**: GHCR (ghcr.io/andriykalashnykov/go-face-recognition)
- **CI**: GitHub Actions
- **Static analysis**: golangci-lint (gosec, gocritic, errorlint, bodyclose, noctx, misspell, goconst), hadolint, actionlint, shellcheck
- **Security scanning**: gitleaks (secrets), Trivy (filesystem/image), govulncheck (Go CVEs — Docker CI only)

## Project Structure

```
cmd/                # Application entry point (main.go)
internal/
  entity/           # Domain entities (person, drawer)
  usecases/         # Business logic (load, classify, recognize persons)
images/             # Input/output images for recognition
persons/            # Person directories with face images for training
models/             # Trained facial recognition models
fonts/              # Fonts for image annotation
docker-compose.yml  # Docker Compose for local multi-container setup
```

## Common Commands

```bash
make help             # List available targets
make deps             # Verify required tool dependencies
make build            # Build Go binary for Linux amd64
make build-arm64      # Build Go binary for macOS arm64
make test             # Run tests with coverage
make format           # Auto-format Go source code
make lint             # golangci-lint (gosec, gocritic, …) + hadolint on all Dockerfile.*
make lint-ci          # Lint GitHub Actions workflows with actionlint + shellcheck
make secrets          # Scan for hardcoded secrets with gitleaks
make trivy-fs         # Filesystem vulnerability / secret / misconfig scan (Trivy)
make vulncheck        # Go dependency vulnerability scan (requires C toolchain)
make static-check     # Composite gate (lint-ci, lint, secrets, trivy-fs, deps-prune-check)
make run              # Run the application locally
make update           # Update Go dependencies
make ci               # Run full CI pipeline (deps, static-check, test, build)
make ci-run           # Run GitHub Actions workflow locally using act
make image-build      # Build Docker images via buildx
make image-run        # Run Docker images interactively
make release          # Create and push a new semver tag
make version          # Print current version tag
```

## Key Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `GO_VER` | `1.26.2` | Go version for Docker builds |
| `GOLANGCI_VERSION` | `2.11.4` | golangci-lint version |
| `ACT_VERSION` | `0.2.87` | act version for local CI |
| `HADOLINT_VERSION` | `2.14.0` | hadolint version for Dockerfile linting |
| `ACTIONLINT_VERSION` | `1.7.12` | actionlint version for workflow linting |
| `SHELLCHECK_VERSION` | `0.11.0` | shellcheck version (used by actionlint) |
| `GITLEAKS_VERSION` | `8.30.1` | gitleaks version for secret scanning |
| `TRIVY_VERSION` | `0.69.3` | Trivy version for security scanning |
| `GOVULNCHECK_VERSION` | `1.1.4` | govulncheck version for Go CVE scanning |
| `NVM_VERSION` | `0.40.4` | nvm version for Renovate bootstrap |
| `NODE_VERSION` | `$(shell cat .nvmrc)` → `24` | Node major version (source of truth: `.nvmrc`) |
| `DOCKER_PLATFORM` | `linux/amd64` | Default Docker build platform |
| `BUILDER_IMAGE` | `ghcr.io/andriykalashnykov/go-face:v0.0.3` | Base builder image |
| `IMAGE_REPO` | `andriykalashnykov/go-face-recognition` | Docker image repository |

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push to main, tags, and pull requests:

1. **docker** job: Build multi-arch Docker image (amd64, arm64, arm/v7); push to GHCR on tags only. Authenticates with the built-in `GITHUB_TOKEN` (no PAT required).

Build and test happen inside the Docker multi-stage build since CGO/dlib dependencies are only available in the builder image. Lint and test via `make ci` are for local development.

Docker image tags follow the bare-semver convention (`1.2.3`, `1.2`, `1`) derived from `v`-prefixed git tags via `docker/metadata-action`.

A separate cleanup workflow (`.github/workflows/cleanup-runs.yml`) removes old workflow runs weekly via native `gh` CLI.

## Build Notes

- CGO is required (dlib C++ bindings)
- **Linux amd64 build** requires Debian/Ubuntu packages: `libjpeg-dev`, `libdlib-dev`, `libopenblas-dev`, `libblas-dev`, `libatlas-base-dev`, `liblapack-dev`, `gfortran`, `libpng-dev`, plus `x86_64-linux-gnu-gcc` / `x86_64-linux-gnu-g++` cross-toolchain. On hosts missing these headers, `make lint`, `make test`, `make build`, and `make vulncheck` fail with `fatal error: jpeglib.h: No such file or directory` — use `make image-build` / `make ci-run` instead (the Docker builder image bundles everything).
- **macOS arm64 build** requires: Homebrew `dlib`, `openblas`, `aarch64-unknown-linux-gnu` toolchain
- Docker builds use pre-built builder image: `ghcr.io/andriykalashnykov/go-face:v0.0.3`
- `make static-check` excludes `vulncheck` because govulncheck needs the full CGO toolchain to load packages; the standalone `make vulncheck` target is available for manual invocation when the C deps are installed (or inside the builder image).

## Upgrade Backlog

Last reviewed: 2026-04-10

- [x] ~~Bump `GO_VER` 1.26.1 → 1.26.2~~ (done 2026-04-07)
- [x] ~~Bump Ubuntu noble-20260217 → noble-20260324 in Dockerfile.ubuntu.builder~~ (done 2026-04-07)
- [x] ~~Pin `Dockerfile.alpine.runtme` base image with digest~~ (already pinned to `alpine:3.23.3@sha256:25109184...`)
- [x] ~~Add non-root `USER` directive to runtime Dockerfiles~~ (done 2026-04-10 — UID 10001 in `Dockerfile.go-face`, `Dockerfile.dlib-docker-go`, `Dockerfile.alpine.runtme{,.local}`; DS-0002 now passes without `.trivyignore`)
- [x] ~~Add Trivy image scan + smoke test before push (`/harden-image-pipeline` Phase 1)~~ (done 2026-04-10)
- [x] ~~`/harden-image-pipeline` Phase 2 — cosign keyless OIDC signing~~ (done 2026-04-10 — tag-gated `sigstore/cosign-installer@cad07c2e # v4.1.1` + `cosign sign --yes <tag>@<digest>` loop; docker job gained `id-token: write` permission)
- [x] ~~`apk upgrade` in runtime stages to pick up CVE patches between alpine image cuts~~ (done 2026-04-10 — closed CVE-2026-28390 openssl + CVE-2026-22184 zlib)
- [ ] Add govulncheck as Docker CI step (can't run locally due to CGO/dlib)
- [ ] Rename typo `Dockerfile.alpine.runtme` → `Dockerfile.alpine.runtime`

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
