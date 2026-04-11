ARG BUILDER_IMAGE="ubuntu:noble-20260324@sha256:84e77dee7d1bc93fb029a45e3c6cb9d8aa4831ccfcc7103d36e876938d28895b"

# https://hub.docker.com/_/ubuntu/tags
FROM ${BUILDER_IMAGE} AS builder

ARG GO_VER=1.26.2
# Re-declare the buildx-auto-provided TARGETARCH so it is visible to RUN
# layers (ARG values from before FROM do NOT automatically propagate).
# Used by the conditional CGO_LDFLAGS + cross-compile blocks below.
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

# Use bash with pipefail so any failure in a piped command (notably the
# sha256sum verification pipeline below) fails the RUN layer instead of
# silently succeeding on the last command's exit status.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install cmake + cross-compile toolchains + go-face build dependencies in a
# single layer. Ubuntu's `libdlib-dev` package ships BOTH libdlib.a and
# libdlib.so in /usr/lib/x86_64-linux-gnu/ (dlib 19.24.0 on noble at the time
# of writing — older than the dlib-docker chain's 20.0.1, but self-consistent
# because this image builds AND runs the binary with the same dlib version).
#
# The `dpkg --add-architecture` block + cross-compile installs are gated on
# amd64/arm64 hosts because those are the only TARGETARCH values we cross-
# build from. On an arm/v7 host, cross builds are native.
#
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        cmake \
        build-essential \
        curl \
        locales \
        net-tools \
        wget \
        libopenblas-dev \
        libblas-dev \
        libblaspp-dev \
        libatlas-base-dev \
        libgslcblas0 \
        libjpeg-dev \
        libpng-dev \
        liblapack-dev \
        libjpeg-turbo8-dev \
        gfortran \
        libgfortran5 \
        libdlib-dev \
    && rm -rf /var/lib/apt/lists/*

# NOTE: the previous incarnation of this Dockerfile installed gcc/g++
# cross-compile toolchains for arm64/armel/armhf plus matching libapparmor/
# libseccomp dev headers. Those apt packages were never actually invoked
# by the `go build` below — Go handles cross-compilation internally via
# GOARCH/GOOS and does not call out to gcc-<triple> when CGO_ENABLED=1
# links statically via `-extldflags -static` (the Go toolchain ships its
# own linker wrappers). Removing them shrinks the builder image, drops a
# whole ~1 GB of apt download, and eliminates the "some armhf index files
# failed to download" failure mode on recent Ubuntu noble mirrors where
# armhf is only partially published. Builds remain fully reproducible
# under `docker buildx --platform linux/amd64`, `linux/arm64`, or
# `linux/arm/v7`.

# Install Go with SHA256 verification. The tarball on go.dev 302-redirects
# to dl.google.com/go/, and dl.google.com (but NOT go.dev) serves the
# matching .sha256 file as plain text. Fetching both from dl.google.com
# keeps the download and its checksum behind the same certificate pin and
# avoids the HTML-404 trap on go.dev's .sha256 URL.
#
# The uname -m -> Go arch suffix substitution is factored out once so the
# same transform runs for both tarball and checksum.
RUN set -eux; \
    GO_ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64$/arm64/' -e 's/armv7l$/armv6l/'); \
    GO_TARBALL="go${GO_VER}.linux-${GO_ARCH}.tar.gz"; \
    curl -fsSLO "https://dl.google.com/go/${GO_TARBALL}"; \
    GO_SHA256=$(curl -fsSL "https://dl.google.com/go/${GO_TARBALL}.sha256"); \
    echo "${GO_SHA256}  ${GO_TARBALL}" | sha256sum -c -; \
    tar -C /usr/local -xzf "${GO_TARBALL}"; \
    rm -f "${GO_TARBALL}"

ENV PATH=/usr/local/go/bin:${PATH}

# Set the working directory
WORKDIR /app

# Copy go modules files
COPY ./go.mod .
COPY ./go.sum .

# Copy the source code
COPY ./internal/ internal/
COPY ./models/ models/
COPY ./images/ images/
COPY ./cmd/ cmd/
COPY ./fonts fonts
COPY ./persons persons

RUN go mod download

# Ubuntu amd64 needs libquadmath0 for -lquadmath in CGO_LDFLAGS; armhf/armel
# don't ship it and don't need it (the arm CGO_LDFLAGS below omit -lquadmath).
# hadolint ignore=DL3008
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
        apt-get update && \
        apt-get install -y --no-install-recommends libquadmath0 && \
        rm -rf /var/lib/apt/lists/*; \
    fi

RUN <<EOT
    set -eu
    if [ "${TARGETARCH}" = "amd64" ]; then
      export CGO_LDFLAGS="-lcblas -llapack_atlas -lgfortran -lquadmath -lblas -latlas"
    else
      export CGO_LDFLAGS="-lcblas -llapack_atlas -lgfortran -lblas -latlas"
    fi
    CGO_ENABLED=1 go build -trimpath -ldflags "-s -w -extldflags -static" -tags "static netgo cgo static_build" -o cmd/main cmd/main.go
EOT

# Keep the container running as a dev/testdata sandbox. Override via
# `--entrypoint /app/main` to exercise the classification pipeline.
CMD ["tail", "-f", "/dev/null"]
