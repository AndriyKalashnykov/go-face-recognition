FROM anriykalashnykov/go-face:latest AS builder

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
#RUN go mod tidy
#WORKDIR /app

RUN CGO_ENABLED=1 CGO_LDFLAGS="-static" /usr/local/go/bin/go build --ldflags "-w -s" -tags static -o cmd/main cmd/main.go

# https://hub.docker.com/_/alpine/tags
FROM alpine:3.20.3 AS runtime
COPY --from=builder /app/cmd/main /
# Keep the container running
CMD ["tail", "-f", "/dev/null"]
