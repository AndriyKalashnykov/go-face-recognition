projectname?=go-face-recognition

CURRENTTAG:=$(shell git describe --tags --abbrev=0)
NEWTAG ?= $(shell bash -c 'read -p "Please provide a new tag (currnet tag - ${CURRENTTAG}): " newtag; echo $$newtag')

default: help

.PHONY: help
help: ## list makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}'

.PHONY: testdata
testdata: ## get test data
	git clone https://github.com/Kagami/go-face-testdata testdatas

.PHONY: test
test: ## run tests
	go test --cover -parallel=1 -v -coverprofile=coverage.out -v ./...
	go tool cover -func=coverage.out | sort -rnk3

.PHONY: build
build: ## build golang binary
	@go build cmd/main.go -ldflags "-X main.version=$(shell git describe --abbrev=0 --tags)" -o cmd/main

.PHONY: update
update: ## update dependency packages to latest versions
	@go get -u ./...; go mod tidy

.PHONY: release
release: ## create and push a new tag
	$(eval NT=$(NEWTAG))
	@echo -n "Are you sure to create and push ${NT} tag? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo ${NT} > ./version.txt
	@git add -A
	@git commit -a -s -m "Cut ${NT} release"
	@git tag ${NT}
	@git push origin ${NT}
	@git push
	@echo "Done."

.PHONY: bootstrap
bootstrap: ## bootstrap build dblib image
	docker buildx create --use --platform=linux/arm64,linux/amd64 --name multi-platform-builder
	docker buildx inspect --bootstrap

.PHONY: bi
bi: ## build go-face-recognition Docker image
	docker build -f Dockerfile.ubuntu.builder -t andriykalashnykov/go-face-recognition:latest-builder .
	docker build -f Dockerfile.alpine.runtme  -t andriykalashnykov/go-face-recognition:latest .

.PHONY: ri
ri: ## run go-face-recognition image
	docker run --rm -it --platform linux/arm64 andriykalashnykov/go-face-recognition:latest /bin/sh

version: ## Print current version(tag)
	@echo $(shell git describe --tags --abbrev=0)

dp:
	docker system prune
	docker buildx prune

# setup Docker to run arm64 images on Ubuntu x86_64
# https://jkfran.com/running-ubuntu-arm-with-docker/
# https://www.stereolabs.com/docs/docker/building-arm-container-on-x86
# https://github.com/carlosperate/arm-none-eabi-gcc-action
# https://embeddedinventor.com/a-complete-beginners-guide-to-the-gnu-arm-toolchain-part-1/
# export PATH=/path/to/install/dir/bin:$PATH
sd:
	docker run --privileged --rm tonistiigi/binfmt --install all
	docker run -it --rm --platform linux/arm64 arm64v8/ubuntu sh
# uname -m
# aarch64


ba:
	docker build -f Dockerfile.amd64 -t docker.io/anriykalashnykov/amd64:latest .
	docker build -f Dockerfile.arm64 -t docker.io/anriykalashnykov/arm64:latest .

ra:
	docker run -it --rm --platform linux/arm64 docker.io/anriykalashnykov/arm64:latest /bin/sh

dt:
	rm -f version.txt
	git push --delete origin v0.0.1
	git tag --delete v0.0.1
