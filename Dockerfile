FROM dlib-dev:latest AS builder

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

WORKDIR /app

RUN CGO_LDFLAGS="-static" /usr/local/go/bin/go build -tags static .

# Keep the container running
CMD ["tail", "-f", "/dev/null"]
