

FROM ghcr.io/andriykalashnykov/dlib-docker:v19.24.0 AS builder

#ENV DEBIAN_FRONTEND=noninteractive
#RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get update && apt-get install -y --install-recommends gfortran

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
COPY ./fonts fonts/
COPY ./persons persons/

#WORKDIR /app/cmd
#RUN /usr/local/go/bin/go mod tidy

# Install Go
RUN curl -sLO https://go.dev/dl/go1.23.2.linux-amd64.tar.gz && tar -C /usr/local -xzf go1.23.2.linux-amd64.tar.gz && rm -rf go1.23.2.linux-amd64.tar.gz

ENV PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig/

RUN /usr/local/go/bin/go mod download
RUN GOOS=linux GOARCH=amd64 CGO_ENABLED=1 CGO_LDFLAGS="-lcblas -llapack_atlas -lgfortran -lquadmath -lblas -latlas" /usr/local/go/bin/go build -ldflags "-s -w -extldflags -static" -tags static -o cmd/main cmd/main.go

FROM alpine:3.20.3
WORKDIR /app
COPY --from=builder /app/cmd/main .
# Keep the container running
CMD ["tail", "-f", "/dev/null"]
