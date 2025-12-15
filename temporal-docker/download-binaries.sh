#!/bin/bash
set -e

# Script to download Temporal binaries for air-gapped deployment
# After downloading, you can upload these to your Nexus repository

TEMPORAL_VERSION="${TEMPORAL_VERSION:-1.24.2}"
CLI_VERSION="${CLI_VERSION:-0.13.2}"
PLATFORM="${PLATFORM:-linux}"
ARCH="${ARCH:-amd64}"

BINARIES_DIR="./binaries"
mkdir -p "$BINARIES_DIR"

echo "================================================"
echo "Temporal Binaries Download Script"
echo "================================================"
echo "Version: $TEMPORAL_VERSION"
echo "Platform: $PLATFORM"
echo "Architecture: $ARCH"
echo "================================================"

# Download Temporal Server
echo ""
echo "1. Downloading Temporal Server..."
TEMPORAL_SERVER_URL="https://github.com/temporalio/temporal/releases/download/v${TEMPORAL_VERSION}/temporal_${TEMPORAL_VERSION}_${PLATFORM}_${ARCH}.tar.gz"
echo "   URL: $TEMPORAL_SERVER_URL"

curl -L "$TEMPORAL_SERVER_URL" -o /tmp/temporal-server.tar.gz

echo "   Extracting..."
tar -xzf /tmp/temporal-server.tar.gz -C /tmp
mv /tmp/temporal-server "$BINARIES_DIR/temporal-server"
chmod +x "$BINARIES_DIR/temporal-server"
rm /tmp/temporal-server.tar.gz

echo "   ✓ Temporal Server downloaded"

# Download Temporal CLI
echo ""
echo "2. Downloading Temporal CLI..."
TEMPORAL_CLI_URL="https://github.com/temporalio/cli/releases/download/v${CLI_VERSION}/temporal_cli_${CLI_VERSION}_${PLATFORM}_${ARCH}.tar.gz"
echo "   URL: $TEMPORAL_CLI_URL"

curl -L "$TEMPORAL_CLI_URL" -o /tmp/temporal-cli.tar.gz

echo "   Extracting..."
tar -xzf /tmp/temporal-cli.tar.gz -C /tmp
mv /tmp/temporal "$BINARIES_DIR/temporal"
chmod +x "$BINARIES_DIR/temporal"
rm /tmp/temporal-cli.tar.gz

echo "   ✓ Temporal CLI downloaded"

# Verify binaries
echo ""
echo "3. Verifying binaries..."
if [ -f "$BINARIES_DIR/temporal-server" ]; then
    echo "   ✓ temporal-server: $(stat -f%z "$BINARIES_DIR/temporal-server" 2>/dev/null || stat -c%s "$BINARIES_DIR/temporal-server") bytes"
fi

if [ -f "$BINARIES_DIR/temporal" ]; then
    echo "   ✓ temporal: $(stat -f%z "$BINARIES_DIR/temporal" 2>/dev/null || stat -c%s "$BINARIES_DIR/temporal") bytes"
fi

# Create checksums
echo ""
echo "4. Creating checksums..."
cd "$BINARIES_DIR"
if command -v sha256sum > /dev/null; then
    sha256sum * > checksums.txt
    echo "   ✓ Checksums created (SHA256)"
elif command -v shasum > /dev/null; then
    shasum -a 256 * > checksums.txt
    echo "   ✓ Checksums created (SHA256)"
fi
cd ..

# Create archive for Nexus upload
echo ""
echo "5. Creating archive for Nexus upload..."
tar -czf temporal-binaries-${TEMPORAL_VERSION}.tar.gz -C binaries .
echo "   ✓ Archive created: temporal-binaries-${TEMPORAL_VERSION}.tar.gz"

echo ""
echo "================================================"
echo "Download Complete!"
echo "================================================"
echo ""
echo "Downloaded files in: $BINARIES_DIR/"
ls -lh "$BINARIES_DIR/"
echo ""
echo "Archive for Nexus: temporal-binaries-${TEMPORAL_VERSION}.tar.gz"
echo ""
echo "Next Steps:"
echo "1. Upload binaries to your Nexus repository"
echo "2. Update docker-compose.yml with Nexus URL (if using Dockerfile.airgap)"
echo "3. Or use the local binaries with: docker-compose build"
echo ""
