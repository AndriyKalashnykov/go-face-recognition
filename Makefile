SHELL := /bin/bash

# Ensure mise shims and Go's GOPATH/bin are on PATH for every recipe — needed
# inside the act runner container where neither path is preconfigured.
# Exported so every sub-shell the recipes spawn inherits it.
export PATH := $(HOME)/.local/share/mise/shims:$(HOME)/.local/bin:$(HOME)/go/bin:$(PATH)

# ──────────────────────────────────────────────────────────────
# Tool versions
# ──────────────────────────────────────────────────────────────
# SINGLE SOURCE OF TRUTH for tool versions is `.mise.toml` (and `go.mod`,
# `.nvmrc` which mise reads natively). The `deps` target runs `mise install`
# which provisions go, node, hadolint, golangci-lint, actionlint, shellcheck,
# gitleaks, trivy, govulncheck, act — pinned exactly as declared in
# `.mise.toml`. Renovate's first-class `mise` manager updates `.mise.toml`
# automatically; no per-tool customManager regex is needed.
#
# The constants below are the EXCEPTIONS — tools mise cannot manage (Docker
# images consumed via `docker run`, host-side multiarch helpers) — and are
# tracked by the generic Makefile customManager regex in `renovate.json`.
NODE_VERSION       := $(shell cat .nvmrc 2>/dev/null || echo 24)
GO_VER             := $(shell awk '/^go [0-9]/ {print $$2}' go.mod 2>/dev/null || echo 1.26.2)

# renovate: datasource=docker depName=minlag/mermaid-cli
MERMAID_CLI_VERSION := 11.12.0
# renovate: datasource=docker depName=plantuml/plantuml
PLANTUML_VERSION    := 1.2026.2
# renovate: datasource=docker depName=tonistiigi/binfmt versioning=loose
BINFMT_VERSION      := qemu-v10.2.1

DOCKER_PLATFORM    ?= linux/amd64
# Primary builder lineage for local `make image-build` — matches the CI matrix
# primary cell in .github/workflows/ci.yml. To build against the dlib19
# lineage locally instead, pass BUILDER_IMAGE=ghcr.io/andriykalashnykov/go-face/dlib19:<tag>
# (see CLAUDE.md "Build Notes" for details). Tracked by the dedicated
# `go-face builder image (Makefile default)` Renovate custom regex manager.
BUILDER_IMAGE      ?= ghcr.io/andriykalashnykov/go-face/dlib20:0.1.4
IMAGE_REPO         ?= andriykalashnykov/go-face-recognition

# Per-CI-matrix-lineage builder image pins. These MUST mirror the
# .github/workflows/ci.yml docker job `strategy.matrix.include[].builder`
# entries exactly so `make image-verify` exercises the same chain of trust
# as GitHub Actions. When a lineage is added or bumped upstream, update both
# this block AND the ci.yml matrix in the same PR (Renovate's
# "go-face builder images" group rule collapses the bumps into one PR).
BUILDER_DLIB20 := ghcr.io/andriykalashnykov/go-face/dlib20:0.1.4@sha256:c30c97c5d5a664d5f711f17d81a65d9558e17eeb73c0d7a76ff8dc11f6d1d958
BUILDER_DLIB19 := ghcr.io/andriykalashnykov/go-face/dlib19:0.1.4@sha256:4711c37c29f7af3623297b8a28fa135ed7f7e001d5688661916921bde7948c51

# ──────────────────────────────────────────────────────────────
# Project metadata
# ──────────────────────────────────────────────────────────────
projectname     ?= go-face-recognition
CURRENTTAG      := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
IMAGE_TAG       ?= $(CURRENTTAG)
NEWTAG          ?= $(shell bash -c 'read -p "Please provide a new tag (current tag - $(CURRENTTAG)): " newtag; echo $$newtag')
SEMVER_REGEX    := ^v[0-9]+\.[0-9]+\.[0-9]+$$

DOCKERFILES     := $(wildcard Dockerfile.*)

.DEFAULT_GOAL := help

# ──────────────────────────────────────────────────────────────
# Targets
# ──────────────────────────────────────────────────────────────

