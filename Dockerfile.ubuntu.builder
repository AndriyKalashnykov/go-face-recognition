# https://hub.docker.com/_/ubuntu/tags
FROM amd64/ubuntu:24.10 AS builder

RUN apt-get update
RUN apt-get install -y build-essential cmake curl

## Install go-face dependencies
RUN apt-get install -y --install-recommends \
    libdlib-dev \
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
    libgfortran5 libquadmath0-amd64-cross libquadrule-dev

# https://hub.docker.com/_/golang/
# Install Go
RUN curl -sLO https://go.dev/dl/go1.23.2.linux-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/').tar.gz \
    && tar -C /usr/local -xzf go1.23.2.linux-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/').tar.gz \
    && rm -rf go1.23.2.linux-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/').tar.gz

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

ENV PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig/

RUN /usr/local/go/bin/go mod download
RUN CGO_ENABLED=1 CGO_LDFLAGS="-lcblas -llapack_atlas -lblas -latlas -lgfortran -lquadmath" /usr/local/go/bin/go build -ldflags "-s -w -extldflags -static" -tags static -o cmd/main cmd/main.go

# Keep the container running
CMD ["tail", "-f", "/dev/null"]