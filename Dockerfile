# https://hub.docker.com/_/ubuntu/tags
FROM ubuntu:24.10 AS builder

RUN apt-get update
RUN apt-get install -y build-essential cmake curl

## Install go-face dependencies
RUN apt-get install -y \
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
    gfortran

RUN curl -sLO https://go.dev/dl/go1.23.2.linux-amd64.tar.gz && tar -C /usr/local -xzf go1.23.2.linux-amd64.tar.gz && rm -rf go1.23.2.linux-amd64.tar.gz

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

#WORKDIR /app/cmd
#RUN /usr/local/go/bin/go mod tidy

RUN CGO_ENABLED=1 CGO_LDFLAGS="-static -lgfortran" /usr/local/go/bin/go build -tags static -o cmd/main cmd/main.go

FROM alpine
WORKDIR /app
COPY --from=builder /app/cmd/main .
# Keep the container running
CMD ["tail", "-f", "/dev/null"]
