# https://hub.docker.com/_/ubuntu/tags
FROM amd64/ubuntu:24.10 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ENV DLIB_VERSION=19.24

RUN apt-get update
RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get update && apt-get install -y build-essential bash curl locales

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

#RUN mkdir /dlib && cd /dlib && curl -sLO http://dlib.net/files/dlib-${DLIB_VERSION}.tar.bz2 && tar xf dlib-${DLIB_VERSION}.tar.bz2
#RUN cd /dlib/dlib-${DLIB_VERSION} && mkdir build && cd build \
#    && cmake .. && cmake -DDLIB_PNG_SUPPORT=ON -DDLIB_GIF_SUPPORT=ON -DDLIB_JPEG_SUPPORT=ON -DDLIB_NO_GUI_SUPPORT=ON .. \
#    && cmake --build . --config Release \
#    && make -j$(grep -c processor /proc/cpuinfo) \
#    && make install \
#    && rm -rf /dlib

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

#ENV PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig/

RUN /usr/local/go/bin/go mod download

RUN GOOS=linux GOARCH=amd64 CC=x86_64-linux-gnu-gcc CXX=x86_64-linux-gnu-g++ CGO_ENABLED=1 CGO_LDFLAGS="-lcblas -llapack_atlas -lblas -latlas -lgfortran -lquadmath" /usr/local/go/bin/go build --ldflags "-s -w -extldflags -static" -tags "static netgo cgo static_build" -o cmd/main cmd/main.go

#ENV PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig
#ENV PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig
#RUN GOOS=linux GOARCH=arm64 CC=aarch64-linux-gnu-gcc CXX=aarch64-linux-gnu-g++ CGO_ENABLED=1 CGO_LDFLAGS="-lcblas -llapack_atlas -lblas -latlas -lgfortran -lquadmath" /usr/local/go/bin/go build --ldflags "-s -w -extldflags -static -extld=aarch64-linux-gnu-gcc" -tags "static netgo cgo static_build" -o cmd/main-arm64 cmd/main.go

# Keep the container running
CMD ["tail", "-f", "/dev/null"]
