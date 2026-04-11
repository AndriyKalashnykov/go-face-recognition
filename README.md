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
| Container         | Docker multi-arch buildx (amd64, arm64, arm/v7); built against upstream `go-face/dlib19` + `go-face/dlib20` builder matrix |
| Registry          | GHCR (ghcr.io/andriykalashnykov/go-face-recognition) |
| Image signing     | cosign keyless OIDC (Sigstore Fulcio → Rekor, tag-only) |
| CI                | GitHub Actions                                   |
| Linting           | golangci-lint (gosec, gocritic, errorlint, …), hadolint, actionlint |
| Security scanning | gitleaks (secrets), Trivy (fs + image), govulncheck (Go CVEs) |
| Dependency updates| Renovate (+ scheduled upstream lineage discovery) |

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
| `make test` | Run host-compatible unit tests (scoped to `internal/entity` — pure Go, no CGO) |
| `make test-docker` | Run the full `internal/...` unit-test suite inside the builder image (CGO+dlib) |
| `make test-integration` | Run `//go:build integration` tests inside the builder image — exercises the real dlib classify/recognize pipeline against baked-in `models/`, `persons/`, `images/unknown.jpg` |
| `make e2e` | Build `Dockerfile.go-face` against the primary `BUILDER_IMAGE` lineage and run the compiled binary; asserts ≥1 face is classified |
| `make image-verify` | Build + smoke test `Dockerfile.go-face` against **every** CI matrix lineage pin (the local equivalent of the CI docker job's GATE 1 + GATE 3 per cell). **Run this before every push that touches `Dockerfile.go-face`, the `ci.yml` matrix, or any `BUILDER_*` variable** — closes the structural gap where `make -n image-build` (dry run) was used in place of a real build |
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
| `make deps-trivy` | Install Trivy for filesystem and image security scanning |
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
  entity/        # Domain entities (person, drawer) — pure Go, no CGO
  usecases/      # Business logic (load, classify, recognize persons)
images/          # Input/output images for recognition
persons/         # Person directories with face images for training
models/          # Trained facial recognition models
fonts/           # Fonts for image annotation
```

## Architecture

This project is the top of a three-repo image-build chain. Each upstream repo
publishes a container image to GHCR; each downstream repo pulls the layer
above as an immutable digest-pinned builder base. A bug at any layer
propagates downwards until it's fixed at the root, so understanding the
chain is essential before making changes that touch linking, CGo flags,
or base image versions.

```
┌──────────────────────────────────────────────────────────────────────┐
│  AndriyKalashnykov/dlib-docker          (this project's grandparent) │
│  https://github.com/AndriyKalashnykov/dlib-docker                    │
│                                                                      │
│  Ubuntu noble + apt{cmake,blas,lapack,jpeg,…} + `davisking/dlib`     │
│  built from source via `cmake -DBUILD_SHARED_LIBS={ON,OFF}` (two     │
│  passes, so /usr/local/lib ships BOTH libdlib.so AND libdlib.a       │
│  for downstream static linking). Exports ENV LIBRARY_PATH=/usr/local │
│  /lib so downstream `ld -ldlib` resolves the static archive.         │
│                                                                      │
│  Publishes:                                                          │
│    ghcr.io/andriykalashnykov/dlib-docker:19.24.9                     │
│    ghcr.io/andriykalashnykov/dlib-docker:20.0.1                      │
└───────────────────────────┬──────────────────────────────────────────┘
                            │ FROM (digest-pinned)
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  AndriyKalashnykov/go-face              (this project's parent)      │
│  https://github.com/AndriyKalashnykov/go-face                        │
│                                                                      │
│  dlib-docker + Go toolchain (version extracted from go.mod) + the    │
│  go-face CGo bindings source tree copied into /app. Matrix-built    │
│  against every `active` dlib lineage defined in `.dlib-versions.     │
│  json`; one image per lineage is published with a suffix.            │
│                                                                      │
│  Publishes:                                                          │
│    ghcr.io/andriykalashnykov/go-face/dlib19:0.1.2                    │
│    ghcr.io/andriykalashnykov/go-face/dlib20:0.1.2                    │
└───────────────────────────┬──────────────────────────────────────────┘
                            │ FROM (digest-pinned, per CI matrix cell)
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  AndriyKalashnykov/go-face-recognition  (this repo)                  │
│  https://github.com/AndriyKalashnykov/go-face-recognition            │
│                                                                      │
│  The actual application: uses go-face to detect + classify faces     │
│  against baked-in `persons/` and `images/unknown.jpg`, annotates     │
│  the output via `internal/entity/drawer.go`, and writes              │
│  `images/result.jpg`. Built as a fully-static binary                 │
│  (`-extldflags -static` + `static_build` tag) linking against        │
│  libdlib.a from the layer above, then COPYed into a minimal          │
│  alpine runtime stage running as non-root UID 10001.                 │
│                                                                      │
│  CI matrix builds + publishes against every go-face dlib lineage:    │
│    ghcr.io/andriykalashnykov/go-face-recognition:<tag>               │
│    ghcr.io/andriykalashnykov/go-face-recognition:<tag>-dlib19        │
└──────────────────────────────────────────────────────────────────────┘
```

**What each layer owns:**

| Layer | Provides | Bug class that lives here |
|-------|----------|---------------------------|
| dlib-docker | C++ dlib source build, BLAS/LAPACK/JPEG system libraries, `libdlib.{so,a}` in `/usr/local/lib`, `LIBRARY_PATH` env | Missing static archive, cmake flags, BLAS variant selection, apt package drift |
| go-face | Go toolchain, go-face CGo source tree, dlib headers + libs inherited from dlib-docker | Go version mismatch, CGo flag regressions, testdata drift |
| go-face-recognition | Application code, Dockerfile.go-face (static-link build), CI matrix over go-face lineages, cosign signing, image publishing | Linker flag drift, runtime image hardening, classification logic |

**Rebuilding the chain after an upstream change:** bump the digest pin in the
downstream repo (ci.yml / Makefile / Dockerfile ARG default), verify locally
with `make image-verify` or `make e2e`, then commit. Renovate's
`go-face builder images` group rule collapses all the lineage bumps across
this chain into a single PR so the pin drift stays auditable.

### Dockerfiles

This repo ships four Dockerfiles, each targeting a different build strategy.
`Dockerfile.go-face` is the canonical production path used by the CI publish
matrix; the other three are **alternative build paths** kept as first-class
maintained artifacts for scenarios where the primary path isn't what you
want. All four produce the same functional end-state — a statically-linked
binary that classifies faces in `images/unknown.jpg` against `persons/`.

| Dockerfile | Purpose | Base image (starts from) | libdlib source | Used by |
|------------|---------|--------------------------|----------------|---------|
| **`Dockerfile.go-face`** | **Primary** production build. The CI matrix publishes multi-arch GHCR images from this file, one per dlib lineage. Hardened for K8s restricted-pod-security (non-root UID 10001). | `ghcr.io/andriykalashnykov/go-face/dlib{19,20}:<tag>@<digest>` — upstream go-face image (dlib-docker + Go + go-face CGo source tree) | Inherited from upstream `go-face` (→ dlib-docker → from-source dlib build) | `.github/workflows/ci.yml` docker matrix, `make image-build`, `make e2e`, `make image-verify` |
| **`Dockerfile.ubuntu.builder`** | **Self-contained alternative builder.** Installs dlib via Ubuntu's stock `libdlib-dev` apt package and builds Go from go.dev with SHA256 verification. Useful when you want to reproduce a build without depending on the upstream `dlib-docker`/`go-face` image chain at all. Produces a dev sandbox container (`tail -f /dev/null`) with the baked-in binary for interactive debugging. | `ubuntu:noble-20260324@<digest>` (pinned) | Ubuntu apt `libdlib-dev` package (currently dlib 19.24.0 on noble — older than the dlib-docker chain's 20.0.1 but self-consistent) | `make image-build` → `:latest-builder` |
| **`Dockerfile.alpine.runtime`** | **Minimal alpine runtime slice** over a locally-built builder image. Copies the compiled binary + test data out of the `BUILDER_IMAGE` (default: `:latest-builder` from `Dockerfile.ubuntu.builder`) into a fresh `alpine:3.23.3` stage running as non-root UID 10001. Use this to produce a small (~130 MB content size) deployable runtime image after running `Dockerfile.ubuntu.builder`. | `alpine:3.23.3@<digest>` (pinned) + `BUILDER_IMAGE` via `COPY --from` | Inherited from `BUILDER_IMAGE` | `make image-build` → `:latest-runtime` |
| **`Dockerfile.dlib-docker-go`** | **Skip-go-face alternative.** Builds directly on `dlib-docker` (one layer shallower than `Dockerfile.go-face`), installing Go at build time. Useful for reproducible builds that only depend on one upstream repo, or when exercising dlib-docker changes without round-tripping through the go-face image. Produces the same non-root alpine runtime as `Dockerfile.go-face`. | `ghcr.io/andriykalashnykov/dlib-docker:<tag>@<digest>` (pinned) | Inherited from dlib-docker (→ from-source dlib build via cmake) | `make image-build` → `:latest-dlib-docker-go` |

**Quality invariants (enforced by `hadolint` + `trivy-fs` on every commit):**
all four Dockerfiles use pinned base-image digests, `--no-install-recommends`
on apt installs with `/var/lib/apt/lists/*` cleanup, SHA256 verification on
Go tarball downloads, OCI image labels, and a non-root runtime `USER`. All
four have been end-to-end verified on `linux/amd64` (both the build and
running the compiled binary against the baked-in test data).

**When to use which:**

- **Production / CI publishes:** always `Dockerfile.go-face` — it's the only
  one whose CI publishes multi-arch signed images to GHCR.
- **Local dev sandbox without GHCR dependency:** `Dockerfile.ubuntu.builder`
  gives you a ubuntu-based container with the binary baked in. No need to
  pull the upstream `go-face` or `dlib-docker` images.
- **Small runtime deployable after ubuntu builder:** `Dockerfile.alpine.runtime`
  over `Dockerfile.ubuntu.builder`. Matches the size profile of the
  `Dockerfile.go-face` runtime stage.
- **Testing dlib-docker changes end-to-end:** `Dockerfile.dlib-docker-go`
  bypasses the go-face intermediate so dlib-docker pin bumps can be
  exercised in isolation.

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

| Workflow | Triggers | Summary |
|----------|----------|---------|
| **ci** (`docker` job) | push, PR, tags | `strategy.matrix` over every supported upstream `go-face` dlib major lineage (currently `dlib19` + `dlib20`). Each matrix cell runs the full five-gate hardening pipeline (build + Trivy image scan + smoke test + multi-arch build + cosign signing) independently with its own GHA cache scope. Publishes multi-arch image (amd64, arm64, arm/v7) to GHCR on tag pushes only. |
| **ci** (`release-artifacts-extract` + `release-artifacts-publish` jobs) | tag pushes only | `needs: [docker]`. Extracts `/app/main` + `fonts/` + `models/` + `persons/` + `images/` from every per-platform manifest of every lineage image, packages each as a deterministic reproducible tarball (`tar --sort=name --mtime=@0 --owner=0 --group=0 \| gzip -n`), produces `checksums.txt` covering all six tarballs, cosign-blob-signs it with keyless OIDC (same chain of trust as the image signing), creates the GitHub Release if missing, and uploads everything. See "Release artifacts" below. |
| **cleanup-runs** | weekly (Sunday 00:00 UTC), `workflow_dispatch` | Remove old workflow runs via native `gh` CLI |
| **discover-go-face-lineages** | weekly (Monday 06:00 UTC), `workflow_dispatch` | Scan upstream `ghcr.io/andriykalashnykov/go-face/dlib*` via the anonymous Docker Registry v2 token flow, diff against the lineages currently pinned in `ci.yml`, and open one idempotent discovery issue per new lineage with the latest semver tag + immutable manifest digest pre-filled. Cites the "Adding a new go-face dlib lineage" playbook in [`CLAUDE.md`](CLAUDE.md). No auto-PR or auto-merge — chain of trust preserved. |

Build and test happen inside the Docker multi-stage build (CGO/dlib dependencies are only available in the builder image).

The `docker` job authenticates to GHCR using the built-in `GITHUB_TOKEN` — no additional repository secret is required. The **primary** lineage (`dlib20`) owns the unsuffixed bare-semver Docker tags (`1.2.3`, `1.2`, `1`, `latest`) derived from the `v`-prefixed git tag. **Non-primary** lineages publish suffixed tags (e.g. `1.2.3-dlib19`, `1.2-dlib19`, `latest-dlib19`) so consumers can explicitly target an older dlib ABI when needed. Cosign signs each `tag@digest` per lineage.

### Pre-push image hardening

Each cell of the `docker` job's dlib lineage matrix runs the following gates **before** any image is pushed to GHCR. Any failure in any cell blocks the release (`fail-fast: false` so dlib19 and dlib20 fail independently); regressions in cross-compile targets or in either upstream lineage surface on the commit that introduced them, not on release day. Each cell uses its own GHA cache scope (`dlib19` / `dlib20`) so layers don't evict each other, and its own scan/smoke-test container names so concurrent cells don't collide.

| # | Gate | Catches | Tool |
|---|------|---------|------|
| 1 | Build single-arch image locally | Build regressions on the runner architecture | `docker/build-push-action` with `load: true` |
| 2 | **Trivy image scan** (CRITICAL/HIGH blocking) | CVEs in the base image, OS packages, build layers, leaked secrets, Dockerfile misconfigs | `aquasecurity/trivy-action` with `image-ref:` |
| 3 | **Smoke test** | Image actually works — boots the CLI binary and runs the face-recognition pipeline against baked-in test data; exit 0 means dlib loaded, the recognizer initialised, and `result.jpg` was written | `docker run --entrypoint /app/main` |
| 4 | Multi-arch build + conditional push | `linux/amd64`, `linux/arm64`, and `linux/arm/v7` cross-compile regressions. On tag push: publishes to GHCR. On non-tag push: validation-only. | `docker/build-push-action` with `push: ${{ startsWith(github.ref, 'refs/tags/') }}` |
| 5 | **Cosign keyless OIDC signing** (tag push only) | Unsigned or tampered images — every published tag gets a Sigstore signature on the manifest digest, verifiable without any long-lived key material | `sigstore/cosign-installer` + `cosign sign --yes <tag>@<digest>` |

Buildkit in-manifest attestations (`provenance`, `sbom`) are deliberately disabled so the OCI image index stays free of `unknown/unknown` platform entries — this lets the GHCR Packages UI render the **"OS / Arch"** tab correctly on the package overview page. Supply-chain verification comes from cosign signing, not from in-manifest SLSA attestations.

Runtime Dockerfiles (`Dockerfile.go-face`, `Dockerfile.dlib-docker-go`, `Dockerfile.alpine.runtime`) run as numeric UID `10001` in a non-root `app` group (K8s restricted-pod-security compatible). Every runtime stage also runs `apk --no-cache upgrade` as its first layer to pick up security patches published between alpine image cuts.

#### Verifying a published image signature

```bash
cosign verify ghcr.io/andriykalashnykov/go-face-recognition:<tag> \
  --certificate-identity-regexp 'https://github\.com/AndriyKalashnykov/go-face-recognition/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Expected output: a JSON certificate chain ending in `"issuer": "https://token.actions.githubusercontent.com"` with `"Subject"` pointing at the `AndriyKalashnykov/go-face-recognition` workflow. Any tampering with the image after publish invalidates the signature.

### Release artifacts (pre-built binaries)

Every tagged release also publishes **pre-built binary tarballs** to the
[GitHub Releases](https://github.com/AndriyKalashnykov/go-face-recognition/releases)
page alongside the container images. This is for users who want to run
`go-face-recognition` directly on a host (e.g. a Raspberry Pi) without
installing Docker, and for packagers who want a reproducible artifact to
redistribute.

**What's in a release.** Six tarballs per tag — one per `(dlib lineage ×
target architecture)` combination — plus a signed checksum file:

```
go-face-recognition_<version>_linux_amd64.tar.gz            # dlib20 primary
go-face-recognition_<version>_linux_arm64.tar.gz            # dlib20 primary
go-face-recognition_<version>_linux_armv7.tar.gz            # dlib20 primary
go-face-recognition_<version>_linux_amd64-dlib19.tar.gz     # dlib19 secondary
go-face-recognition_<version>_linux_arm64-dlib19.tar.gz     # dlib19 secondary
go-face-recognition_<version>_linux_armv7-dlib19.tar.gz     # dlib19 secondary
checksums.txt                                               # sha256 of every tarball
checksums.txt.sig                                           # cosign signature
checksums.txt.pem                                           # signing certificate
```

Each tarball is **fully self-contained** — it includes the
statically-linked binary, the dlib model files (`models/`), the fonts, the
training images (`persons/`), and a sample input (`images/unknown.jpg`).
No runtime system packages are required: the binary is linked against
`libdlib.a` from upstream
[`ghcr.io/andriykalashnykov/dlib-docker`](https://github.com/AndriyKalashnykov/dlib-docker)
so it has no `.so` dependency on dlib at all. The tarballs themselves are
built with deterministic metadata (`tar --sort=name --mtime=@0
--owner=0 --group=0 --numeric-owner | gzip -n`) so downstream consumers
can re-extract from the published image digest and verify the sha256
matches byte-for-byte.

**Download + verify + run** — picks the right binary for your
architecture, verifies the Sigstore signature without any pre-shared key,
and runs the classification example out of the box:

```bash
# Pick the version + arch you need
VERSION=1.2.3
ARCH=linux_arm64
URL=https://github.com/AndriyKalashnykov/go-face-recognition/releases/download/v${VERSION}

# Fetch the tarball and the full signed checksum bundle
curl -fsSLO "${URL}/go-face-recognition_${VERSION}_${ARCH}.tar.gz"
curl -fsSLO "${URL}/checksums.txt"
curl -fsSLO "${URL}/checksums.txt.sig"
curl -fsSLO "${URL}/checksums.txt.pem"

# Verify the checksum file was signed by this repo's GitHub Actions workflow
cosign verify-blob \
  --certificate       checksums.txt.pem \
  --signature         checksums.txt.sig \
  --certificate-identity-regexp 'https://github\.com/AndriyKalashnykov/go-face-recognition/.+' \
  --certificate-oidc-issuer    https://token.actions.githubusercontent.com \
  checksums.txt

# Verify the tarball matches the (now trusted) checksum
sha256sum -c checksums.txt --ignore-missing

# Unpack and run
tar -xzf "go-face-recognition_${VERSION}_${ARCH}.tar.gz"
cd "go-face-recognition-${VERSION}"
./main
```

Expected output:

```
Found 1 faces
Person: Trump
Total time: 910ms
```

To run against your own data, replace the contents of `persons/` and
`images/unknown.jpg` before invoking `./main`. The `models/` directory
holds the pre-trained dlib ResNet + shape-predictor weights and should
not be modified.

[Renovate](https://docs.renovatebot.com/) keeps dependencies up to date with platform automerge enabled.

## Contributing

Contributions are welcome! If you find any issues or have suggestions for improvement, please open an issue or submit a pull request on the GitHub repository.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
