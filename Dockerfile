# Multi-stage build for Swiftralino headless server

# Build stage
FROM swift:6.1.2-focal AS builder

WORKDIR /build

# Copy package files first for dependency caching
COPY Package.docker.swift Package.resolved ./

# Use Docker-specific Package.swift (headless only, no tests)
RUN cp Package.docker.swift Package.swift

# Copy source files
COPY Sources ./Sources

# Install system dependencies for Vapor/NIO and zlib
RUN apt-get update && apt-get install -y \
    libssl-dev \
    zlib1g-dev \
    zlib1g \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Build the headless server in release mode
RUN swift build \
    --configuration release \
    --product swiftralino-headless \
    --static-swift-stdlib

# Production stage
FROM ubuntu:24.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create a non-root user
RUN groupadd -r swiftralino && useradd -r -g swiftralino swiftralino

WORKDIR /app

# Copy the built binary from build stage
COPY --from=builder /build/.build/release/swiftralino-headless /app/swiftralino-headless

# Copy the web assets (frontend)
COPY Public ./Public

# Set proper permissions
RUN chmod +x /app/swiftralino-headless && \
    chown -R swiftralino:swiftralino /app

# Switch to non-root user
USER swiftralino

# Expose the default port
EXPOSE 8080

# Environment variables with defaults
ENV SWIFTRALINO_HOST=0.0.0.0
ENV SWIFTRALINO_PORT=8080
ENV SWIFTRALINO_TLS=false

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${SWIFTRALINO_PORT}/health || exit 1

# Run the headless server
ENTRYPOINT ["/app/swiftralino-headless"] 