#help: @ List available targets
help:
	@grep -E '^#[a-zA-Z0-9_-]+:.*@' $(MAKEFILE_LIST) | sort | sed 's/^#//' | awk 'BEGIN {FS = ": *@ *"}; {printf "\033[36m%-28s\033[0m %s\n", $$1, $$2}'

#deps: @ Install all tools pinned in .mise.toml (auto-bootstraps mise locally)
# In CI, jdx/mise-action pre-installs mise on the runner, so this target's
# bootstrap branch (curl https://mise.run | sh) is locally-only-guarded by
# `[ -z "$$CI" ]`. Either way, the second step (`mise install`) runs in BOTH
# environments and is the actual contract: every tool listed in `.mise.toml`
# is provisioned at the pinned version. mise install is idempotent — no-op
# when everything is already at the pinned version.
deps:
	@if [ -z "$$CI" ] && ! command -v mise >/dev/null 2>&1; then \
		echo "Installing mise (no root required, installs to ~/.local/bin)..."; \
		curl -fsSL https://mise.run | sh; \
		echo ""; \
		echo "mise installed. Activate it in your shell, then re-run 'make deps':"; \
		echo '  bash: echo '\''eval "$$(~/.local/bin/mise activate bash)"'\'' >> ~/.bashrc'; \
		echo '  zsh:  echo '\''eval "$$(~/.local/bin/mise activate zsh)"'\''  >> ~/.zshrc'; \
		exit 0; \
	fi
	@command -v mise >/dev/null 2>&1 || { echo "ERROR: mise is required but not on PATH (CI environment should pre-install it via jdx/mise-action)"; exit 1; }
	@command -v git >/dev/null 2>&1 || { echo "ERROR: git is not installed"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is not installed"; exit 1; }
	@docker buildx version >/dev/null 2>&1 || { echo "ERROR: docker buildx is not installed"; exit 1; }
	@mise install
	@echo "All dependencies satisfied (provisioned via mise)."

#deps-check: @ Show installed mise tools
deps-check:
	@echo "--- .mise.toml ---"
	@cat .mise.toml
	@echo
	@echo "--- mise ls ---"
	@mise ls 2>&1 || { echo "ERROR: mise not installed — run 'make deps'"; exit 1; }

#clean: @ Remove build artifacts and generated files
clean:
	@rm -rf cmd/main coverage.out version.txt
	@echo "Cleaned build artifacts."

#test: @ Run unit tests on host (scoped to pure-Go packages that do not need CGO/dlib)
# The internal/usecases package transitively imports go-face (dlib C bindings),
# so it cannot be compiled on a host without libjpeg-dev/libdlib-dev/libopenblas-dev
# headers. `make test` stays scoped to internal/entity (pure Go, always compiles)
# so host developers get fast feedback without the full C toolchain. For the full
# suite incl. usecases + integration tests, use `make test-docker` /
# `make test-integration` which run inside the builder image.
test: deps
	@go test -cover -parallel=1 -v -coverprofile=coverage.out ./internal/entity/...
	@go tool cover -func=coverage.out | sort -rnk3

#test-docker: @ Run the full unit-test suite inside the builder image (CGO+dlib)
# Uses the Makefile's BUILDER_IMAGE pin so the host does not need a C toolchain.
# Mounts the repo read-write so coverage.out lands in the host workspace.
# PATH must include /usr/local/go/bin because `go test` internally exec's
# `go` (without an absolute path) to build and instrument coverage for
# main-package targets under ./cmd/...
test-docker: deps
	@docker run --rm \
		-v $(CURDIR):/app \
		-w /app \
		--user root \
		-e GOFLAGS=-mod=mod \
		-e PATH=/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
		$(BUILDER_IMAGE) \
		go test -cover -parallel=1 -v ./internal/...

#integration-test: @ Run integration tests (real dlib pipeline) inside the builder image
# Tests tagged with `//go:build integration` exercise classify/recognize against
# the baked-in models/, persons/, and images/ directories. Only runs inside the
# builder image because it links against dlib.
integration-test: deps
	@docker run --rm \
		-v $(CURDIR):/app \
		-w /app \
		--user root \
		-e GOFLAGS=-mod=mod \
		-e PATH=/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
		$(BUILDER_IMAGE) \
		go test -tags integration -v -count=1 -race ./internal/usecases/...

# Alias kept for muscle memory; `integration-test` is the canonical skill
# target. Remove once no tooling / muscle memory references the old name.
.PHONY: test-integration
test-integration: integration-test

#e2e: @ Build Dockerfile.go-face and run the compiled binary against baked-in test data
# Mirrors the CI docker job's GATE 1+GATE 3 (scan build + smoke test) on a
# single lineage (BUILDER_IMAGE default). Use `make image-verify` to run the
# same gates against every CI matrix lineage. Asserts face count AND
# identity classification AND annotated result.jpg is produced.
e2e: deps
	@echo "→ e2e: building go-face-recognition:e2e with BUILDER_IMAGE=$(BUILDER_IMAGE)"
	@docker build --quiet \
		-f Dockerfile.go-face \
		--build-arg BUILDER_IMAGE=$(BUILDER_IMAGE) \
		-t go-face-recognition:e2e . >/dev/null
	@echo "→ e2e: running the classification pipeline"
	@docker rm -f gfr-e2e >/dev/null 2>&1 || true
	@docker run --name gfr-e2e --entrypoint /app/main go-face-recognition:e2e | tee /tmp/gfr-e2e.log
	@grep -q 'Found [1-9][0-9]* faces' /tmp/gfr-e2e.log \
		|| { echo "FAIL: e2e did not find any faces in baked-in unknown.jpg"; docker rm -f gfr-e2e >/dev/null 2>&1; exit 1; }
	@grep -qE 'Person: (Trump|Biden)' /tmp/gfr-e2e.log \
		|| { echo "FAIL: e2e did not classify any baked-in identity (expected Trump or Biden)"; docker rm -f gfr-e2e >/dev/null 2>&1; exit 1; }
	@tmpjpg=$$(mktemp --suffix=.jpg); \
		docker cp gfr-e2e:/app/images/result.jpg "$$tmpjpg" >/dev/null 2>&1 \
			|| { echo "FAIL: e2e did not produce /app/images/result.jpg"; docker rm -f gfr-e2e >/dev/null 2>&1; rm -f "$$tmpjpg"; exit 1; }; \
		[ -s "$$tmpjpg" ] \
			|| { echo "FAIL: result.jpg is empty"; docker rm -f gfr-e2e >/dev/null 2>&1; rm -f "$$tmpjpg"; exit 1; }; \
		file -b "$$tmpjpg" | grep -qi 'JPEG image data' \
			|| { echo "FAIL: result.jpg is not JPEG ($$( file -b $$tmpjpg ))"; docker rm -f gfr-e2e >/dev/null 2>&1; rm -f "$$tmpjpg"; exit 1; }; \
		rm -f "$$tmpjpg"
	@docker rm -f gfr-e2e >/dev/null 2>&1 || true
	@echo "PASS: e2e classification pipeline — face count, identity, result.jpg all verified."

#e2e-compose: @ Run the pipeline through docker-compose.yml (catches compose drift)
# Builds via docker-compose.yml (Dockerfile.dlib-docker-go) instead of
# Dockerfile.go-face — this exercises the compose wiring (volume mounts,
# build context, service definition) that `make e2e` does not.
#
# Uses `docker compose run` (not `up`) because Dockerfile.dlib-docker-go
# has CMD ["tail","-f","/dev/null"] so that `make image-run-*` gets an
# interactive shell container. `run --rm --entrypoint /app/main app`
# overrides the CMD to actually execute the classification pipeline and
# exits when /app/main returns, which is what we need for a CI gate.
e2e-compose: deps
	@echo "→ e2e-compose: docker compose build (Dockerfile.dlib-docker-go)"
	@docker compose build --quiet
	@echo "→ e2e-compose: docker compose run --entrypoint /app/main app"
	@docker compose run --rm --entrypoint /app/main -T app | tee /tmp/gfr-e2e-compose.log
	@grep -q 'Found [1-9][0-9]* faces' /tmp/gfr-e2e-compose.log \
		|| { echo "FAIL: e2e-compose did not find any faces"; docker compose down --remove-orphans >/dev/null 2>&1; exit 1; }
	@grep -qE 'Person: (Trump|Biden)' /tmp/gfr-e2e-compose.log \
		|| { echo "FAIL: e2e-compose did not classify any baked-in identity"; docker compose down --remove-orphans >/dev/null 2>&1; exit 1; }
	@docker compose down --remove-orphans >/dev/null 2>&1 || true
	@echo "PASS: e2e-compose pipeline — face count + identity verified through docker-compose.yml."

#image-verify: @ Build + smoke-test Dockerfile.go-face against every CI matrix lineage
# This is the local equivalent of the docker job's GATE 1 (build-for-scan) +
# GATE 3 (smoke test) per matrix cell. If this target passes on your host, the
# CI docker job for the same lineages WILL NOT regress due to an upstream
# builder image change, a Dockerfile.go-face change, or a BUILDER_IMAGE bump.
# Closes the structural gap that allowed d33cc15's libdlib.a regression to ship:
# `make -n image-build` is a dry run — `make image-verify` does the real build.
#
# Run this as part of the pre-push checklist whenever Dockerfile.go-face,
# ci.yml matrix pins, or any Makefile `BUILDER_*` variable is touched.
image-verify: deps
	@set -euo pipefail; \
	for spec in \
		"dlib20:$(BUILDER_DLIB20)" \
		"dlib19:$(BUILDER_DLIB19)"; \
	do \
		lineage=$${spec%%:*}; \
		builder=$${spec#*:}; \
		echo "→ image-verify[$$lineage]: building with BUILDER_IMAGE=$$builder"; \
		docker build --quiet \
			-f Dockerfile.go-face \
			--build-arg BUILDER_IMAGE=$$builder \
			-t go-face-recognition:verify-$$lineage . >/dev/null; \
		echo "→ image-verify[$$lineage]: running smoke test"; \
		docker rm -f gfr-verify-$$lineage >/dev/null 2>&1 || true; \
		docker run --name gfr-verify-$$lineage --entrypoint /app/main go-face-recognition:verify-$$lineage \
			| tee /tmp/gfr-verify-$$lineage.log; \
		grep -q 'Found [1-9][0-9]* faces' /tmp/gfr-verify-$$lineage.log \
			|| { echo "FAIL: $$lineage smoke test did not find any faces"; docker rm -f gfr-verify-$$lineage >/dev/null 2>&1; exit 1; }; \
		grep -qE 'Person: (Trump|Biden)' /tmp/gfr-verify-$$lineage.log \
			|| { echo "FAIL: $$lineage did not classify any baked-in identity"; docker rm -f gfr-verify-$$lineage >/dev/null 2>&1; exit 1; }; \
		tmpjpg=$$(mktemp --suffix=.jpg); \
		docker cp gfr-verify-$$lineage:/app/images/result.jpg "$$tmpjpg" >/dev/null 2>&1 \
			|| { echo "FAIL: $$lineage did not produce result.jpg"; docker rm -f gfr-verify-$$lineage >/dev/null 2>&1; rm -f "$$tmpjpg"; exit 1; }; \
		file -b "$$tmpjpg" | grep -qi 'JPEG image data' \
			|| { echo "FAIL: $$lineage result.jpg is not JPEG"; docker rm -f gfr-verify-$$lineage >/dev/null 2>&1; rm -f "$$tmpjpg"; exit 1; }; \
		rm -f "$$tmpjpg"; \
		docker rm -f gfr-verify-$$lineage >/dev/null 2>&1 || true; \
		echo "PASS: image-verify[$$lineage] — face count + identity + result.jpg verified."; \
	done
	@echo "PASS: image-verify across all CI matrix lineages."

#build: @ Build Go binary for Linux amd64
build: deps
	@GOOS=linux GOARCH=amd64 CC=x86_64-linux-gnu-gcc CXX=x86_64-linux-gnu-g++ \
		CGO_ENABLED=1 \
		CGO_LDFLAGS="-lcblas -llapack_atlas -lblas -latlas -lgfortran -lquadmath" \
		go build --ldflags "-s -w -extldflags -static" \
		-tags "static netgo cgo static_build" \
		-o cmd/main cmd/main.go

#build-arm64: @ Build Go binary natively for macOS arm64
build-arm64: deps
	@CGO_ENABLED=1 \
		CGO_CXXFLAGS="-I/opt/homebrew/include -I/usr/local/include" \
		CGO_CFLAGS="-Wno-pessimizing-move -Wno-unused-but-set-variable" \
		CGO_LDFLAGS="-L/opt/homebrew/lib -L/opt/homebrew/opt/openblas/lib -L/usr/local/lib" \
		GOARCH=arm64 \
		go build --ldflags "-s -w" -o cmd/main cmd/main.go

#format: @ Auto-format Go source code (gofmt + goimports via golangci-lint fmt)
format: deps
	@golangci-lint fmt ./...
	@go mod tidy

#format-check: @ Check Go source is formatted (fails if gofmt/goimports would rewrite)
format-check: deps
	@diff=$$(gofmt -l . 2>/dev/null); \
		if [ -n "$$diff" ]; then \
			echo "ERROR: the following files need formatting:"; \
			echo "$$diff"; \
			echo "Run 'make format'."; \
			exit 1; \
		fi
	@echo "Go source is properly formatted."

#lint: @ Run Go linters (golangci-lint with gosec/gocritic/errorlint) and hadolint
lint: deps
	@golangci-lint run ./...
	@hadolint $(DOCKERFILES)

#lint-ci: @ Lint GitHub Actions workflows with actionlint
lint-ci: deps
	@actionlint

#secrets: @ Scan for hardcoded secrets with gitleaks
secrets: deps
	@gitleaks detect --source . --verbose --redact

#trivy-fs: @ Scan filesystem for vulnerabilities, secrets, and misconfigurations
trivy-fs: deps
	@trivy fs --scanners vuln,secret,misconfig --severity CRITICAL,HIGH .

#vulncheck: @ Check for known vulnerabilities in Go dependencies (requires C toolchain)
vulncheck: deps
	@govulncheck ./...

#vulncheck-docker: @ Run govulncheck inside the builder image (bypasses host CGO/dlib requirement)
# Reads the govulncheck pin from .mise.toml so the Docker invocation stays in
# lockstep with the host `vulncheck` target. mise itself is not required
# inside the builder image — we only extract the version string.
vulncheck-docker: deps
	@gv_version=$$(awk -F'"' '/govulncheck/ {print $$4}' .mise.toml); \
	docker run --rm \
		-v $(CURDIR):/app \
		-w /app \
		--user root \
		-e GOFLAGS=-mod=mod \
		-e PATH=/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
		$(BUILDER_IMAGE) \
		sh -c "go install golang.org/x/vuln/cmd/govulncheck@v$$gv_version && govulncheck ./..."

# NOTE: `vulncheck` is intentionally NOT included in `static-check`.
# govulncheck loads packages via `go build`, which for this project requires
# the full CGO toolchain (libjpeg-dev, libdlib-dev, libopenblas-dev, …) to
# compile the go-face / dlib bindings. On hosts without those headers the
# target fails early with "jpeglib.h: No such file or directory". Run it
# manually inside the builder Docker image, or once the C deps are installed.
# Tracked in CLAUDE.md "Upgrade Backlog" as "Add govulncheck as Docker CI step".
#mermaid-lint: @ Parse every ```mermaid block in markdown files via mermaid-cli (fails on render errors)
# Runs mermaid-cli (pinned via MERMAID_CLI_VERSION) in a Docker sandbox so
# no node / npm / puppeteer / chromium is needed on the host. Each extracted
# block is rendered to SVG; any syntax error from the mermaid parser fails
# the target. Wired into static-check because broken mermaid silently
# degrades README rendering on github.com (red "Unable to render rich
# display" box) and we want that caught in CI, not in production.
mermaid-lint:
	@set -euo pipefail; \
		if [ "$${ACT:-false}" = "true" ]; then \
			echo "→ mermaid-lint: SKIPPED under act (docker-in-docker volume mounts don't survive act's docker-cp workspace copy-in). Runs unmodified on real GitHub Actions."; \
			exit 0; \
		fi; \
		tmpdir=$$(mktemp -d -p "$(CURDIR)" .mermaid-lint.XXXXXX); \
		trap 'rm -rf "$$tmpdir"' EXIT; \
		i=0; \
		for md in $$(git ls-files '*.md' 2>/dev/null); do \
			awk '/^```mermaid$$/{flag=1; f=sprintf("%s/block-%04d.mmd", d, ++n); next} \
			     /^```$$/{if(flag){flag=0}; next} \
			     flag{print > f}' d="$$tmpdir" "$$md" 2>/dev/null || true; \
		done; \
		blocks=$$(ls "$$tmpdir"/*.mmd 2>/dev/null | wc -l); \
		if [ "$$blocks" = "0" ]; then \
			echo "No mermaid blocks found — skipping mermaid-lint."; exit 0; \
		fi; \
		echo "→ mermaid-lint: rendering $$blocks mermaid block(s) via minlag/mermaid-cli:$(MERMAID_CLI_VERSION)"; \
		for mmd in "$$tmpdir"/*.mmd; do \
			out="$${mmd%.mmd}.svg"; \
			docker run --rm -u $$(id -u):$$(id -g) \
				-v "$$tmpdir":/data \
				--entrypoint /home/mermaidcli/node_modules/.bin/mmdc \
				minlag/mermaid-cli:$(MERMAID_CLI_VERSION) \
				-p /puppeteer-config.json \
				-i "/data/$$(basename "$$mmd")" \
				-o "/data/$$(basename "$$out")" \
				-q \
				|| { echo "FAIL: $$mmd does not render"; cat "$$mmd"; exit 1; }; \
		done; \
		echo "PASS: all mermaid blocks render cleanly."

DIAGRAM_DIR := docs/diagrams
DIAGRAM_SRC := $(wildcard $(DIAGRAM_DIR)/*.puml)
DIAGRAM_OUT := $(patsubst $(DIAGRAM_DIR)/%.puml,$(DIAGRAM_DIR)/out/%.png,$(DIAGRAM_SRC))

#diagrams: @ Render PlantUML architecture diagrams to PNG (docs/diagrams/*.puml → out/*.png)
diagrams: $(DIAGRAM_OUT)

$(DIAGRAM_DIR)/out/%.png: $(DIAGRAM_DIR)/%.puml
	@mkdir -p $(DIAGRAM_DIR)/out
	@echo "→ diagrams: rendering $< via plantuml/plantuml:$(PLANTUML_VERSION)"
	@docker run --rm -v "$(CURDIR)/$(DIAGRAM_DIR):/work" -w /work \
		-u $$(id -u):$$(id -g) \
		-e HOME=/tmp -e _JAVA_OPTIONS=-Duser.home=/tmp \
		plantuml/plantuml:$(PLANTUML_VERSION) \
		-tpng -o out $(notdir $<)

#diagrams-clean: @ Remove rendered diagram artefacts (docs/diagrams/out/)
diagrams-clean:
	@rm -rf $(DIAGRAM_DIR)/out

#diagrams-check: @ Verify committed PlantUML output matches current source (CI drift gate)
diagrams-check: diagrams
	@git diff --exit-code -- $(DIAGRAM_DIR)/out \
		|| { echo "ERROR: docs/diagrams/*.puml changed but docs/diagrams/out/ not updated. Run 'make diagrams' and commit."; exit 1; }
	@echo "PASS: committed PlantUML output matches source."

#static-check-host: @ Host-runnable composite gate (no CGO/dlib needed) — used by CI
# Subset of `static-check` that excludes the CGO-requiring `lint` target so it
# can run on a stock GitHub Actions runner (no libjpeg-dev/libdlib-dev/openblas).
# Wired into the CI `static-check` job as a single composite step. The full
# `lint` (golangci-lint with gosec/gocritic on internal/usecases) is exercised
# inside the docker job's GATE 1 (build-for-scan) where the dlib C toolchain
# is available via the builder image.
static-check-host: lint-ci secrets trivy-fs mermaid-lint diagrams-check deps-prune-check
	@echo "Static check (host-safe subset) passed."

#static-check: @ Full composite quality gate (host-safe subset + CGO-requiring lint)
# Requires libjpeg-dev/libdlib-dev/libopenblas-dev/openblas headers on the host
# because `make lint` runs golangci-lint which loads CGO-bound packages
# (internal/usecases imports go-face → dlib). On hosts without those headers,
# use `make static-check-host` (CI) or run inside the builder image.
static-check: static-check-host lint
	@echo "Static check (full) passed."

#run: @ Run the application locally
run: deps
	@go run cmd/main.go

#update: @ Update dependency packages to latest versions and run CI
update: deps
	@go get -u ./...
	@go mod tidy
	@$(MAKE) ci

#release: @ Create and push a new semver tag
release: deps
	$(eval NT=$(NEWTAG))
	@if ! echo "$(NT)" | grep -qE '$(SEMVER_REGEX)'; then \
		echo "ERROR: '$(NT)' is not valid semver (expected vX.Y.Z)"; \
		exit 1; \
	fi
	@echo -n "Are you sure to create and push $(NT) tag? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo $(NT) > ./version.txt
	@git add version.txt
	@git commit -s -m "Cut $(NT) release"
	@git tag $(NT)
	@git push origin $(NT)
	@git push
	@echo "Done."

#image-bootstrap: @ Create Docker buildx multi-platform builder (idempotent)
image-bootstrap: deps
	@docker buildx inspect multi-platform-builder >/dev/null 2>&1 \
		|| docker buildx create --use --platform=linux/arm64,linux/amd64,linux/arm/v7 --name multi-platform-builder
	@docker buildx inspect --bootstrap

#image-build: @ Build Docker images via buildx
image-build: deps
	@docker buildx use multi-platform-builder
	@docker buildx build --load --platform $(DOCKER_PLATFORM) -f Dockerfile.go-face \
		--build-arg GO_VER=$(GO_VER) --build-arg BUILDER_IMAGE=$(BUILDER_IMAGE) \
		-t $(IMAGE_REPO):$(IMAGE_TAG)-go-face .
	@docker buildx build --load --platform $(DOCKER_PLATFORM) -f Dockerfile.ubuntu.builder \
		--build-arg GO_VER=$(GO_VER) -t $(IMAGE_REPO):$(IMAGE_TAG)-builder .
	@docker buildx build --load --platform $(DOCKER_PLATFORM) -f Dockerfile.alpine.runtime \
		-t $(IMAGE_REPO):$(IMAGE_TAG)-runtime .
	@docker buildx build --load --platform $(DOCKER_PLATFORM) -f Dockerfile.dlib-docker-go \
		--build-arg GO_VER=$(GO_VER) -t $(IMAGE_REPO):$(IMAGE_TAG)-dlib-docker-go .

#image-run-runtime: @ Run runtime image interactively
image-run-runtime: deps
	@docker run -it --rm --platform $(DOCKER_PLATFORM) $(IMAGE_REPO):$(IMAGE_TAG)-runtime /bin/sh

#image-run-go-face: @ Run go-face image interactively
image-run-go-face: deps
	@docker run -it --rm --platform $(DOCKER_PLATFORM) $(IMAGE_REPO):$(IMAGE_TAG)-go-face /bin/sh

#image-prune: @ Prune Docker system and buildx cache
image-prune: deps
	@docker system prune
	@docker buildx prune

#image-setup-multiarch: @ Install binfmt handlers for multi-arch Docker
image-setup-multiarch: deps
	@docker run --privileged --rm tonistiigi/binfmt:$(BINFMT_VERSION) --install all

#image-run-ghcr-amd64: @ Run GHCR runtime image on amd64
image-run-ghcr-amd64: deps
	@docker run -it --rm --platform linux/amd64 ghcr.io/andriykalashnykov/go-face-recognition:$(CURRENTTAG)-runtime /bin/sh

#image-run-ghcr-arm64: @ Run GHCR runtime image on arm64
image-run-ghcr-arm64: deps
	@docker run -it --rm --platform linux/arm64 ghcr.io/andriykalashnykov/go-face-recognition:$(CURRENTTAG)-runtime /bin/sh

#version: @ Print current version (tag)
version:
	@echo $(CURRENTTAG)

#tag-delete: @ Delete a specific tag locally and remotely
tag-delete:
	@if [ -z "$(TAG)" ]; then echo "ERROR: TAG is required. Usage: make tag-delete TAG=v1.0.0"; exit 1; fi
	@if ! echo "$(TAG)" | grep -qE '$(SEMVER_REGEX)'; then \
		echo "ERROR: '$(TAG)' is not valid semver (expected vX.Y.Z)"; \
		exit 1; \
	fi
	@echo -n "Are you sure to DELETE tag $(TAG) locally AND on origin? [y/N] " && read ans && [ $${ans:-N} = y ]
	@rm -f version.txt
	@git tag --delete $(TAG) 2>/dev/null || true
	@git push --delete origin $(TAG)

#deps-prune-check: @ Verify go.mod and go.sum are tidy
deps-prune-check: deps
	@tmp=$$(mktemp -d); \
		trap 'rm -rf "$$tmp"' EXIT; \
		cp go.mod "$$tmp/go.mod"; \
		cp go.sum "$$tmp/go.sum"; \
		go mod tidy; \
		if ! diff -q go.mod "$$tmp/go.mod" >/dev/null 2>&1 \
			|| ! diff -q go.sum "$$tmp/go.sum" >/dev/null 2>&1; then \
			echo "ERROR: go.mod/go.sum not tidy. Run 'go mod tidy'."; \
			cp "$$tmp/go.mod" go.mod; cp "$$tmp/go.sum" go.sum; \
			exit 1; \
		fi
	@echo "go.mod/go.sum are tidy."

#coverage-check: @ Fail if total unit-test coverage falls below 80%
coverage-check: test
	@go tool cover -func=coverage.out | awk '/total:/ { \
		pct=$$3; sub("%","",pct); \
		if (pct+0 < 80) { \
			printf "ERROR: coverage %s%% is below 80%% threshold\n", pct; exit 1 \
		} else { \
			printf "OK: coverage %s%% meets 80%% threshold\n", pct \
		} \
	}'

#ci: @ Run the full CI pipeline locally (deps, format-check, static-check, test, coverage-check, build)
ci: deps format-check static-check test coverage-check build
	@echo "CI pipeline passed."

#ci-run: @ Run GitHub Actions workflow locally using act
# act's synthetic push-event payload omits `repository.default_branch`, which
# `dorny/paths-filter` (the `changes` detector job) requires on push events to
# compute the diff base. Without a custom payload the action errors with
# "This action requires 'base' input to be configured or
#  'repository.default_branch' to be set in the event payload" — and every
# downstream job that gates on `needs.changes.outputs.code` skips. Generate a
# minimal payload with mktemp so the `changes` job behaves the same locally as
# in real GitHub Actions. See `/ci-workflow` skill "Path-Filter Strategy" §15a.
ci-run: deps
	@event=$$(mktemp --suffix=.json); \
		trap 'rm -f "$$event"' EXIT; \
		head=$$(git rev-parse HEAD); \
		before=$$(git rev-parse HEAD~1 2>/dev/null || echo "0000000000000000000000000000000000000000"); \
		printf '{"ref":"refs/heads/main","before":"%s","after":"%s","repository":{"default_branch":"main","name":"go-face-recognition","full_name":"AndriyKalashnykov/go-face-recognition"}}' "$$before" "$$head" > "$$event"; \
		act push --container-architecture linux/amd64 \
			--eventpath "$$event" \
			--artifact-server-path /tmp/act-artifacts

#renovate-bootstrap: @ Install mise + Node (per .mise.toml) for Renovate
renovate-bootstrap:
	@command -v mise >/dev/null 2>&1 || { \
		echo "Installing mise (no root required, installs to ~/.local/bin)..."; \
		curl -fsSL https://mise.run | sh; \
	}
	@command -v node >/dev/null 2>&1 || { \
		echo "Installing Node $(NODE_VERSION) via mise..."; \
		mise install node@$(NODE_VERSION); \
	}

#renovate-validate: @ Validate Renovate configuration
renovate-validate: renovate-bootstrap
	@if [ -n "$$GH_ACCESS_TOKEN" ]; then \
		GITHUB_COM_TOKEN=$$GH_ACCESS_TOKEN npx --yes renovate --platform=local; \
	else \
		echo "Warning: GH_ACCESS_TOKEN not set, some dependency lookups may fail"; \
		npx --yes renovate --platform=local; \
	fi

.PHONY: help deps deps-check clean test \
        test-docker integration-test e2e e2e-compose image-verify build \
        build-arm64 format format-check lint lint-ci mermaid-lint secrets trivy-fs vulncheck static-check \
        run update release image-bootstrap image-build image-run-runtime image-run-go-face image-prune \
        image-setup-multiarch image-run-ghcr-amd64 image-run-ghcr-arm64 \
        version tag-delete ci ci-run renovate-bootstrap renovate-validate \
        deps-prune-check coverage-check vulncheck-docker \
        diagrams diagrams-clean diagrams-check static-check-host
