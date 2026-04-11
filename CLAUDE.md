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
make test             # Host unit tests (scoped to internal/entity — pure Go, no CGO)
make test-docker      # Full internal/... unit-test suite inside the builder image (CGO+dlib)
make test-integration # //go:build integration tests inside the builder image (real dlib pipeline)
make e2e              # Build Dockerfile.go-face with primary BUILDER_IMAGE + run the binary; asserts ≥1 face
make image-verify     # Build + smoke test Dockerfile.go-face against EVERY CI matrix lineage (pre-push gate)
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

### Pre-push checklist for changes touching the image build path

When a PR touches `Dockerfile.go-face`, any `BUILDER_*` Makefile variable, or
the `ci.yml` docker matrix `include[].builder` pins, the following targets
MUST pass locally before pushing. This closes the structural gap that allowed
d33cc15 (the switch from `go-face:v0.0.3` to `go-face/dlib{19,20}:0.1.2`) to
ship with a broken link step because `make -n image-build` (dry run) was
substituted for an actual build:

| Target | Catches |
|--------|---------|
| `make test` | Host-side pure-Go regressions (fast feedback, <1s) |
| `make test-docker` | `internal/usecases` CGo compile regressions + unit tests linked against dlib |
| `make test-integration` | Real classify/recognize pipeline regressions against baked-in models |
| `make e2e` | End-to-end Dockerfile.go-face + binary boot + face classification on the primary lineage |
| `make image-verify` | Same as `e2e` but across **every** CI matrix lineage (catches lineage-specific regressions before CI) |

Never substitute `make -n image-build` or any other `-n` dry-run in place of
an actual build for verification — the whole point is to exercise the real
Docker build + link + run, and dry-runs skip exactly that.

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
| `BUILDER_IMAGE` | `ghcr.io/andriykalashnykov/go-face/dlib20:0.1.2` (Makefile default) | Base builder image override passed to `Dockerfile.go-face` as `--build-arg`. CI builds both `dlib19` and `dlib20` lineages via a matrix (see CI/CD). |
| `IMAGE_REPO` | `andriykalashnykov/go-face-recognition` | Docker image repository |

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push to main, tags, and pull requests:

1. **docker** job: Build multi-arch Docker image (amd64, arm64, arm/v7); push to GHCR on tags only. Authenticates with the built-in `GITHUB_TOKEN` (no PAT required). Runs as a `strategy.matrix` over every supported `dlib-docker` major lineage that upstream `go-face` publishes (currently `dlib19` and `dlib20`); each cell reruns all five hardening gates (build-for-scan → Trivy → smoke → multi-arch build/push → cosign sign) independently with its own GHA cache scope and its own scan/smoke container names. `fail-fast: false` so a regression in one lineage does not mask the other.

Build and test happen inside the Docker multi-stage build since CGO/dlib dependencies are only available in the builder image. Lint and test via `make ci` are for local development.

Docker image tags follow the bare-semver convention (`1.2.3`, `1.2`, `1`) derived from `v`-prefixed git tags via `docker/metadata-action`. The primary lineage (`dlib20`) owns the unsuffixed tags and `latest`; non-primary lineages publish suffixed tags (`1.2.3-dlib19`, `1.2-dlib19`, `1-dlib19`, `latest-dlib19`). Cosign signs each `tag@digest` per lineage.

A separate cleanup workflow (`.github/workflows/cleanup-runs.yml`) removes old workflow runs weekly via native `gh` CLI.

## Build Notes

- CGO is required (dlib C++ bindings)
- **Linux amd64 build** requires Debian/Ubuntu packages: `libjpeg-dev`, `libdlib-dev`, `libopenblas-dev`, `libblas-dev`, `libatlas-base-dev`, `liblapack-dev`, `gfortran`, `libpng-dev`, plus `x86_64-linux-gnu-gcc` / `x86_64-linux-gnu-g++` cross-toolchain. On hosts missing these headers, `make lint`, `make test`, `make build`, and `make vulncheck` fail with `fatal error: jpeglib.h: No such file or directory` — use `make image-build` / `make ci-run` instead (the Docker builder image bundles everything).
- **macOS arm64 build** requires: Homebrew `dlib`, `openblas`, `aarch64-unknown-linux-gnu` toolchain
- Docker builds use pre-built builder images from upstream `AndriyKalashnykov/go-face`, organized by dlib-docker major version lineage:
  - **Primary**: `ghcr.io/andriykalashnykov/go-face/dlib20` (default for `make image-build` and for CI unsuffixed tags)
  - **Secondary**: `ghcr.io/andriykalashnykov/go-face/dlib19` (CI `*-dlib19` tags only; override locally with `make image-build BUILDER_IMAGE=ghcr.io/andriykalashnykov/go-face/dlib19:<tag>`)
  - Exact digests are pinned in `.github/workflows/ci.yml` under the `strategy.matrix.include[].builder` keys and tracked by Renovate via a custom regex manager.
