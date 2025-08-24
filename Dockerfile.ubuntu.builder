ARG BUILDER_IMAGE="ubuntu:oracular-20250619@sha256:cdf755952ed117f6126ff4e65810bf93767d4c38f5c7185b50ec1f1078b464cc"

# https://hub.docker.com/_/ubuntu/tags
FROM ${BUILDER_IMAGE} AS builder

ARG GO_VER=1.25.0
ARG DEBIAN_FRONTEND=noninteractive

RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get update
RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get install -y cmake build-essential bash curl wget locales ca-certificates net-tools

RUN <<EOT
    if [ "${TARGETARCH}" == "amd64" ] || [ "${TARGETARCH}" == "arm64" ]; then

        dpkg --add-architecture arm64
        dpkg --add-architecture armel
        dpkg --add-architecture armhf

        DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get update && apt-get install -y --no-install-recommends \
            crossbuild-essential-arm64 \
            crossbuild-essential-armel \
            crossbuild-essential-armhf

        DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get update && apt-get install -y --no-install-recommends \
            libapparmor-dev:arm64 \
            libapparmor-dev:armel \
            libapparmor-dev:armhf \
            libseccomp-dev:arm64 \
            libseccomp-dev:armel \
            libseccomp-dev:armhf
    fi
EOT

#RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get install -y --no-install-recommends \
#    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu

## Install go-face dependencies
RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get install -y --install-recommends \
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
    libgfortran5  \
    libdlib-dev

# libquadmath0-amd64-cross libquadrule-dev

# https://launchpad.net/ubuntu/oracular/+package/libdlib-dev

# https://hub.docker.com/_/golang/
# Install Go
ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" skipcache
RUN curl -sLO https://go.dev/dl/go$GO_VER.linux-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?\(v7l\)\?.*/\1\2\3/' -e 's/aarch64$/arm64/' -e 's/armv7l$/armv6l/').tar.gz \
    && tar -C /usr/local -xzf go$GO_VER.linux-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?\(v7l\)\?.*/\1\2\3/' -e 's/aarch64$/arm64/' -e 's/armv7l$/armv6l/').tar.gz \
    && rm -rf go$GO_VER.linux-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?\(v7l\)\?.*/\1\2\3/' -e 's/aarch64$/arm64/' -e 's/armv7l$/armv6l/').tar.gz

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

RUN /usr/local/go/bin/go mod download

RUN <<EOT
    if [ "${TARGETARCH}" = "amd64" ]; then
      apt install -y libquadmath0;
      export CGO_LDFLAGS="-lcblas -llapack_atlas -lgfortran -lquadmath -lblas -latlas"
    else
      export CGO_LDFLAGS="-lcblas -llapack_atlas -lgfortran -lblas -latlas"
    fi

    CGO_ENABLED=1 /usr/local/go/bin/go build -trimpath -ldflags "-s -w -extldflags -static" -tags "static netgo cgo static_build" -o cmd/main cmd/main.go
EOT

# Keep the container running
CMD ["tail", "-f", "/dev/null"]
