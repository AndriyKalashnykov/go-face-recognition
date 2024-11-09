# https://hub.docker.com/_/ubuntu/tags
FROM ubuntu:24.10 AS builder

ARG GO_VER="1.23.1"
ARG DEBIAN_FRONTEND=noninteractive

RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get update
RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get install -y cmake build-essential bash curl locales

RUN dpkg --add-architecture arm64
RUN dpkg --add-architecture armel
RUN dpkg --add-architecture armhf

RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get install -y --no-install-recommends \
    crossbuild-essential-arm64 \
    crossbuild-essential-armel \
    crossbuild-essential-armhf

RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get install -y --no-install-recommends \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu

## Install go-face dependencies
RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND}  apt-get install -y --install-recommends \
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
    libgfortran5 libquadmath0-amd64-cross libquadrule-dev \
    libdlib-dev

# https://hub.docker.com/_/golang/
# Install Go
RUN curl -sLO https://go.dev/dl/go$GO_VER.linux-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/').tar.gz \
    && tar -C /usr/local -xzf go$GO_VER.linux-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/').tar.gz \
    && rm -rf go$GO_VER.linux-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/').tar.gz

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
