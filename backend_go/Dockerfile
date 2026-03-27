# ── Stage 1: Build the Go binary ──────────────────────────────────────────────
# Go compiles to a single static binary — no runtime needed in the final image.
# This is a huge advantage over Node: the final image can be a scratch (empty) container
# or a minimal alpine image, typically 10-50MB vs 300+MB for Node.
FROM golang:1.22-alpine AS builder

# Install git (required by `go mod download` for some modules)
RUN apk add --no-cache git

WORKDIR /build

# Copy go.mod and go.sum first — Docker caches this layer.
# If your code changes but go.mod doesn't, `go mod download` uses the cache.
# This is the Go equivalent of `COPY package.json && npm install` before COPY .
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source
COPY . .

# Build the binary.
# CGO_ENABLED=0: disable C bindings — produces a fully static binary (no .so dependencies).
# GOOS/GOARCH: cross-compile for Linux/amd64 (the Docker container's OS).
# -ldflags="-w -s": strip debug symbols → smaller binary (typically 30-50% smaller).
# -o /build/server: output path for the binary.
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o /build/server ./cmd/server

# ── Stage 2: Minimal runtime image ────────────────────────────────────────────
# alpine is ~5MB; scratch (completely empty) is 0MB but has no shell for debugging.
# alpine is a good production choice — you keep basic tools like sh and ls.
FROM alpine:latest

# ca-certificates: needed for HTTPS outbound requests (if any)
# tzdata: timezone data (for time.Local to work correctly)
RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

# Copy ONLY the compiled binary from the builder stage.
# No Go toolchain, no source code, no node_modules — just the binary.
COPY --from=builder /build/server .

EXPOSE 1234

# The binary is the entrypoint. No `node`, no `npm` — just run the compiled binary.
ENTRYPOINT ["./server"]
