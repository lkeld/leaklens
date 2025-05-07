# LeakLens API Server Dockerfile
# Multi-stage build for optimized production image

# Build stage
FROM rust:1.76-slim-bullseye AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Create a new empty project
WORKDIR /app
RUN USER=root cargo new --bin leaklens-api
WORKDIR /app/leaklens-api

# Copy manifests
COPY Cargo.toml Cargo.lock ./

# Create a dummy source file
RUN mkdir -p src/
RUN echo "fn main() { println!(\"Dummy implementation\"); }" > src/main.rs

# Build dependencies - this is done separately to cache dependencies
RUN cargo build --release

# Copy source code
COPY src/ ./src/
COPY proto/ ./proto/
COPY build.rs ./
COPY swagger.yaml /app/

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
COPY --from=builder /app/leaklens-api/target/release/leaklens-api .
COPY --from=builder /app/swagger.yaml ./

# Create a non-root user to run the application
RUN useradd -m appuser
USER appuser

# Expose the port
EXPOSE 3000

# Set the startup command
CMD ["./leaklens-api"]