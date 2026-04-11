# Ensure tools installed to ~/.local/bin and $(GOPATH)/bin (hadolint, act,
# gitleaks, actionlint, govulncheck, trivy, shellcheck, etc.) are on PATH for
# every recipe — needed inside the act runner container where neither path is
# preconfigured. Exported so every sub-shell the recipes spawn inherits it.
export PATH := $(HOME)/.local/bin:$(HOME)/go/bin:$(PATH)

# ──────────────────────────────────────────────────────────────
# Tool versions (pinned, Renovate-tracked via inline comments)
# ──────────────────────────────────────────────────────────────
# renovate: datasource=github-releases depName=nvm-sh/nvm
NVM_VERSION        := 0.40.4
# Source of truth: .nvmrc (major version only, e.g. "24")
NODE_VERSION       := $(shell cat .nvmrc 2>/dev/null || echo 24)
# renovate: datasource=docker depName=golang
GO_VER             := 1.26.2
# renovate: datasource=github-releases depName=nektos/act
ACT_VERSION        := 0.2.87
# renovate: datasource=github-releases depName=hadolint/hadolint
HADOLINT_VERSION   := 2.14.0
# renovate: datasource=github-releases depName=golangci/golangci-lint
GOLANGCI_VERSION   := 2.11.4
# renovate: datasource=github-releases depName=rhysd/actionlint
ACTIONLINT_VERSION := 1.7.12
# renovate: datasource=github-releases depName=koalaman/shellcheck
SHELLCHECK_VERSION := 0.11.0
# renovate: datasource=github-releases depName=gitleaks/gitleaks
GITLEAKS_VERSION   := 8.30.1
# renovate: datasource=github-releases depName=aquasecurity/trivy
TRIVY_VERSION      := 0.69.3
# renovate: datasource=go depName=golang.org/x/vuln/cmd/govulncheck
GOVULNCHECK_VERSION := 1.1.4

DOCKER_PLATFORM    ?= linux/amd64
# Primary builder lineage for local `make image-build` — matches the CI matrix
# primary cell in .github/workflows/ci.yml. To build against the dlib19
# lineage locally instead, pass BUILDER_IMAGE=ghcr.io/andriykalashnykov/go-face/dlib19:<tag>
# (see CLAUDE.md "Build Notes" for details). Tracked by the dedicated
# `go-face builder image (Makefile default)` Renovate custom regex manager.
BUILDER_IMAGE      ?= ghcr.io/andriykalashnykov/go-face/dlib20:0.1.2
IMAGE_REPO         ?= andriykalashnykov/go-face-recognition

# ──────────────────────────────────────────────────────────────
# Project metadata
# ──────────────────────────────────────────────────────────────
projectname     ?= go-face-recognition
CURRENTTAG      := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
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

