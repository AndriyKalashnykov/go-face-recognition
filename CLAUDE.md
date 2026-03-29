# Go Face Recognition

Facial recognition system built in Go, based on FaceNet principles. Uses the go-face library (backed by dlib C++) for face detection and recognition. Dockerized for multi-architecture deployment (amd64, arm64, arm/v7).

## Tech Stack

- **Language**: Go 1.25.7 (CGO enabled)
- **Face Recognition**: go-face (dlib C++ bindings)
- **Image Processing**: golang/freetype, golang.org/x/image
- **Container**: Docker with multi-arch buildx (amd64, arm64, arm/v7)
- **Registry**: GHCR (ghcr.io/andriykalashnykov/go-face-recognition)
- **CI**: GitHub Actions

## Project Structure

```
cmd/             # Application entry point (main.go)
internal/
  entity/        # Domain entities (person, drawer)
  usecases/      # Business logic (load, classify, recognize persons)
images/          # Input/output images for recognition
persons/         # Person directories with face images for training
models/          # Trained facial recognition models
fonts/           # Fonts for image annotation
```

## Common Commands

```bash
make help             # List available targets
make deps             # Verify required tool dependencies
make build            # Build Go binary for Linux amd64
make build-arm64      # Build Go binary for macOS arm64
make test             # Run tests with coverage
make lint             # Run golangci-lint
make run              # Run the application locally
make update           # Update Go dependencies
make ci               # Run full CI pipeline (deps, lint, test)
make image-build      # Build Docker images via buildx
make image-run        # Run Docker images interactively
make release          # Create and push a new semver tag
make version          # Print current version tag
```

## CI

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push to main and pull request:
1. Checkout with full history
2. Setup QEMU and Docker Buildx
3. Build multi-platform Docker image (amd64, arm64, arm/v7)
4. Push to GHCR on tag events only

A separate cleanup workflow (`.github/workflows/cleanup-runs.yml`) removes old workflow runs weekly.

## Build Notes

- CGO is required (dlib C++ bindings)
- Linux amd64 build requires: `x86_64-linux-gnu-gcc`, `x86_64-linux-gnu-g++`, LAPACK, BLAS, ATLAS, gfortran
- macOS arm64 build requires: Homebrew dlib, OpenBLAS
- Docker builds use pre-built builder image: `ghcr.io/andriykalashnykov/go-face:v0.0.3`

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.yml` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
