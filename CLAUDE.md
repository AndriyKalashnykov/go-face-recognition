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

## Upgrade Backlog → [`BACKLOG.md`](BACKLOG.md)

The upgrade backlog lives in **[`BACKLOG.md`](BACKLOG.md)**, which is *not* auto-loaded. It was
46% of this file (21,999 B) and it is task state, not instructions — and this file is paid on
every session and every subagent dispatch. Open it when you pick up upgrade work.

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
