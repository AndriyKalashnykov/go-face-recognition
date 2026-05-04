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
- **Diagram linting**: minlag/mermaid-cli (`make mermaid-lint`), plantuml/plantuml (`make diagrams-check`) — both wired into `make static-check-host`
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
make deps             # Install all tools pinned in .mise.toml (auto-bootstraps mise locally)
make deps-check       # Show installed mise tools (diagnostic)
make build            # Build Go binary for Linux amd64
make build-arm64      # Build Go binary for macOS arm64
make test             # Host unit tests (scoped to internal/entity — pure Go, no CGO)
make test-docker      # Full internal/... unit-test suite inside the builder image (CGO+dlib)
make integration-test # //go:build integration tests inside the builder image (real dlib pipeline)
make e2e              # Build Dockerfile.go-face + run binary; asserts face count, identity, result.jpg
make e2e-compose      # Run the pipeline through docker-compose.yml (catches compose drift)
make image-verify     # Build + smoke test Dockerfile.go-face against EVERY CI matrix lineage (pre-push gate)
make format           # Auto-format Go source code (golangci-lint fmt + goimports)
make format-check     # Fail if any file needs formatting (CI gate; non-mutating)
make lint             # golangci-lint (gosec, gocritic, …) + hadolint on all Dockerfile.*
make lint-ci          # Lint GitHub Actions workflows with actionlint + shellcheck
make mermaid-lint     # Render every ```mermaid block via minlag/mermaid-cli; fail on parse errors
make diagrams         # Render docs/diagrams/*.puml → docs/diagrams/out/*.png via pinned plantuml/plantuml
make diagrams-check   # CI drift gate: fails if rendered PNGs no longer match .puml source
make secrets          # Scan for hardcoded secrets with gitleaks
make trivy-fs         # Filesystem vulnerability / secret / misconfig scan (Trivy)
make vulncheck        # Go dependency vulnerability scan on host (requires C toolchain)
make vulncheck-docker # Go dependency vulnerability scan inside the builder image (no host C deps)
make static-check-host # Host-runnable composite gate (lint-ci, secrets, trivy-fs, mermaid-lint, diagrams-check, deps-prune-check) — used by CI
make static-check     # Full composite gate = static-check-host + lint (requires CGO/dlib)
make coverage-check   # Fail if total unit-test coverage falls below 80%
make run              # Run the application locally
make update           # Update Go dependencies + run make ci
make ci               # Run full CI pipeline (deps, format-check, static-check, test, build)
make ci-run           # Run GitHub Actions workflow locally using act
make image-build      # Build Docker images via buildx (uses IMAGE_TAG, defaults to current tag)
make image-run-runtime    # Run runtime image interactively
make image-run-go-face    # Run go-face image interactively
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
| `make integration-test` | Real classify/recognize pipeline regressions + error branches against baked-in models |
| `make e2e` | End-to-end Dockerfile.go-face + binary boot + face count + identity classification + result.jpg artifact on the primary lineage |
| `make e2e-compose` | Same end-to-end assertions exercised through `docker-compose.yml` (Dockerfile.dlib-docker-go path) — catches compose wiring drift |
| `make image-verify` | Same as `e2e` but across **every** CI matrix lineage (catches lineage-specific regressions before CI) |

Never substitute `make -n image-build` or any other `-n` dry-run in place of
an actual build for verification — the whole point is to exercise the real
Docker build + link + run, and dry-runs skip exactly that.

## Key Variables

**Tool versions are pinned in `.mise.toml`** (single source of truth). `make deps` runs `mise install` which provisions Go, Node, and every aqua-backed tool the project needs (`hadolint`, `golangci-lint`, `actionlint`, `shellcheck`, `gitleaks`, `trivy`, `govulncheck`, `act`). Renovate's first-class `mise` manager updates `.mise.toml` automatically. There are no per-tool `_VERSION` constants in the Makefile for mise-managed tools.

The Makefile constants below are the EXCEPTIONS — Docker images consumed via `docker run`, host-side multiarch helpers, and project-specific image references. These are tracked by the generic Makefile customManager regex in `renovate.json` via inline `# renovate:` comments.

