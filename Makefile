projectname?=go-face-recognition

CURRENTTAG:=$(shell git describe --tags --abbrev=0)
NEWTAG ?= $(shell bash -c 'read -p "Please provide a new tag (currnet tag - ${CURRENTTAG}): " newtag; echo $$newtag')

default: help

help: ## list makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}'

testdata: ## get test data
	git clone https://github.com/Kagami/go-face-testdata testdatas

test: ## run tests
	go test --cover -parallel=1 -v -coverprofile=coverage.out -v ./...
	go tool cover -func=coverage.out | sort -rnk3

build: ## build golang binary
	@GOOS=linux GOARCH=amd64 CC=x86_64-linux-gnu-gcc CXX=x86_64-linux-gnu-g++ CGO_ENABLED=1 CGO_LDFLAGS="-lcblas -llapack_atlas -lblas -latlas -lgfortran -lquadmath" go build --ldflags "-s -w -extldflags -static" -tags "static netgo cgo static_build" -o cmd/main cmd/main.go

update: ## update dependency packages to latest versions
	@go get -u ./...; go mod tidy

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

bootstrap: ## buildx bootstrap
	docker buildx create --use --platform=linux/arm64,linux/amd64,linux/arm/v7 --name multi-platform-builder
	docker buildx inspect --bootstrap

bi: ## build image
	docker buildx use multi-platform-builder
	docker buildx build --load --platform linux/arm/v7 -f Dockerfile.go-face --build-arg GO_VER=1.25.3 -t andriykalashnykov/go-face-recognition:latest-go-face .
#	docker buildx build --load --platform linux/arm/v7 -f Dockerfile.ubuntu.builder --build-arg GO_VER=1.25.3  -t andriykalashnykov/go-face-recognition:latest-builder .
#	docker buildx build --load --platform linux/arm/v7 -f Dockerfile.alpine.runtme.local -t andriykalashnykov/go-face-recognition:latest-runtime .
#	docker buildx build --load --platform linux/arm/v7 -f Dockerfile.dlib-docker-go --build-arg GO_VER=1.25.3 -t andriykalashnykov/go-face-recognition:latest-dlib-docker-go .


ri: ## run image
	docker run -it --rm --platform linux/arm/v7 andriykalashnykov/go-face-recognition:latest-runtime /bin/sh
	docker run -it --rm --platform linux/arm/v7 andriykalashnykov/go-face-recognition:latest-go-face /bin/sh

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

ra-amd64:
	docker run -it --rm --platform linux/amd64 ghcr.io/andriykalashnykov/go-face-recognition:v0.0.2-runtime /bin/sh

ra-arm64:
	docker run -it --rm --platform linux/arm64 ghcr.io/andriykalashnykov/go-face-recognition:v0.0.2-runtime /bin/sh

dt:
	rm -f version.txt
	git push --delete origin v0.0.1
	git tag --delete v0.0.1
