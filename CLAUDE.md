# Go Face Recognition

Facial recognition system built in Go, based on FaceNet principles. Uses the go-face library (backed by dlib C++) for face detection and recognition. Dockerized for multi-architecture deployment (amd64, arm64, arm/v7).

## Tech Stack

- **Language**: Go 1.26.2 (CGO enabled)
- **Face Recognition**: go-face (fork of Kagami/go-face, dlib C++ bindings)
- **Image Processing**: golang.org/x/image (font/opentype for TTF rendering)
- **Container**: Docker with multi-arch buildx (amd64, arm64, arm/v7)
- **Registry**: GHCR (ghcr.io/andriykalashnykov/go-face-recognition)
- **CI**: GitHub Actions
- **Linting**: golangci-lint, hadolint

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
make lint             # Run Go linters and Dockerfile linting
make run              # Run the application locally
make update           # Update Go dependencies
make ci               # Run full CI pipeline (deps, lint, test, build)
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
| `DOCKER_PLATFORM` | `linux/arm/v7` | Default Docker build platform |
| `BUILDER_IMAGE` | `ghcr.io/andriykalashnykov/go-face:v0.0.3` | Base builder image |
| `IMAGE_REPO` | `andriykalashnykov/go-face-recognition` | Docker image repository |

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push to main, tags, and pull requests:

1. **docker-image** job: Build multi-arch Docker image (amd64, arm64, arm/v7); push to GHCR on tags only

Build and test happen inside the Docker multi-stage build since CGO/dlib dependencies are only available in the builder image. Lint and test via `make ci` are for local development.

A separate cleanup workflow (`.github/workflows/cleanup-runs.yml`) removes old workflow runs weekly via native `gh` CLI.

## Build Notes

- CGO is required (dlib C++ bindings)
- Linux amd64 build requires: `x86_64-linux-gnu-gcc`, `x86_64-linux-gnu-g++`, LAPACK, BLAS, ATLAS, gfortran
- macOS arm64 build requires: Homebrew dlib, OpenBLAS
- Docker builds use pre-built builder image: `ghcr.io/andriykalashnykov/go-face:v0.0.3`

## Upgrade Backlog

Last reviewed: 2026-04-07

- [x] ~~Bump `GO_VER` 1.26.1 → 1.26.2~~ (done 2026-04-07)
- [x] ~~Bump Ubuntu noble-20260217 → noble-20260324 in Dockerfile.ubuntu.builder~~ (done 2026-04-07)
- [ ] Pin `Dockerfile.alpine.runtme` base image with digest (needs image pull to obtain sha256)
- [ ] Add govulncheck as Docker CI step (can't run locally due to CGO/dlib)

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.yml` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
