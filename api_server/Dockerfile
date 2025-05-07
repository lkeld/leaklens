# LeakLens API Server Dockerfile
# Multi-stage build for optimized production image

# Build stage
FROM rust:1.81-slim-bullseye AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    make \
    gcc \
    perl \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /app

# Copy the entire project
COPY . .

# Build dependencies - this is done separately to cache dependencies
RUN cargo build --release

# Build the application
RUN cargo clean && cargo build --release

# Runtime stage
FROM debian:bullseye-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl1.1 \
    && rm -rf /var/lib/apt/lists/*

# Copy the build artifact from the builder stage
WORKDIR /app
COPY --from=builder /app/target/release/api_server .
COPY --from=builder /app/swagger.yaml ./

# Create a non-root user to run the application
RUN useradd -m appuser
USER appuser

# Expose the port
EXPOSE 3000

# Set the startup command
CMD ["./api_server"]