#deps: @ Verify required tool dependencies
deps:
	@command -v go     >/dev/null 2>&1 || { echo "ERROR: go is not installed";     exit 1; }
	@command -v git    >/dev/null 2>&1 || { echo "ERROR: git is not installed";    exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is not installed"; exit 1; }
	@command -v golangci-lint >/dev/null 2>&1 || { echo "Installing golangci-lint v$(GOLANGCI_VERSION)..."; \
		curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh | sh -s -- -b $$(go env GOPATH)/bin v$(GOLANGCI_VERSION); }
	@echo "All dependencies satisfied."

#deps-act: @ Install act for local CI
deps-act: deps
	@command -v act >/dev/null 2>&1 || { echo "Installing act $(ACT_VERSION)..."; \
		mkdir -p $$HOME/.local/bin; \
		curl -sSfL https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b $$HOME/.local/bin v$(ACT_VERSION); \
	}

#deps-hadolint: @ Install hadolint for Dockerfile linting
deps-hadolint:
	@command -v hadolint >/dev/null 2>&1 || { echo "Installing hadolint $(HADOLINT_VERSION)..."; \
		mkdir -p $$HOME/.local/bin; \
		curl -sSfL -o /tmp/hadolint https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-Linux-x86_64 && \
		install -m 755 /tmp/hadolint $$HOME/.local/bin/hadolint && \
		rm -f /tmp/hadolint; \
	}

#deps-shellcheck: @ Install shellcheck for shell script linting
deps-shellcheck:
	@command -v shellcheck >/dev/null 2>&1 || { echo "Installing shellcheck $(SHELLCHECK_VERSION)..."; \
		mkdir -p $$HOME/.local/bin; \
		curl -sSfL -o /tmp/shellcheck.tar.xz https://github.com/koalaman/shellcheck/releases/download/v$(SHELLCHECK_VERSION)/shellcheck-v$(SHELLCHECK_VERSION).linux.x86_64.tar.xz && \
		tar -xJf /tmp/shellcheck.tar.xz -C /tmp && \
		install -m 755 /tmp/shellcheck-v$(SHELLCHECK_VERSION)/shellcheck $$HOME/.local/bin/shellcheck && \
		rm -rf /tmp/shellcheck-v$(SHELLCHECK_VERSION) /tmp/shellcheck.tar.xz; \
	}

#deps-actionlint: @ Install actionlint for GitHub Actions workflow linting
deps-actionlint: deps deps-shellcheck
	@command -v actionlint >/dev/null 2>&1 || { echo "Installing actionlint $(ACTIONLINT_VERSION)..."; \
		go install github.com/rhysd/actionlint/cmd/actionlint@v$(ACTIONLINT_VERSION); }

#deps-gitleaks: @ Install gitleaks for secret scanning
deps-gitleaks:
	@command -v gitleaks >/dev/null 2>&1 || { echo "Installing gitleaks $(GITLEAKS_VERSION)..."; \
		mkdir -p $$HOME/.local/bin; \
		curl -sSfL -o /tmp/gitleaks.tar.gz https://github.com/gitleaks/gitleaks/releases/download/v$(GITLEAKS_VERSION)/gitleaks_$(GITLEAKS_VERSION)_linux_x64.tar.gz && \
		tar -xzf /tmp/gitleaks.tar.gz -C /tmp gitleaks && \
		install -m 755 /tmp/gitleaks $$HOME/.local/bin/gitleaks && \
		rm -f /tmp/gitleaks.tar.gz /tmp/gitleaks; \
	}

#deps-trivy: @ Install Trivy for filesystem and image security scanning
deps-trivy: deps
	@command -v trivy >/dev/null 2>&1 || { echo "Installing trivy $(TRIVY_VERSION)..."; \
		curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b $$(go env GOPATH)/bin v$(TRIVY_VERSION); }

#deps-govulncheck: @ Install govulncheck for Go module vulnerability scanning
deps-govulncheck: deps
	@command -v govulncheck >/dev/null 2>&1 || { echo "Installing govulncheck $(GOVULNCHECK_VERSION)..."; \
		go install golang.org/x/vuln/cmd/govulncheck@v$(GOVULNCHECK_VERSION); }

#clean: @ Remove build artifacts and generated files
clean:
	@rm -rf cmd/main coverage.out testdatas version.txt
	@echo "Cleaned build artifacts."

#testdata: @ Clone test data repository
testdata: deps
	@git clone https://github.com/Kagami/go-face-testdata testdatas

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

#test-integration: @ Run integration tests (real dlib pipeline) inside the builder image
# Tests tagged with `//go:build integration` exercise classify/recognize against
# the baked-in models/, persons/, and images/ directories. Only runs inside the
# builder image because it links against dlib.
test-integration: deps
	@docker run --rm \
		-v $(CURDIR):/app \
		-w /app \
		--user root \
		-e GOFLAGS=-mod=mod \
		-e PATH=/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
		$(BUILDER_IMAGE) \
		go test -tags integration -v -count=1 ./internal/usecases/...

#e2e: @ Build Dockerfile.go-face and run the compiled binary against baked-in test data
# Mirrors the CI docker job's GATE 1+GATE 3 (scan build + smoke test) on a
# single lineage (BUILDER_IMAGE default). Use `make image-verify` to run the
# same gates against every CI matrix lineage.
e2e: deps
	@echo "→ e2e: building go-face-recognition:e2e with BUILDER_IMAGE=$(BUILDER_IMAGE)"
	@docker build --quiet \
		-f Dockerfile.go-face \
		--build-arg BUILDER_IMAGE=$(BUILDER_IMAGE) \
		-t go-face-recognition:e2e . >/dev/null
	@echo "→ e2e: running the classification pipeline"
	@docker run --rm --entrypoint /app/main go-face-recognition:e2e | tee /tmp/gfr-e2e.log
	@grep -q 'Found [1-9][0-9]* faces' /tmp/gfr-e2e.log \
		|| { echo "FAIL: e2e did not find any faces in the baked-in unknown.jpg"; exit 1; }
	@echo "PASS: e2e classification pipeline produced ≥1 face."

# Per-CI-matrix-lineage builder image pins. These MUST mirror the
# .github/workflows/ci.yml docker job `strategy.matrix.include[].builder`
# entries exactly so `make image-verify` exercises the same chain of trust
# as GitHub Actions. When a lineage is added or bumped upstream, update both
# this block AND the ci.yml matrix in the same PR (Renovate's
# "go-face builder images" group rule collapses the bumps into one PR).
BUILDER_DLIB20 := ghcr.io/andriykalashnykov/go-face/dlib20:0.1.2@sha256:349946e5ff74011a27f010d6250800b3c1506acfb3a452e941f2cdb2cbd7d750
BUILDER_DLIB19 := ghcr.io/andriykalashnykov/go-face/dlib19:0.1.2@sha256:694ce629ba44265cc0d378a1137bce57cba94b9e5ca27cd7c1be5a5f5fc61872

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
	@set -e; \
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
		docker run --rm --entrypoint /app/main go-face-recognition:verify-$$lineage \
			| tee /tmp/gfr-verify-$$lineage.log; \
		grep -q 'Found [1-9][0-9]* faces' /tmp/gfr-verify-$$lineage.log \
			|| { echo "FAIL: $$lineage smoke test did not find any faces"; exit 1; }; \
		echo "PASS: image-verify[$$lineage]"; \
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

#format: @ Auto-format Go source code
format: deps
	@gofmt -s -w .
	@go mod tidy

#lint: @ Run Go linters (golangci-lint with gosec/gocritic/errorlint) and hadolint
lint: deps deps-hadolint
	@golangci-lint run ./...
	@for f in $(DOCKERFILES); do echo "hadolint $$f"; hadolint $$f || exit 1; done

#lint-ci: @ Lint GitHub Actions workflows with actionlint
lint-ci: deps-actionlint
	@actionlint

#secrets: @ Scan for hardcoded secrets with gitleaks
secrets: deps-gitleaks
	@gitleaks detect --source . --verbose --redact

#trivy-fs: @ Scan filesystem for vulnerabilities, secrets, and misconfigurations
trivy-fs: deps-trivy
	@trivy fs --scanners vuln,secret,misconfig --severity CRITICAL,HIGH .

#vulncheck: @ Check for known vulnerabilities in Go dependencies (requires C toolchain)
vulncheck: deps-govulncheck
	@govulncheck ./...

# NOTE: `vulncheck` is intentionally NOT included in `static-check`.
# govulncheck loads packages via `go build`, which for this project requires
# the full CGO toolchain (libjpeg-dev, libdlib-dev, libopenblas-dev, …) to
# compile the go-face / dlib bindings. On hosts without those headers the
# target fails early with "jpeglib.h: No such file or directory". Run it
# manually inside the builder Docker image, or once the C deps are installed.
# Tracked in CLAUDE.md "Upgrade Backlog" as "Add govulncheck as Docker CI step".
#static-check: @ Composite quality gate (lint-ci, lint, secrets, trivy-fs, deps-prune-check)
static-check: lint-ci lint secrets trivy-fs deps-prune-check
	@echo "Static check passed."

#run: @ Run the application locally
run: deps
	@go run cmd/main.go

#update: @ Update dependency packages to latest versions
update: deps
	@go get -u ./...
	@go mod tidy

#release: @ Create and push a new semver tag
release: deps
	$(eval NT=$(NEWTAG))
	@if ! echo "$(NT)" | grep -qE '$(SEMVER_REGEX)'; then \
		echo "ERROR: '$(NT)' is not valid semver (expected vX.Y.Z)"; \
		exit 1; \
	fi
	@echo -n "Are you sure to create and push $(NT) tag? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo $(NT) > ./version.txt
	@git add -A
	@git commit -a -s -m "Cut $(NT) release"
	@git tag $(NT)
	@git push origin $(NT)
	@git push
	@echo "Done."

#image-bootstrap: @ Create Docker buildx multi-platform builder
image-bootstrap:
	@docker buildx create --use --platform=linux/arm64,linux/amd64,linux/arm/v7 --name multi-platform-builder
	@docker buildx inspect --bootstrap

#image-build: @ Build Docker images via buildx
image-build:
	@docker buildx use multi-platform-builder
	@docker buildx build --load --platform $(DOCKER_PLATFORM) -f Dockerfile.go-face \
		--build-arg GO_VER=$(GO_VER) --build-arg BUILDER_IMAGE=$(BUILDER_IMAGE) \
		-t $(IMAGE_REPO):latest-go-face .
	@docker buildx build --load --platform $(DOCKER_PLATFORM) -f Dockerfile.ubuntu.builder \
		--build-arg GO_VER=$(GO_VER) -t $(IMAGE_REPO):latest-builder .
	@docker buildx build --load --platform $(DOCKER_PLATFORM) -f Dockerfile.alpine.runtme.local \
		-t $(IMAGE_REPO):latest-runtime .
	@docker buildx build --load --platform $(DOCKER_PLATFORM) -f Dockerfile.dlib-docker-go \
		--build-arg GO_VER=$(GO_VER) -t $(IMAGE_REPO):latest-dlib-docker-go .

#image-run: @ Run Docker images interactively
image-run:
	@docker run -it --rm --platform $(DOCKER_PLATFORM) $(IMAGE_REPO):latest-runtime /bin/sh
	@docker run -it --rm --platform $(DOCKER_PLATFORM) $(IMAGE_REPO):latest-go-face /bin/sh

#image-prune: @ Prune Docker system and buildx cache
image-prune:
	@docker system prune
	@docker buildx prune

#image-setup-multiarch: @ Install binfmt handlers for multi-arch Docker
image-setup-multiarch:
	@docker run --privileged --rm tonistiigi/binfmt --install all
	@docker run -it --rm --platform linux/arm64 arm64v8/ubuntu sh

#image-run-ghcr-amd64: @ Run GHCR runtime image on amd64
image-run-ghcr-amd64:
	@docker run -it --rm --platform linux/amd64 ghcr.io/andriykalashnykov/go-face-recognition:$(CURRENTTAG)-runtime /bin/sh

#image-run-ghcr-arm64: @ Run GHCR runtime image on arm64
image-run-ghcr-arm64:
	@docker run -it --rm --platform linux/arm64 ghcr.io/andriykalashnykov/go-face-recognition:$(CURRENTTAG)-runtime /bin/sh

#version: @ Print current version (tag)
version:
	@echo $(CURRENTTAG)

#tag-delete: @ Delete a specific tag locally and remotely
tag-delete:
	@if [ -z "$(TAG)" ]; then echo "ERROR: TAG is required. Usage: make tag-delete TAG=v1.0.0"; exit 1; fi
	@rm -f version.txt
	@git push --delete origin $(TAG)
	@git tag --delete $(TAG)

#deps-prune-check: @ Verify go.mod and go.sum are tidy
deps-prune-check: deps
	@cp go.mod go.mod.bak && cp go.sum go.sum.bak
	@go mod tidy
	@if ! diff -q go.mod go.mod.bak >/dev/null 2>&1 || ! diff -q go.sum go.sum.bak >/dev/null 2>&1; then \
		echo "ERROR: go.mod/go.sum not tidy. Run 'go mod tidy'."; \
		mv go.mod.bak go.mod; mv go.sum.bak go.sum; \
		exit 1; \
	fi
	@rm -f go.mod.bak go.sum.bak
	@echo "go.mod/go.sum are tidy."

#ci: @ Run the full CI pipeline locally (deps, static-check, test, build)
ci: deps static-check test build
	@echo "CI pipeline passed."

#ci-run: @ Run GitHub Actions workflow locally using act
ci-run: deps-act
	@act push --container-architecture linux/amd64 \
		--artifact-server-path /tmp/act-artifacts

#renovate-bootstrap: @ Install nvm and npm for Renovate
renovate-bootstrap:
	@command -v node >/dev/null 2>&1 || { \
		echo "Installing nvm $(NVM_VERSION)..."; \
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$(NVM_VERSION)/install.sh | bash; \
		export NVM_DIR="$$HOME/.nvm"; \
		[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
		nvm install $(NODE_VERSION); \
	}

#renovate-validate: @ Validate Renovate configuration
renovate-validate: renovate-bootstrap
	@npx --yes renovate --platform=local

.PHONY: help deps deps-act deps-hadolint deps-shellcheck deps-actionlint \
        deps-gitleaks deps-trivy deps-govulncheck clean testdata test \
        test-docker test-integration e2e image-verify build \
        build-arm64 format lint lint-ci secrets trivy-fs vulncheck static-check \
        run update release image-bootstrap image-build image-run image-prune \
        image-setup-multiarch image-run-ghcr-amd64 image-run-ghcr-arm64 \
        version tag-delete ci ci-run renovate-bootstrap renovate-validate \
        deps-prune-check