- `make static-check` excludes `vulncheck` because govulncheck needs the full CGO toolchain to load packages; the standalone `make vulncheck` target is available for manual invocation when the C deps are installed (or inside the builder image).

## Upgrade Backlog

Last reviewed: 2026-04-11

- [x] ~~`libdlib.a` static archive missing from upstream dlib-docker images~~ (done 2026-04-11 — root cause of the d33cc15 CI regression. `dlib-docker/Dockerfile` built dlib with `-DBUILD_SHARED_LIBS=ON` only, so `/usr/local/lib/libdlib.a` was never produced; `go-face/dlib{19,20}:0.1.2` inherited the gap; this repo's `-extldflags -static` + `static_build` tag build broke with `/usr/bin/ld: cannot find -ldlib`. Fix: upstream `dlib-docker/Dockerfile` now configures + builds dlib twice (`BUILD_SHARED_LIBS=ON` then `OFF` with `CMAKE_POSITION_INDEPENDENT_CODE=ON`) so both `libdlib.so` + `libdlib.a` land in `/usr/local/lib`. Added `ENV LIBRARY_PATH=/usr/local/lib` in the upstream Dockerfile so downstream static linking resolves the archive without per-consumer CFLAGS knowledge. Verified end-to-end: dlib-docker → go-face → go-face-recognition → compiled binary classifies Trump in baked-in `unknown.jpg` in <1s)
- [x] ~~`linux/arm/v7` missing from go-face CI build-and-push platforms~~ (done 2026-04-11 — latent gap discovered after the libdlib.a fix unblocked CI: this repo's `docker` matrix builds `Dockerfile.go-face` for `linux/amd64,linux/arm64,linux/arm/v7` on top of `ghcr.io/andriykalashnykov/go-face/dlib{19,20}:<tag>`, but upstream `go-face/.github/workflows/ci.yml` only published `linux/amd64,linux/arm64` manifests. Pre-existing bug hidden for weeks because the libdlib.a issue blocked CI earlier so it never reached the multi-arch `Build and push` step. Fix: added `linux/arm/v7` to upstream go-face's docker build-and-push `platforms:` list and cut `v0.1.4` release; this repo's pins now point at `go-face/dlib{19,20}:0.1.4@<3-platform-manifest-digest>`. All 3 secondary Dockerfiles (`Dockerfile.ubuntu.builder`, `Dockerfile.alpine.runtime`, `Dockerfile.dlib-docker-go`) also verified end-to-end on amd64 + arm64 + arm/v7 via QEMU with the compiled binary classifying Trump in all 9 combinations)
- [ ] **Release artifacts pipeline (binaries on GitHub Releases) — staged on `feat/release-artifacts` branch, not yet merged.** New `release-artifacts-extract` + `release-artifacts-publish` jobs in `ci.yml`, gated on `startsWith(github.ref, 'refs/tags/')` and depending on the `docker` job. Per tag push, publishes **6 tarballs** (2 lineages × 3 archs) as GitHub Release assets, plus a `checksums.txt` cosign-blob-signed via GitHub OIDC keyless using the same sigstore chain as the image signing. Each tarball is a deterministic reproducible archive (`tar --sort=name --mtime=@0 --owner=0 --group=0 \| gzip -n`) containing the statically-linked `main` binary, `fonts/`, `models/`, `persons/`, `images/`, `LICENSE`, `README.md`, and a short `USAGE.md`. Download + verify snippet documented in `README.md` "Release artifacts" section. Still TODO: test end-to-end with a throwaway `v0.0.3-rc1` tag on the feature branch before merging to main
- [x] ~~`make test-docker` / `make test-integration` / `make e2e` / `make image-verify` targets~~ (done 2026-04-11 — closes the structural gap that let d33cc15 ship. `make test-docker` runs the full `internal/...` suite inside the builder image (CGO/dlib host-toolchain-free); `make test-integration` runs `//go:build integration` tagged tests exercising the real dlib classify/recognize pipeline against baked-in `models/`, `persons/`, `images/unknown.jpg`; `make e2e` builds `Dockerfile.go-face` against the primary `BUILDER_IMAGE` and asserts ≥1 face is found in the classification output; `make image-verify` loops the same build + smoke over EVERY CI matrix lineage pin (`BUILDER_DLIB19` + `BUILDER_DLIB20`) mirroring the `ci.yml` `strategy.matrix.include[].builder` entries. Pre-push checklist in this file now lists all four as required before any PR touching `Dockerfile.go-face` or the matrix pins)
- [x] ~~Seed unit + integration tests (project had zero `*_test.go` files at start of 2026-04-11)~~ (done 2026-04-11 — `internal/entity/person_test.go` + `internal/entity/drawer_test.go` + `internal/usecases/load_persons_test.go` run on host (entity hits 91.9% statement coverage). `internal/usecases/recognize_integration_test.go` (build tag `integration`) exercises the full dlib flow against `models/` + `persons/` + `images/unknown.jpg` via `t.Chdir(repoRoot)` — only runs via `make test-integration` inside the builder image)
- [x] ~~Scheduled upstream lineage discovery workflow~~ (done 2026-04-11 — `.github/workflows/discover-go-face-lineages.yml` runs weekly on Monday 06:00 UTC, scans ghcr.io/andriykalashnykov/go-face/dlib{15..40} via the anonymous Docker Registry v2 token flow, diffs against `ci.yml` matrix, and opens one idempotent discovery issue per new lineage. Issue body cites the "Adding a new go-face dlib lineage" playbook in CLAUDE.md with tag + digest pre-filled. No auto-PR or auto-merge — chain of trust preserved)
- [x] ~~"Adding a new go-face dlib lineage" playbook in CLAUDE.md~~ (done 2026-04-11 — 4-step playbook with primary-flip rubric; Steps 1/2/4 mechanical, Step 3 explicitly gated on maintainer judgment)
- [x] ~~Matrix CI across upstream `go-face/dlib19` and `go-face/dlib20` builder lineages~~ (done 2026-04-11 — `.github/workflows/ci.yml` docker job gained `strategy.matrix.include` with per-lineage builder pin, cache scope, scan/smoke container suffix, and tag suffix; Renovate custom regex manager + `go-face builder images` group track both pins)
- [x] ~~Bump `GO_VER` 1.26.1 → 1.26.2~~ (done 2026-04-07)
- [x] ~~Bump Ubuntu noble-20260217 → noble-20260324 in Dockerfile.ubuntu.builder~~ (done 2026-04-07)
- [x] ~~Pin `Dockerfile.alpine.runtime` base image with digest~~ (already pinned to `alpine:3.23.3@sha256:25109184...`)
- [x] ~~Add non-root `USER` directive to runtime Dockerfiles~~ (done 2026-04-10 — UID 10001 in `Dockerfile.go-face`, `Dockerfile.dlib-docker-go`, `Dockerfile.alpine.runtime`; DS-0002 now passes without `.trivyignore`)
- [x] ~~Add Trivy image scan + smoke test before push (`/harden-image-pipeline` Phase 1)~~ (done 2026-04-10)
- [x] ~~`/harden-image-pipeline` Phase 2 — cosign keyless OIDC signing~~ (done 2026-04-10 — tag-gated `sigstore/cosign-installer@cad07c2e # v4.1.1` + `cosign sign --yes <tag>@<digest>` loop; docker job gained `id-token: write` permission)
- [x] ~~`apk upgrade` in runtime stages to pick up CVE patches between alpine image cuts~~ (done 2026-04-10 — closed CVE-2026-28390 openssl + CVE-2026-22184 zlib)
- [x] ~~Rename typo `Dockerfile.alpine.runtme` → `Dockerfile.alpine.runtime`~~ (done 2026-04-11 — while rebasing the secondary Dockerfile set. Also deleted the unused `Dockerfile.alpine.runtme` (no `.local` suffix) which referenced a deleted `ghcr.io/andriykalashnykov/go-face-recognition:v0.0.3-builder` tag and was not used by any `make` target)
- [x] ~~`Dockerfile.dlib-docker-go` references deleted `dlib-docker:v20.0.0@sha256:199cece5...`~~ (done 2026-04-11 — both tag and digest were gone from GHCR. Repointed at the rebuilt `dlib-docker:20.0.1` digest published in Phase 1 of the libdlib.a fix chain)
- [ ] Add govulncheck as Docker CI step (can't run locally due to CGO/dlib)

## Adding a new go-face dlib lineage

**Trigger**: an issue opened by `.github/workflows/discover-go-face-lineages.yml` (runs weekly on Monday 06:00 UTC, plus `workflow_dispatch`). The workflow scans upstream GHCR for `ghcr.io/andriykalashnykov/go-face/dlib<N>` packages, diffs the result against the lineages already pinned in `ci.yml`, and opens one discovery issue per newly-published lineage with its latest semver tag and immutable digest pre-filled.

Apply the four steps below in order. **Steps 1, 2, and 4 are mechanical and safe to automate**. **Step 3 is a maintainer judgment call** — do not flip the `primary:` designation without explicit human approval, because it rewrites the public meaning of the unsuffixed `:latest` tag.

**Prerequisites** — the discovery issue pre-fills these; to fetch manually for a hypothetical `dlib21`:

```bash
MAJOR=21
PKG=andriykalashnykov/go-face/dlib${MAJOR}
TOKEN=$(curl -fsS "https://ghcr.io/token?service=ghcr.io&scope=repository:${PKG}:pull" | jq -r .token)
TAG=$(curl -fsS -H "Authorization: Bearer $TOKEN" "https://ghcr.io/v2/${PKG}/tags/list" \
  | jq -r '.tags[]' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
DIGEST=$(curl -fsSI -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.oci.image.manifest.v1+json" \
  "https://ghcr.io/v2/${PKG}/manifests/${TAG}" \
  | awk 'tolower($1) == "docker-content-digest:" {print $2}' | tr -d '\r' | head -1)
echo "ghcr.io/${PKG}:${TAG}@${DIGEST}"
```

### Step 1 — Append a matrix cell in `.github/workflows/ci.yml`

In the `docker:` job's `strategy.matrix.include` list, append a new entry (always `primary: false` initially — Step 3 decides whether to flip it):

```yaml
          - dlib_major: '<N>'
            suffix: '-dlib<N>'
            primary: false
            builder: 'ghcr.io/andriykalashnykov/go-face/dlib<N>:<TAG>@<DIGEST>'
```

No other `ci.yml` edits are required — every step that references the builder image, scan tag, smoke container, or GHA cache scope is already parameterized on `matrix.*`.

### Step 2 — Register the lineage with Renovate

In `renovate.json`, append the new image name to the `matchDepNames` list of the `go-face builder images` `packageRules` entry. This ensures future patch/minor/major bumps of the new lineage collapse into the same grouped PR as existing lineages:

```json
"matchDepNames": [
  "ghcr.io/andriykalashnykov/go-face/dlib19",
  "ghcr.io/andriykalashnykov/go-face/dlib20",
  "ghcr.io/andriykalashnykov/go-face/dlib<N>"
]
```

### Step 3 — Primary designation (human decision, do NOT automate)

The primary lineage owns unsuffixed tags (`1.2.3`, `1.2`, `1`, `latest`). Flipping it rewrites the implicit contract of `ghcr.io/<owner>/go-face-recognition:latest` and affects every anonymous consumer that pulls by bare tag.

**Default**: keep the existing primary. Leave `primary: false` on the new cell and ship it alongside the current primary as a secondary lineage. The vast majority of new-lineage additions should stop here.

**Flip the primary only if ALL of the following are true**:

- Upstream `dlib-docker` has formally deprecated the previous major (check the upstream repo's release notes or deprecation notices).
- The new lineage has built green on `primary: false` in this repo's CI for at least one full release cycle (one tagged release) with no Trivy CRITICAL/HIGH findings.
- The previous primary has been pinned on this repo's most recent tag for ≥ 30 days (downstream consumers have had time to notice the lineage shift is coming via `-dlib<N>` suffixed tags).
- The maintainer has communicated the shift in a release-notes changelog entry or equivalent heads-up.

**If flipping**: change `primary: true` on the new entry and `primary: false` on the previous primary. Because the flavor logic in the `Docker metadata` step is driven by `matrix.primary`, no further `ci.yml` edits are required. Also update:

- `BUILDER_IMAGE ?=` default in `Makefile` (around line 34) to the new primary's pin.
- `ARG BUILDER_IMAGE="…"` default in `Dockerfile.go-face` (line 1) to the new primary's pin.
- The `BUILDER_IMAGE` row in the Key Variables table above to reflect the new primary.

### Step 4 — Update this file (`CLAUDE.md`)

Three touches:

1. **`## CI/CD`** section — update the "(currently `dlib19` and `dlib20`)" parenthetical to include the new lineage.
2. **`## Build Notes`** — add a bullet for the new lineage with its local-override example; mark it **Primary** or **Secondary** consistent with Step 3.
3. **`## Upgrade Backlog`** — add a completed entry at the top of the list with today's date describing what was added.

### Verification

Before committing:

```bash
make lint-ci                                                                 # actionlint
npx --yes --package renovate -- renovate-config-validator renovate.json      # Renovate config
make -n image-build                                                          # sanity-check Makefile default
actionlint .github/workflows/discover-go-face-lineages.yml                   # if you touched the discovery workflow
```

### Commit + issue closure

Conventional commit format:

```
feat(ci): add go-face/dlib<N> lineage to matrix

<closes|relates to> #<discovery-issue-number>
```

Closing the discovery issue in the commit footer keeps the audit trail linked.

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
