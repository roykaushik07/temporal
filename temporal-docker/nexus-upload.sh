#!/bin/bash
set -e

# Script to upload Temporal binaries to Nexus repository

# Configuration - Update these values for your environment
NEXUS_URL="${NEXUS_URL:-http://nexus.company.com}"
NEXUS_REPO="${NEXUS_REPO:-temporal}"
NEXUS_USER="${NEXUS_USER:-admin}"
NEXUS_PASS="${NEXUS_PASS}"
TEMPORAL_VERSION="${TEMPORAL_VERSION:-1.24.2}"

BINARIES_DIR="./binaries"
ARCHIVE_NAME="temporal-binaries-${TEMPORAL_VERSION}.tar.gz"

echo "================================================"
echo "Temporal Binaries Upload to Nexus"
echo "================================================"
echo "Nexus URL: $NEXUS_URL"
echo "Repository: $NEXUS_REPO"
echo "Version: $TEMPORAL_VERSION"
echo "================================================"
echo ""

# Check if archive exists
if [ ! -f "$ARCHIVE_NAME" ]; then
    echo "❌ Error: $ARCHIVE_NAME not found!"
    echo ""
    echo "Run ./download-binaries.sh first to create the archive."
    exit 1
fi

# Check if credentials are provided
if [ -z "$NEXUS_PASS" ]; then
    echo "Enter Nexus password for user '$NEXUS_USER':"
    read -s NEXUS_PASS
    echo ""
fi

# Upload archive
echo "Uploading $ARCHIVE_NAME to Nexus..."
UPLOAD_URL="${NEXUS_URL}/repository/${NEXUS_REPO}/${ARCHIVE_NAME}"

echo "Upload URL: $UPLOAD_URL"
echo ""

curl -v -u "${NEXUS_USER}:${NEXUS_PASS}" \
  --upload-file "$ARCHIVE_NAME" \
  "$UPLOAD_URL"

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================"
    echo "✅ Upload Successful!"
    echo "================================================"
    echo ""
    echo "Archive uploaded to: $UPLOAD_URL"
    echo ""
    echo "Verify the upload:"
    echo "  curl -I $UPLOAD_URL"
    echo ""
    echo "Next steps:"
    echo "1. Update Dockerfile.airgap with your Nexus URL"
    echo "2. Build image: docker build -f Dockerfile.airgap -t temporal:${TEMPORAL_VERSION} ."
    echo ""
else
    echo ""
    echo "❌ Upload failed!"
    echo ""
    echo "Check:"
    echo "1. Nexus URL is correct"
    echo "2. Repository exists and accepts uploads"
    echo "3. Credentials are correct"
    echo "4. Network connectivity to Nexus"
    exit 1
fi