| Variable | Default | Purpose |
|----------|---------|---------|
| `GO_VER` | `$(shell awk '/^go [0-9]/ ...' go.mod)` → `1.26.2` | Go version for Docker builds — derived from `go.mod` so it stays in lockstep with `.mise.toml` and the Renovate-managed `gomod` manager (no separate Renovate pin needed) |
| `NODE_VERSION` | `$(shell cat .nvmrc)` → `24` | Node major version (source of truth: `.nvmrc`; also declared in `.mise.toml`) |
| `MERMAID_CLI_VERSION` | `11.12.0` | `minlag/mermaid-cli` image tag used by `make mermaid-lint` (Docker image — not in mise registry) |
| `PLANTUML_VERSION` | `1.2026.2` | `plantuml/plantuml` image tag used by `make diagrams` (Docker image — not in mise registry) |
| `BINFMT_VERSION` | `qemu-v10.2.1` | `tonistiigi/binfmt` image tag used by `make image-setup-multiarch` (Docker image — not in mise registry) |
| `DOCKER_PLATFORM` | `linux/amd64` | Default Docker build platform |
| `BUILDER_IMAGE` | `ghcr.io/andriykalashnykov/go-face/dlib20:0.1.4` (Makefile default) | Base builder image override passed to `Dockerfile.go-face` as `--build-arg`. CI builds both `dlib19` and `dlib20` lineages via a matrix (see CI/CD). |
| `IMAGE_REPO` | `andriykalashnykov/go-face-recognition` | Docker image repository |

Tools managed by mise (versions in `.mise.toml`):

| Tool | Backend | Version source |
|------|---------|----------------|
| Go | core (mise reads `go.mod`) | `.mise.toml` `go = ...` matches `go.mod` |
| Node | core (mise reads `.nvmrc`) | `.mise.toml` `node = ...` |
| hadolint | `aqua:hadolint/hadolint` | `.mise.toml` |
| golangci-lint | `aqua:golangci/golangci-lint` | `.mise.toml` |
| actionlint | `aqua:rhysd/actionlint` | `.mise.toml` |
| shellcheck | `aqua:koalaman/shellcheck` | `.mise.toml` |
| gitleaks | `aqua:gitleaks/gitleaks` | `.mise.toml` |
| trivy | `aqua:aquasecurity/trivy` | `.mise.toml` |
| govulncheck | `go:golang.org/x/vuln/cmd/govulncheck` | `.mise.toml` |
| act | `aqua:nektos/act` | `.mise.toml` |

The CI workflow uses `jdx/mise-action` to install everything from `.mise.toml` in a single step — no per-tool `actions/setup-*` actions, no inline tool installations.

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push to main, tags, and pull requests:

