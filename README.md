[![CI](https://github.com/AndriyKalashnykov/go-face-recognition/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AndriyKalashnykov/go-face-recognition/actions/workflows/ci.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/go-face-recognition.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/go-face-recognition/)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/go-face-recognition)

# Go Face Recognition

Facial recognition system built in Go, based on FaceNet principles. Uses the [go-face](https://github.com/AndriyKalashnykov/go-face) library (backed by [dlib](http://dlib.net/) C++) for face detection and recognition. Dockerized for multi-architecture deployment (amd64, arm64, arm/v7).

| Component         | Technology                                       |
|-------------------|--------------------------------------------------|
| Language          | Go 1.26.2 (CGO enabled)                          |
| Face Recognition  | go-face (fork of Kagami/go-face, dlib C++)       |
| Image Processing  | golang.org/x/image (font/opentype for TTF)       |
| Container         | Docker multi-arch buildx (amd64, arm64, arm/v7)  |
| Registry          | GHCR (ghcr.io/andriykalashnykov/go-face-recognition) |
| CI                | GitHub Actions                                   |
| Linting           | golangci-lint (gosec, gocritic, errorlint, …), hadolint, actionlint |
| Security scanning | gitleaks (secrets), Trivy (fs), govulncheck (Go CVEs) |
| Dependency updates| Renovate                                         |

## Quick Start

```bash
make deps          # verify required tools
make build         # build Go binary for Linux amd64
make test          # run tests with coverage
make image-build   # build multi-arch Docker images
make image-run     # run Docker images interactively
```

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [GNU Make](https://www.gnu.org/software/make/) | 3.81+ | Build orchestration |
| [Go](https://go.dev/dl/) | 1.26.2 | Language runtime (CGO enabled) |
| [Git](https://git-scm.com/) | 2.0+ | Version control |
| [Docker](https://www.docker.com/) | latest | Container builds and runtime |
| [golangci-lint](https://golangci-lint.run/) | 2.11.4 | Go linters (auto-installed by `make deps`) |
| [hadolint](https://github.com/hadolint/hadolint) | 2.14.0 | Dockerfile linting (auto-installed by `make deps-hadolint`) |
| [actionlint](https://github.com/rhysd/actionlint) | 1.7.12 | GitHub Actions workflow linting (auto-installed by `make deps-actionlint`) |
| [shellcheck](https://github.com/koalaman/shellcheck) | 0.11.0 | Shell script linting (auto-installed by `make deps-shellcheck`) |
| [gitleaks](https://github.com/gitleaks/gitleaks) | 8.30.1 | Secret scanning (auto-installed by `make deps-gitleaks`) |
| [Trivy](https://trivy.dev/) | 0.69.3 | Filesystem/image security scanning (auto-installed by `make deps-trivy`) |
| [govulncheck](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck) | 1.1.4 | Go module vulnerability scanning (auto-installed by `make deps-govulncheck`) |
| [act](https://github.com/nektos/act) | 0.2.87 | Run GitHub Actions locally (optional) |

Install Go tool dependencies:

```bash
make deps
```

### Linux system C development headers (required for CGO build)

Because go-face links against dlib and friends via CGO, local `make lint`, `make test`, and `make build` require the following Debian/Ubuntu packages in addition to `make deps`:

```bash
sudo apt-get install -y \
    libjpeg-dev libdlib-dev libopenblas-dev libblas-dev \
    libatlas-base-dev liblapack-dev gfortran libpng-dev
```

If these headers are missing, tools like `golangci-lint` and `govulncheck` will fail with `fatal error: jpeglib.h: No such file or directory`. On hosts without the headers, use `make image-build` / `make ci-run` — the Docker builder image bundles the full toolchain.

## Available Make Targets

Run `make help` to see all available targets.

### Build & Run

| Target | Description |
|--------|-------------|
| `make build` | Build Go binary for Linux amd64 |
| `make build-arm64` | Build Go binary natively for macOS arm64 |
| `make run` | Run the application locally |
| `make clean` | Remove build artifacts and generated files |
| `make testdata` | Clone test data repository |

### Code Quality

| Target | Description |
|--------|-------------|
| `make test` | Run tests with coverage |
| `make format` | Auto-format Go source code |
| `make lint` | Run golangci-lint (gosec, gocritic, errorlint, …) and hadolint on all Dockerfiles |
| `make lint-ci` | Lint GitHub Actions workflows with actionlint |
| `make secrets` | Scan for hardcoded secrets with gitleaks |
| `make trivy-fs` | Scan filesystem for vulnerabilities, secrets, and misconfigurations |
| `make vulncheck` | Check for known vulnerabilities in Go dependencies (requires C toolchain) |
| `make static-check` | Composite quality gate (lint-ci, lint, secrets, trivy-fs, deps-prune-check) |
| `make update` | Update dependency packages to latest versions |

### Docker

| Target | Description |
|--------|-------------|
| `make image-bootstrap` | Create Docker buildx multi-platform builder |
| `make image-build` | Build Docker images via buildx |
| `make image-run` | Run Docker images interactively |
| `make image-prune` | Prune Docker system and buildx cache |
| `make image-setup-multiarch` | Install binfmt handlers for multi-arch Docker |
| `make image-run-ghcr-amd64` | Run GHCR runtime image on amd64 |
| `make image-run-ghcr-arm64` | Run GHCR runtime image on arm64 |

### CI

| Target | Description |
|--------|-------------|
| `make ci` | Run the full CI pipeline locally (deps, static-check, test, build) |
| `make ci-run` | Run GitHub Actions workflow locally using [act](https://github.com/nektos/act) |

### Dependencies

| Target | Description |
|--------|-------------|
| `make deps` | Verify required tool dependencies |
| `make deps-act` | Install act for local CI |
| `make deps-hadolint` | Install hadolint for Dockerfile linting |
| `make deps-shellcheck` | Install shellcheck for shell script linting |
| `make deps-actionlint` | Install actionlint for GitHub Actions workflow linting |
| `make deps-gitleaks` | Install gitleaks for secret scanning |
| `make deps-trivy` | Install Trivy for filesystem/image security scanning |
| `make deps-govulncheck` | Install govulncheck for Go module vulnerability scanning |
| `make deps-prune-check` | Verify go.mod and go.sum are tidy |

### Release

| Target | Description |
|--------|-------------|
| `make release` | Create and push a new semver tag |
| `make tag-delete` | Delete a specific tag locally and remotely |
| `make version` | Print current version (tag) |

### Utilities

| Target | Description |
|--------|-------------|
| `make help` | List available targets |
| `make clean` | Remove build artifacts and generated files |
| `make testdata` | Clone test data repository |
| `make renovate-bootstrap` | Install nvm and npm for Renovate |
| `make renovate-validate` | Validate Renovate configuration |

## Usage

### Dynamic Loading of People

This project dynamically loads people from within the `persons/` directory. Each person should have a subfolder with the person's name, containing images of that person to be used in the model. It is ideal to provide more than one image per person to improve classification accuracy. The images provided for each person should contain only one face, which is the face of the person.

### Recognition of Faces

After loading the people, the software reads an image from the `images/` directory. By default, it searches for an image named `unknown.jpg`. It then recognizes the faces in the image based on the provided people. The input image can contain multiple people, and the software attempts to recognize all of them.

### Output Generation

The output of the system is a new image with the faces marked and the name of each identified person. The generated image will be saved in the `images/` directory with the name `result.jpg`.

## About FaceNet

Go-Face-Recognition is based on the principles of [FaceNet](https://arxiv.org/abs/1503.03832), a groundbreaking facial recognition system developed by Google. FaceNet employs a deep neural network to directly learn a mapping from facial images to a compact Euclidean space, where distances between embeddings correspond directly to a measure of facial similarity.

### About dlib

[dlib](http://dlib.net/) is a modern C++ toolkit containing machine learning algorithms and tools for creating complex software in C++ to solve real-world problems. It is renowned for its robustness, efficiency, and versatility in computer vision, machine learning, and artificial intelligence.

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

## Building on macOS

Install OpenBLAS etc:

```bash
brew tap messense/macos-cross-toolchains
brew install aarch64-unknown-linux-musl
brew install messense/macos-cross-toolchains/aarch64-unknown-linux-gnu
brew link openblas 2>&1
```

Install dlib:

```bash
brew install cmake
git clone https://github.com/davisking/dlib.git
cd dlib
mkdir build
cd build
cmake ..
cmake --build . --config Release
sudo make install
```

Build and run:

```bash
make build-arm64
./cmd/main
```

## CI/CD

GitHub Actions runs on every push to `main`, tags `v*`, and pull requests.

| Job | Triggers | Steps |
|-----|----------|-------|
| **docker** | push, PR, tags | Build + Trivy image scan + smoke test every push; publish multi-arch image (amd64, arm64, arm/v7) to GHCR on tags only |
| **cleanup** | weekly (Sunday) | Remove old workflow runs via native `gh` CLI |

Build and test happen inside the Docker multi-stage build (CGO/dlib dependencies are only available in the builder image).

The `docker` job authenticates to GHCR using the built-in `GITHUB_TOKEN` — no additional repository secret is required. The workflow publishes bare semver Docker tags (`1.2.3`, `1.2`, `1`) derived from the `v`-prefixed git tag.

### Pre-push image hardening

The `docker` job runs the following gates **before** any image is pushed to GHCR. Any failure blocks the release; regressions in cross-compile targets surface on the commit that introduced them, not on release day.

| # | Gate | Catches | Tool |
|---|------|---------|------|
| 1 | Build single-arch image locally | Build regressions on the runner architecture | `docker/build-push-action` with `load: true` |
| 2 | **Trivy image scan** (CRITICAL/HIGH blocking) | CVEs in the base image, OS packages, build layers, leaked secrets, Dockerfile misconfigs | `aquasecurity/trivy-action` with `image-ref:` |
| 3 | **Smoke test** | Image actually works — boots the CLI binary and runs the face-recognition pipeline against baked-in test data; exit 0 means dlib loaded, the recognizer initialised, and `result.jpg` was written | `docker run --entrypoint /app/main` |
| 4 | Multi-arch build + conditional push | `linux/amd64`, `linux/arm64`, and `linux/arm/v7` cross-compile regressions. On tag push: publishes to GHCR. On non-tag push: validation-only. | `docker/build-push-action` with `push: ${{ startsWith(github.ref, 'refs/tags/') }}` |

Buildkit in-manifest attestations (`provenance`, `sbom`) are deliberately disabled so the OCI image index stays free of `unknown/unknown` platform entries — this lets the GHCR Packages UI render the **"OS / Arch"** tab correctly on the package overview page.

Runtime Dockerfiles (`Dockerfile.go-face`, `Dockerfile.dlib-docker-go`, `Dockerfile.alpine.runtme*`) run as numeric UID `10001` in a non-root `app` group (K8s restricted-pod-security compatible).

[Renovate](https://docs.renovatebot.com/) keeps dependencies up to date with platform automerge enabled.

## Contributing

Contributions are welcome! If you find any issues or have suggestions for improvement, please open an issue or submit a pull request on the GitHub repository.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
