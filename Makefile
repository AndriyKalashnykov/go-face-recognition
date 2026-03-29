# ──────────────────────────────────────────────────────────────
# Tool versions (pinned)
# ──────────────────────────────────────────────────────────────
NVM_VERSION      ?= 0.40.4
GO_VER           ?= 1.25.7
ACT_VERSION      := 0.2.86
HADOLINT_VERSION := 2.12.0
GOLANGCI_VERSION := 2.11.1
DOCKER_PLATFORM  ?= linux/arm/v7
BUILDER_IMAGE    ?= ghcr.io/andriykalashnykov/go-face:v0.0.3
IMAGE_REPO       ?= andriykalashnykov/go-face-recognition

# ──────────────────────────────────────────────────────────────
# Project metadata
# ──────────────────────────────────────────────────────────────
projectname     ?= go-face-recognition
CURRENTTAG      := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
NEWTAG          ?= $(shell bash -c 'read -p "Please provide a new tag (current tag - $(CURRENTTAG)): " newtag; echo $$newtag')
SEMVER_REGEX    := ^v[0-9]+\.[0-9]+\.[0-9]+$$

.DEFAULT_GOAL := help

# ──────────────────────────────────────────────────────────────
# Targets
# ──────────────────────────────────────────────────────────────

#help: @ List available targets
help:
	@grep -E '^#[a-zA-Z0-9_-]+:.*@' $(MAKEFILE_LIST) | sort | sed 's/^#//' | awk 'BEGIN {FS = ": *@ *"}; {printf "\033[36m%-24s\033[0m %s\n", $$1, $$2}'

#deps: @ Verify required tool dependencies
deps:
	@command -v go   >/dev/null 2>&1 || { echo "ERROR: go is not installed";   exit 1; }
	@command -v git  >/dev/null 2>&1 || { echo "ERROR: git is not installed";  exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is not installed"; exit 1; }
	@command -v golangci-lint >/dev/null 2>&1 || { echo "Installing golangci-lint v$(GOLANGCI_VERSION)..."; \
		curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh | sh -s -- -b $$(go env GOPATH)/bin v$(GOLANGCI_VERSION); }
	@echo "All dependencies satisfied."

#deps-act: @ Install act for local CI
deps-act: deps
	@command -v act >/dev/null 2>&1 || { echo "Installing act $(ACT_VERSION)..."; \
		curl -sSfL https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash -s -- -b /usr/local/bin v$(ACT_VERSION); \
	}

#deps-hadolint: @ Install hadolint for Dockerfile linting
deps-hadolint:
	@command -v hadolint >/dev/null 2>&1 || { echo "Installing hadolint $(HADOLINT_VERSION)..."; \
		curl -sSfL -o /tmp/hadolint https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-Linux-x86_64 && \
		install -m 755 /tmp/hadolint /usr/local/bin/hadolint && \
		rm -f /tmp/hadolint; \
	}

#clean: @ Remove build artifacts and generated files
clean:
	@rm -rf cmd/main coverage.out testdatas version.txt
	@echo "Cleaned build artifacts."

#testdata: @ Clone test data repository
testdata:
	@git clone https://github.com/Kagami/go-face-testdata testdatas

#test: @ Run tests with coverage
test: deps
	@go test --cover -parallel=1 -v -coverprofile=coverage.out -v ./...
	@go tool cover -func=coverage.out | sort -rnk3

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

#lint: @ Run Go linters and Dockerfile linting
lint: deps deps-hadolint
	@golangci-lint run ./...
	@hadolint Dockerfile.go-face

#run: @ Run the application locally
run: deps
	@go run cmd/main.go

#update: @ Update dependency packages to latest versions
update: deps
	@go get -u ./...
	@go mod tidy

#release: @ Create and push a new semver tag
release:
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

#bootstrap: @ Create Docker buildx multi-platform builder
bootstrap:
	@docker buildx create --use --platform=linux/arm64,linux/amd64,linux/arm/v7 --name multi-platform-builder
	@docker buildx inspect --bootstrap

#image-build: @ Build Docker images via buildx
image-build:
	@docker buildx use multi-platform-builder
	@docker buildx build --load --platform $(DOCKER_PLATFORM) -f Dockerfile.go-face \
		--build-arg GO_VER=$(GO_VER) -t $(IMAGE_REPO):latest-go-face .
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

#version: @ Print current version (tag)
version:
	@echo $(CURRENTTAG)

#docker-prune: @ Prune Docker system and buildx cache
docker-prune:
	@docker system prune
	@docker buildx prune

#docker-setup-multiarch: @ Install binfmt handlers for multi-arch Docker
docker-setup-multiarch:
	@docker run --privileged --rm tonistiigi/binfmt --install all
	@docker run -it --rm --platform linux/arm64 arm64v8/ubuntu sh

#run-ghcr-amd64: @ Run GHCR runtime image on amd64
run-ghcr-amd64:
	@docker run -it --rm --platform linux/amd64 ghcr.io/andriykalashnykov/go-face-recognition:v0.0.3-runtime /bin/sh

#run-ghcr-arm64: @ Run GHCR runtime image on arm64
run-ghcr-arm64:
	@docker run -it --rm --platform linux/arm64 ghcr.io/andriykalashnykov/go-face-recognition:v0.0.3-runtime /bin/sh

#tag-delete: @ Delete a specific tag locally and remotely
tag-delete:
	@rm -f version.txt
	@git push --delete origin v0.0.3
	@git tag --delete v0.0.3

#ci: @ Run the full CI pipeline locally (deps, lint, test, build)
ci: deps lint test build
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
		nvm install --lts; \
	}

#renovate-validate: @ Validate Renovate configuration
renovate-validate: renovate-bootstrap
	@npx --yes renovate --platform=local

.PHONY: help deps deps-act deps-hadolint clean testdata test build build-arm64 \
        lint run update release bootstrap image-build image-run version \
        docker-prune docker-setup-multiarch run-ghcr-amd64 run-ghcr-arm64 \
        tag-delete ci ci-run renovate-bootstrap renovate-validate