1. **changes** job: cheap (~10 s) `dorny/paths-filter` detector that emits TWO outputs:
   - `code=true` for any non-docs change (re-includes `CLAUDE.md` because it's project config, not docs). Drives the cheap host jobs (`static-check`, `test`).
   - `image=true` for changes that could affect the produced image or its runtime contract — Dockerfiles, docker-compose.yml, container-structure-test.yaml, Makefile, go.mod/sum, cmd/**, internal/**, baked-in data (models/, persons/, fonts/, images/), and ci.yml itself (matrix builder pins). Drives the EXPENSIVE jobs (`docker`, `integration-test`, `e2e`).

   Every heavy job gates on `code AND (image OR is-tag)` so non-image-affecting code changes (CODEOWNERS, renovate.json, cleanup-runs.yml, .mise.toml) skip the heavy jobs while tag pushes always run them as a release-day gate. Replaces the legacy trigger-level `paths-ignore` pattern, which deadlocks under Repository Rulesets (a docs-only PR's workflow run is never created → required `ci-pass` check never reports → merge blocked, admin override rejected). NOTE: `**.png` / `**.jpg` are deliberately NOT in the doc-only filter — fixture image edits must retrigger CI so the smoke test re-evaluates `images/unknown.jpg`.
2. **static-check** job: runs `make static-check-host` on host as a single composite step (lint-ci + secrets + trivy-fs + mermaid-lint + diagrams-check + deps-prune-check). The CGO-requiring `lint` (golangci-lint with gosec on internal/usecases) is exercised inside the docker job's GATE 1 build-for-scan because it cannot run on a stock runner.
3. **test** job: runs `make test` on host (pure-Go `internal/entity` suite, 98%+ coverage). Gated on `needs: [static-check]` for fail-fast.
4. **integration-test** job: runs `make integration-test` (pulls the public `go-face/dlib20` builder image and executes `//go:build integration` tests with `-race`). Gated on `needs: [static-check, test]` AND on the `image` change-flag (or tag push).
5. **e2e** job: runs `make e2e-compose` — exercises `docker-compose.yml` (Dockerfile.dlib-docker-go build path) and asserts face count + identity. Catches compose drift that `docker` job (Dockerfile.go-face) cannot see. Job key is `e2e` per portfolio convention; the Makefile target name reflects the path it exercises (the other `make e2e` target — Dockerfile.go-face direct — is exercised inside the docker job's GATE 3 smoke test). Gated on `needs: [static-check, test]` AND on the `image` change-flag (or tag push).
6. **docker** job: Build Docker image; push to GHCR on tags only. Authenticates with the built-in `GITHUB_TOKEN` (no PAT required). Runs as a `strategy.matrix` over every supported `dlib-docker` major lineage that upstream `go-face` publishes (currently `dlib19` and `dlib20`); each cell reruns all seven hardening gates (build-for-scan → Trivy image scan → smoke test → container-structure-test → multi-arch build/push → cosign sign → SBOM attest via syft + `cosign attest --type spdxjson`) independently with its own GHA cache scope and its own scan/smoke container names. `fail-fast: false` so a regression in one lineage does not mask the other. **Cost optimization**: GATE 4 (`Build and push`) is `linux/amd64` only on non-tag pushes (validation only) and full multi-arch (`amd64,arm64,arm/v7`) on tag pushes (the only time we publish). arm64 + arm/v7 builds run dlib's C++ template-heavy compile under QEMU at ~5–8× native wall-clock, so this saves ~80–90% of docker-job time on routine PRs while still validating cross-arch on release day. Gated on `needs: [static-check, test]` AND on the `image` change-flag (or tag push).
7. **release-artifacts-extract + release-artifacts-publish** jobs (tag-gated): split into two jobs by design — `extract` is a per-lineage matrix that pulls each platform manifest and builds tarballs; `publish` aggregates them, generates checksums.txt, cosign-blob-signs, and uploads to the GitHub Release. This two-job split deviates from the canonical single-`docker` job convention and is documented here as an accepted exception: the matrix fan-out is required for multi-lineage × multi-arch tarball extraction and cannot live inside the single `docker` matrix cell without serializing the work.
8. **ci-pass** aggregator: `if: always()` with `needs:` enumerating every upstream job (including `changes`); branch protection references this job only, so matrix-cell renames don't silently bypass protection. `skipped` results count as success — required for the `changes`-detector pattern to clear the Ruleset gate on docs-only PRs.

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
- `make static-check-host` is the CI-runnable subset of `make static-check`: lint-ci + secrets + trivy-fs + mermaid-lint + diagrams-check + deps-prune-check (everything except the CGO-requiring `lint`). The CI `static-check` job calls this target as a single composite step. Use `make static-check` locally on hosts with the C toolchain installed; use `make static-check-host` (or rely on CI) on stock runners.

## Upgrade Backlog

Last reviewed: 2026-05-04

- [x] ~~`/project-review` polish pass (16 findings — 0 HIGH, 5 MEDIUM, 11 LOW; all applied 2026-05-04)~~ (done 2026-05-04 — Makefile: `mermaid-lint`/`tag-delete` gained missing `deps:` prereq; `coverage-check` dropped its `test:` prereq + added missing-file guard so `make ci` no longer re-runs the unit suite; `coverage-check` + `test-integration` added to `.PHONY`; `ci-run` rewritten with per-job iteration (`static-check`/`test`/`integration-test`/`docker`), `--pull=false`, and `docker container prune -f` to dodge the containerd snapshotter race that surfaces as exit 137 on Docker 25+. CI workflows: `discover-go-face-lineages.yml` checkout step gained `name: Checkout`; `cleanup-runs.yml` `cancel-in-progress: false` deviation documented inline; `ci.yml:565` login-action version comment normalized `# v4.1.0` → `# v4`. CLAUDE.md: Tech Stack gained a "Diagram linting: mermaid-cli, plantuml" line. Test coverage: `cmd/main.go` refactored to extract `run() error` (Pattern A from `/test-coverage-analysis`); `cmd/main_test.go` added with `TestRun_LoadPersonsError` + `TestRun_RecognizerInitError` covering the previously-untestable error branches; `make integration-test` extended to `./cmd/... ./internal/usecases/...` so CI's existing `integration-test` job exercises the new tests via the builder image (no new CI job needed); `recognize_integration_test.go` `repoRoot = "../.."` const replaced with a `runtime.Caller`-derived helper that survives test-file relocations. **Real bug surfaced and fixed**: the `/test-coverage-analysis` agent flagged that `make e2e-compose` only checked face count + identity in stdout, never that the binary's `SaveImage` actually wrote `/app/images/result.jpg` back to the host via the docker-compose `./images` bind mount. Adding an mtime-delta + JPEG-validity + draw-vs-passthrough check immediately surfaced `save result image: open images/result.jpg: permission denied` — a silent UID mismatch (Dockerfile.dlib-docker-go runs as UID 10001, host file owned by UID 1000) that had been masked by `tee` swallowing the binary's exit code. Fixed at the root: added `--user $$(id -u):$$(id -g)` to `docker compose run` so the binary writes as the host UID, and added `set -o pipefail` to `e2e` / `e2e-compose` / `image-verify` recipes so future binary-side regressions surface immediately. `git restore images/result.jpg` at recipe end keeps the worktree clean since the file is git-tracked. `e2e` and `image-verify` also gained the same passthrough check (cmp result.jpg vs unknown.jpg) so a regression that drops `DrawFace` is caught even when SaveImage succeeds)

Last reviewed prior: 2026-04-26

- [x] ~~Migrate trigger-level `paths-ignore` → `dorny/paths-filter` `changes` detector job (Rulesets-deadlock fix)~~ (done 2026-04-26 — repo is on Repository Rulesets requiring `ci-pass`; trigger-level `paths-ignore` would deadlock docs-only PRs because no run is created → required check never reports → merge blocked, admin override rejected. Migrated to a 10s `changes` job using `dorny/paths-filter@v3` with the canonical negated glob (re-includes `CLAUDE.md`); every heavy job gates on `if: needs.changes.outputs.code == 'true'`. Added `pull-requests: read` workflow permission for the action's listFiles API call. `**.png` / `**.jpg` deliberately omitted from the doc-only filter so fixture image edits retrigger the smoke test)
- [x] ~~Wire `test` job to `needs: [static-check]` for fail-fast~~ (done 2026-04-26 — was running in parallel with `static-check`)
- [x] ~~Consolidate `static-check` job to one composite Makefile call~~ (done 2026-04-26 — split Makefile `static-check` into `static-check-host` (host-safe subset: lint-ci + secrets + trivy-fs + mermaid-lint + diagrams-check + deps-prune-check) and `static-check` (full = host-safe + lint). CI calls `make static-check-host` as one step. Adds mermaid-lint, diagrams-check, deps-prune-check coverage to CI for the first time — the prior 3-step inline workflow was missing them)
- [x] ~~Add `name:` to every `uses:` step lacking one~~ (done 2026-04-26 — `Checkout`, `Set up QEMU`, `Set up Docker Buildx`. CI logs were rendering `Run actions/checkout@de0fac2e4500dabe...` instead of `Checkout`)
- [x] ~~Switch `actions/setup-go` from hardcoded `go-version: '1.26.2'` to `go-version-file: 'go.mod'`~~ (done 2026-04-26 — single source of truth, eliminates drift from `GO_VER` in Makefile)
- [x] ~~Add Go tool binary cache (`~/go/bin` + `~/.local/bin` keyed on `hashFiles('Makefile')`)~~ (done 2026-04-26 — caches golangci-lint, hadolint, gitleaks, actionlint, shellcheck, trivy, govulncheck across runs; tool version bump in Makefile invalidates cache automatically)
- [x] ~~Drop `type=ref,event=branch` from Docker metadata-action tags~~ (done 2026-04-26 — generated a dead `:main` tag that was never pushed (push: gated on tag refs); pure noise)
- [x] ~~Rename CI job `e2e-compose` → `e2e`~~ (done 2026-04-26 — portfolio convention is the singular lowercase `e2e` job key. Underlying Makefile target `make e2e-compose` keeps its name to reflect the path it exercises)
- [x] ~~Add `Set up Go` step to `integration-test` + `e2e` jobs~~ (done 2026-04-26 — both jobs call `make <target>` whose `deps:` prerequisite runs `command -v go`. Real ubuntu-latest runners have Go preinstalled so this never failed in real CI; act's `catthehacker/ubuntu:act-latest` doesn't, so `make ci-run` failed with "ERROR: go is not installed" before any Docker work. Cheap (~2 s with cache) on real CI; closes the act-parity gap)
- [x] ~~Cost optimization (A): build amd64-only on non-tag pushes; multi-arch only on tags~~ (done 2026-04-26 — `Build and push` step's `platforms:` is now `${{ startsWith(github.ref, 'refs/tags/') && 'linux/amd64,linux/arm64,linux/arm/v7' \|\| 'linux/amd64' }}`. arm64 + arm/v7 builds run dlib's C++ template-heavy compile under QEMU emulation, ~5–8× wall-clock vs native — the dominant CI cost on every PR. Cross-arch regressions still surface on tag day. Trade-off documented in the `Build and push` step comment in `ci.yml`)
- [x] ~~Cost optimization (C): per-flag scoping for the `changes` detector~~ (done 2026-04-26 — added `image:` filter to the `changes` job covering Dockerfiles, docker-compose.yml, container-structure-test.yaml, Makefile, go.mod/sum, cmd/**, internal/**, models/**, persons/**, fonts/**, images/**, .github/workflows/ci.yml. The `docker`, `integration-test`, and `e2e` jobs now gate on `code AND (image OR is-tag)`. Code-only-but-not-image-affecting changes (CODEOWNERS, renovate.json, cleanup-runs.yml, .mise.toml, .nvmrc) skip the heavy jobs entirely. Tag pushes always run them as a release-day gate)
- [x] ~~Migrate Makefile tool pins to `.mise.toml` (mise as single source of truth)~~ (done 2026-04-26 — moved `ACT_VERSION`, `HADOLINT_VERSION`, `GOLANGCI_VERSION`, `ACTIONLINT_VERSION`, `SHELLCHECK_VERSION`, `GITLEAKS_VERSION`, `TRIVY_VERSION`, `GOVULNCHECK_VERSION` from Makefile constants to `.mise.toml` aqua/go backends. Dropped 7 `deps-<tool>` install targets (~80 lines of curl-and-install boilerplate). `make deps` now runs `mise install` against `.mise.toml`. CI uses `jdx/mise-action@v4` instead of `actions/setup-go`. Renovate's first-class `mise` manager updates `.mise.toml` automatically. Also: derived `GO_VER` from `go.mod` (was duplicate-pinned); deleted dead `CONTAINER_STRUCTURE_TEST_VERSION` constant (CI workflow has its own pin); pinned `tonistiigi/binfmt:qemu-v10.2.1` in `image-setup-multiarch` (was unpinned `:latest` defaulted))

Last reviewed prior: 2026-04-14

- [x] ~~Migrate `renovate-bootstrap` from nvm → mise (portfolio-wide policy)~~ (done 2026-04-14 — `.mise.toml` declares `go = "1.26.2"` and `node = "24"`; `renovate-bootstrap` installs mise via `https://mise.run` and provisions Node via `mise install node@$(NODE_VERSION)`. Dropped `NVM_VERSION` constant and its Renovate comment. `.nvmrc` retained since mise reads it natively and a handful of IDE integrations still consume it)
- [x] ~~Bump `GOVULNCHECK_VERSION` 1.1.4 → 1.2.0~~ (done 2026-04-14)
- [x] ~~Add `vulncheck-docker` target that runs govulncheck inside the builder image (bypasses host CGO dep on libjpeg/dlib)~~ (done 2026-04-14 — supersedes the "Add govulncheck as Docker CI step" backlog item below)
- [x] ~~Add host-runnable CI jobs (`static-check`, `test`, `ci-pass` aggregator) + `needs:` edges on `docker` job~~ (done 2026-04-14 — branch protection now references `ci-pass` only; `static-check` runs `lint-ci`/`secrets`/`trivy-fs` on host, `test` runs the pure-Go `internal/entity` suite on host, docker matrix gated on `needs: [static-check, test]`)
- [x] ~~Rewrite `cleanup-runs.yml` with canonical `RETAIN_DAYS`/`KEEP_MINIMUM` template + add `cleanup-caches` companion job~~ (done 2026-04-14)
- [x] ~~Extend `make e2e` + `make image-verify` with identity classification assertion (`Person: (Trump\|Biden)` grep) and `result.jpg` artifact verification (`docker cp` + `file` JPEG check)~~ (done 2026-04-14)
- [x] ~~Add `make e2e-compose` target exercising `docker-compose.yml` (Dockerfile.dlib-docker-go path); wire into CI as its own job~~ (done 2026-04-14)
- [x] ~~Rename `make test-integration` → `make integration-test` per `/test-coverage-analysis` skill convention; keep `test-integration` as a `.PHONY` alias for muscle memory~~ (done 2026-04-14)
- [x] ~~Extend `recognize_integration_test.go` with error-branch coverage: faceless training image (RecognizePersons `face == nil` branch), faceless unknown image (ClassifyPersons `len(unkFaces)==0` branch), tight-threshold classification (ClassifyThreshold `catID < 0` branch)~~ (done 2026-04-14)
- [x] ~~Extend `drawer_test.go` with `loadImage`/`loadFont` error-path tests (missing file, wrong-format bytes, empty path); lifts internal/entity coverage 91.9% → 98.4%~~ (done 2026-04-14)
- [x] ~~Add container-structure-test to the docker CI job (every matrix cell, every push) — asserts entrypoint, OCI labels, UID=10001, /app subtree presence, statically-linked ELF~~ (done 2026-04-14)
- [x] ~~Add out-of-band SBOM attestation via Syft + `cosign attest --type spdxjson` (tag-gated, attaches SPDX SBOM to image digest without polluting image manifest — Pattern A compliant)~~ (done 2026-04-14)
- [x] ~~Add Mermaid C4-Context hero diagram to README Architecture section + `make mermaid-lint` target wired into `static-check`~~ (done 2026-04-14)
- [x] ~~Bump `CONTAINER_STRUCTURE_TEST_VERSION` 1.19.3 → 1.22.1 + `CST_VERSION` env in ci.yml~~ (done 2026-04-14 — brand-new pin was already 3 minors behind latest on day 1)
- [x] ~~Bump `anchore/sbom-action/download-syft` v0.17.8 → v0.24.0 (SHA `e22c389904149dbc22b58101806040fa8d37a610`)~~ (done 2026-04-14 — included Syft v1.x migration, subaction surface unchanged)
- [x] ~~Fix `BUILDER_IMAGE` doc drift in CLAUDE.md Key Variables table (0.1.2 → 0.1.4 to match Makefile)~~ (done 2026-04-14)
- [x] ~~Renovate coverage audit for `MERMAID_CLI_VERSION` / `CONTAINER_STRUCTURE_TEST_VERSION` Makefile pins~~ (done 2026-04-27 — `CONTAINER_STRUCTURE_TEST_VERSION` was a dead Makefile constant (never referenced in any recipe) and was deleted as part of the mise migration; the actual `CST_VERSION: 'v1.22.1'` env var lives in `.github/workflows/ci.yml` and is now Renovate-tracked via a new workflow-YAML `customManagers` regex (verified end-to-end with `LOG_LEVEL=debug npx renovate --platform=local` — extraction returns `depName=GoogleContainerTools/container-structure-test, currentValue=v1.22.1`). `MERMAID_CLI_VERSION` matches the generic Makefile regex and is verified clean by `npx renovate-config-validator`)
- [ ] **`container-structure-test` 1.20→1.22 changelog scan** — now on 1.22.1, but the version jump skipped 3 minor releases. Scan the changelogs (https://github.com/GoogleContainerTools/container-structure-test/releases) for schema features worth exercising in `container-structure-test.yaml` (candidate: metadata assertions, OCI layer checks, label regex matching).
- [ ] **`anchore/sbom-action` v0.17→v0.24 smoke test on next tag push** — Syft v1.x migration happened inside this version range; confirm `syft "${first_tag}@${DIGEST}" -o spdx-json` still produces a valid SPDX 2.x JSON that `cosign attest --type spdxjson` accepts. Catch this in the next throwaway RC tag, not v1.x.
- [ ] **Trivy-gate the upstream builder pull in `integration-test` / `e2e` jobs** — both jobs pull `ghcr.io/andriykalashnykov/go-face/dlib20:0.1.4@<digest>` on every push and trust it via SHA pin only. Adding `aquasecurity/trivy-action` with `image-ref: ${{ env.BUILDER_IMAGE }}` as a first step would catch a compromised upstream lineage. Low urgency because the pin is digest-immutable — but zero-cost insurance against a theoretical upstream tag rewrite.
- [ ] **Discovery workflow scope clarification** — `.github/workflows/discover-go-face-lineages.yml` discovers new `dlib<N>` majors but does NOT detect new patch/minor tags within existing lineages (that's Renovate's `go-face builder images` group). Add a 1-line comment to the workflow clarifying this so future readers don't assume it covers both dimensions. Also confirm the Renovate group is still cycling — last merge was 0.1.4 on 2026-04-11.
- [ ] **Consider `npx @mermaid-js/mermaid-cli` (via mise) instead of `minlag/mermaid-cli` Docker image** — current `make mermaid-lint` pulls a single-maintainer Docker image. Switching to the npm package pinned via `.mise.toml` aligns with portfolio mise-first policy and drops one supply-chain hop. Monitor, not urgent — image is maintained, but dependency diversity matters for CI-critical tools.
- [x] ~~Add PlantUML C4 Context + Container diagrams under `docs/diagrams/*.puml` with modern-flat skinparam theme + `make diagrams` / `diagrams-clean` / `diagrams-check` targets wired into `static-check`; render to committed PNGs so README renders on github.com without a toolchain~~ (done 2026-04-14 — pinned `plantuml/plantuml:1.2026.2`, Renovate-annotated; C4-PlantUML stdlib pinned to v2.11.0; teal Person / indigo System / violet System_Ext palette; `UpdateElementStyle` needs BOTH `"system_ext"` AND `"external_system"` tags in Context diagrams for the palette to apply consistently)
- [x] ~~Add Mermaid `sequenceDiagram` for the classification pipeline (LoadPersons → NewRecognizer → Recognize → Classify → Draw → Save) to README Architecture section~~ (done 2026-04-14 — autonumbered, validated by `make mermaid-lint`)
- [x] ~~Add `.github/CODEOWNERS` covering `.github/workflows/**`, all `Dockerfile.*`, `container-structure-test.yaml`, `docker-compose.yml`, `renovate.json`, and `docs/diagrams/**`~~ (done 2026-04-14 — defense-in-depth against future bot workflows; requires owner review on every publishing-adjacent path)



- [x] ~~`libdlib.a` static archive missing from upstream dlib-docker images~~ (done 2026-04-11 — root cause of the d33cc15 CI regression. `dlib-docker/Dockerfile` built dlib with `-DBUILD_SHARED_LIBS=ON` only, so `/usr/local/lib/libdlib.a` was never produced; `go-face/dlib{19,20}:0.1.2` inherited the gap; this repo's `-extldflags -static` + `static_build` tag build broke with `/usr/bin/ld: cannot find -ldlib`. Fix: upstream `dlib-docker/Dockerfile` now configures + builds dlib twice (`BUILD_SHARED_LIBS=ON` then `OFF` with `CMAKE_POSITION_INDEPENDENT_CODE=ON`) so both `libdlib.so` + `libdlib.a` land in `/usr/local/lib`. Added `ENV LIBRARY_PATH=/usr/local/lib` in the upstream Dockerfile so downstream static linking resolves the archive without per-consumer CFLAGS knowledge. Verified end-to-end: dlib-docker → go-face → go-face-recognition → compiled binary classifies Trump in baked-in `unknown.jpg` in <1s)
- [x] ~~`linux/arm/v7` missing from go-face CI build-and-push platforms~~ (done 2026-04-11 — latent gap discovered after the libdlib.a fix unblocked CI: this repo's `docker` matrix builds `Dockerfile.go-face` for `linux/amd64,linux/arm64,linux/arm/v7` on top of `ghcr.io/andriykalashnykov/go-face/dlib{19,20}:<tag>`, but upstream `go-face/.github/workflows/ci.yml` only published `linux/amd64,linux/arm64` manifests. Pre-existing bug hidden for weeks because the libdlib.a issue blocked CI earlier so it never reached the multi-arch `Build and push` step. Fix: added `linux/arm/v7` to upstream go-face's docker build-and-push `platforms:` list and cut `v0.1.4` release; this repo's pins now point at `go-face/dlib{19,20}:0.1.4@<3-platform-manifest-digest>`. All 3 secondary Dockerfiles (`Dockerfile.ubuntu.builder`, `Dockerfile.alpine.runtime`, `Dockerfile.dlib-docker-go`) also verified end-to-end on amd64 + arm64 + arm/v7 via QEMU with the compiled binary classifying Trump in all 9 combinations)
- [x] ~~Release artifacts pipeline (binaries on GitHub Releases)~~ (done 2026-04-11 — new `release-artifacts-extract` + `release-artifacts-publish` jobs in `ci.yml`, gated on `startsWith(github.ref, 'refs/tags/')` and depending on the `docker` job. Per tag push, publishes **6 tarballs** (2 lineages × 3 archs) as GitHub Release assets, plus a `checksums.txt` cosign-blob-signed via GitHub OIDC keyless using the same sigstore chain as the image signing (single-bundle `.sigstore.json` format — cosign v3.x required, see 7d00ce4 → ca16bbd → ca2913e iteration for the bundle-format migration). Each tarball is a deterministic reproducible archive (`tar --sort=name --mtime=@0 --owner=0 --group=0 \| gzip -n`) containing the statically-linked `main` binary, `fonts/`, `models/`, `persons/`, `images/`, `LICENSE`, `README.md`, and a short `USAGE.md`. Download + verify snippet documented in `README.md` "Release artifacts" section. End-to-end verified on throwaway `v0.0.3-rc1` tag: 6 tarballs (115-122 MB each) uploaded, `cosign verify-blob --bundle` returns `Verified OK`, `sha256sum -c` OK, extracted binary classifies Trump in `unknown.jpg` in ~930 ms on the download host with no Docker / dlib system packages installed)
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

## GHCR package cleanup — gotchas

If you ever need to clean up a stale / test / broken `go-face-recognition` package state in GHCR (e.g. after a dry-run release, a miscut tag, or a compromised image), the key API gotchas learned 2026-04-11:

1. **Per-version delete is rate-limited by a 5000-downloads policy.**
   `DELETE /user/packages/container/go-face-recognition/versions/{id}`
   returns HTTP 400
   `Publicly visible package versions with more than 5000 downloads cannot be deleted. Contact GitHub support for further assistance.`
   The counter is aggregated at the blob (layer) level, so a package version whose layer digests happen to be shared with any popular public image (alpine, ubuntu, go runtime base layers, …) will hit this cap even for a brand-new test tag.

2. **Whole-package delete is NOT subject to that cap.**
   `DELETE /user/packages/container/go-face-recognition` (no `/versions/{id}`) succeeds silently even when individual versions inside it are above 5000 downloads. This is the escape hatch for stuck orphaned manifests in a test cleanup.

3. **After whole-package delete**, the package URL returns HTTP 404 and the GHCR Packages UI at `https://github.com/<owner>/<repo>/pkgs/container/<name>` is dead until the next `v*` tag push recreates the package fresh with real tagged versions.

4. **Cosign signature artifacts** are stored as separate tagged versions under the same package (tag format: `sha256-<hex>[.sig|.att]`). When you delete a parent manifest, the signature versions do NOT cascade — they become orphaned tagged versions that still show up in the "Recent tagged image versions" UI block. Clean them up alongside the parent image, or use whole-package delete which sweeps everything.

5. **Deleting a git tag that has a GitHub Release demotes the release to DRAFT, not to deleted.** GitHub's behavior on `git push origin --delete <tag>`: the tag is removed, but any Release that pointed at it becomes a persistent draft without a tag reference. Recreating the tag does NOT re-attach the draft — you end up with a phantom draft release that still shows up in `gh release list` and in `gh release view`, but is invisible to `shields.io/github/v/release/...` badges and to anonymous consumers of the Releases page. This hit dlib-docker during the libdlib.a tag re-cut on 2026-04-11 and left its release badge reading "no releases or repo not found" until the drafts were promoted via `gh release edit <tag> --draft=false`. The `release-artifacts-publish` job's release-creation step explicitly handles this case: instead of the naive `if gh release view ... else create` pattern, it inspects `.isDraft` and promotes drafts explicitly. Same fix lives in `dlib-docker/.github/workflows/ci.yml`'s `Create or publish GitHub Release` step.

6. **First-publish race on a freshly-created (or freshly-deleted-and-recreated) GHCR package.** When the `docker` job's matrix publishes to a package namespace that does not currently exist in GHCR, the first matrix cell to finish its multi-arch push **creates** the package and triggers GitHub's internal package-to-repo linkage. Any sibling cell that finishes its push within a few seconds of the first cell's completion hits
   ```
   denied: permission_denied: write_package
   ```
   because the package-to-repo linkage has not yet propagated through GitHub's auth layer. Observed on 2026-04-11 during the v0.0.1 release push: `docker (19)` finished first at `20:04:12Z` (creating the package), `docker (20)` tried to push its manifest at `20:04:15Z` (3 seconds later) and was denied. The race is **once-per-namespace** — subsequent pushes from any matrix cell work fine once the package exists + is linked. Fix when it happens:
   ```bash
   gh run rerun <run-id> --failed
   ```
   This retries only the failed cell. By the time the rerun hits the push step, the namespace + linkage are already in place from the first cell's earlier successful push, so the second attempt succeeds cleanly. Downstream `release-artifacts-extract` + `release-artifacts-publish` jobs re-evaluate their `needs:` chains automatically once the failed cell turns green.

   **When does this bite?** Only the very first publish to a namespace that:
   - has never been published to before (brand-new repo), OR
   - was fully deleted via `DELETE /user/packages/container/<name>` (the whole-package escape hatch from gotcha #2 above).

   **Do not** attempt a fix by serializing the matrix (`needs: [docker (20)]`-style dependency chain) — it costs parallelism on every release to work around a once-per-deletion event, and a `gh run rerun --failed` one-liner is cheaper. Document-and-accept rather than pre-serialize.

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
