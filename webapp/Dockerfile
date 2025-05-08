# LeakLens WebApp Dockerfile
# Multi-stage build for optimized production image

# Build stage
FROM node:20.10-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./

# Install dependencies with legacy-peer-deps to resolve dependency conflicts
ENV CI=false
RUN npm install --no-fund --no-audit --legacy-peer-deps

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Runtime stage
FROM node:20.10-alpine

# Set working directory
WORKDIR /app

# Copy built app from builder
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/package-lock.json ./package-lock.json

# Install only production dependencies
RUN npm install --only=production --legacy-peer-deps

# Expose the port
EXPOSE 3001

# Start the application
CMD ["npm", "start"] 