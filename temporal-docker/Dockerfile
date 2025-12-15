# Temporal Server - Standalone Build (No External Dependencies)
# This Dockerfile uses locally downloaded binaries
# Run ./download-binaries.sh first to download the binaries

FROM alpine:3.18

# Install runtime dependencies only
RUN apk add --no-cache \
    ca-certificates \
    bash \
    curl \
    sqlite \
    && rm -rf /var/cache/apk/*

# Create temporal user and directories
RUN addgroup -g 1000 temporal && \
    adduser -D -u 1000 -G temporal temporal && \
    mkdir -p /etc/temporal/config/dynamicconfig \
             /var/lib/temporal/db \
             /usr/local/bin && \
    chown -R temporal:temporal /etc/temporal /var/lib/temporal

WORKDIR /app

# Copy pre-downloaded binaries from local binaries/ directory
# You need to place the binaries in the binaries/ directory before building
COPY binaries/temporal-server /usr/local/bin/temporal-server
COPY binaries/temporal /usr/local/bin/temporal

# Make binaries executable
RUN chmod +x /usr/local/bin/temporal-server /usr/local/bin/temporal

# Copy configuration files
COPY --chown=temporal:temporal config/ /etc/temporal/config/

# Switch to temporal user
USER temporal

# Expose ports
# 7233 - Frontend gRPC
# 8233 - Frontend HTTP
EXPOSE 7233 8233

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8233/ || exit 1

# Default command
CMD ["temporal-server", "start"]
