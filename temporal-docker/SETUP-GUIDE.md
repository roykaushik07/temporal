# Corporate Environment Setup Guide

This guide walks you through setting up Temporal in a restricted corporate environment with no external Docker registry access.

## 🎯 Overview

You will:
1. Download Temporal binaries on a machine with internet
2. Upload binaries to your corporate Nexus
3. Build Docker image using local binaries
4. Run Temporal standalone (no PostgreSQL needed)

## 📋 Prerequisites

- Machine with internet access (for step 1)
- Access to corporate Nexus repository
- Docker installed on target machine
- No external registry access required!

## 🚀 Step-by-Step Setup

### Step 1: Download Binaries (Internet-connected machine)

On any machine with internet access:

```bash
cd temporal-docker

# Download binaries
./download-binaries.sh

# This creates:
# - binaries/temporal-server (70-80 MB)
# - binaries/temporal (60-70 MB)
# - temporal-binaries-1.24.2.tar.gz (archive for Nexus)
```

**What happens:**
- Downloads temporal-server v1.24.2 from GitHub
- Downloads temporal CLI v0.13.2 from GitHub
- Creates checksums
- Packages everything into a tar.gz

### Step 2: Upload to Nexus

#### Option A: Upload Archive (Recommended)

```bash
# Set your Nexus details
export NEXUS_URL=http://nexus.company.com
export NEXUS_REPO=temporal
export NEXUS_USER=your-username

# Upload
./nexus-upload.sh
```

#### Option B: Manual Upload via Nexus UI

1. Login to Nexus: http://nexus.company.com
2. Navigate to Repository: `temporal` (create if needed)
3. Upload: `temporal-binaries-1.24.2.tar.gz`

#### Option C: Using curl

```bash
curl -v -u username:password \
  --upload-file temporal-binaries-1.24.2.tar.gz \
  http://nexus.company.com/repository/temporal/temporal-binaries-1.24.2.tar.gz
```

### Step 3: Transfer Binaries to Target Machine

#### Option A: Use Nexus (if target has Nexus access)

On target machine:

```bash
cd temporal-docker

# Download from Nexus
curl -o temporal-binaries.tar.gz \
  http://nexus.company.com/repository/temporal/temporal-binaries-1.24.2.tar.gz

# Extract to binaries directory
tar -xzf temporal-binaries.tar.gz -C binaries/

# Verify
ls -lh binaries/
```

#### Option B: Direct File Transfer

Copy the `binaries/` directory directly:

```bash
# On internet machine, create archive
tar -czf binaries.tar.gz binaries/

# Transfer via USB, SCP, or other approved method
scp binaries.tar.gz target-machine:~/temporal-docker/

# On target machine
cd temporal-docker
tar -xzf binaries.tar.gz
```

### Step 4: Build Docker Image

On target machine with Docker:

```bash
cd temporal-docker

# Verify binaries are in place
ls -la binaries/
# Should show:
# - temporal-server
# - temporal

# Build image
docker-compose build

# Verify build
docker images | grep temporal
```

### Step 5: Run Temporal

#### Quick Start (Standalone - No PostgreSQL)

```bash
# Start Temporal with SQLite
docker-compose --profile standalone up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f temporal

# Wait 1-2 minutes for startup
```

#### Verify It's Running

```bash
# Test connectivity
curl http://localhost:8233/

# Or check with temporal CLI (from inside container)
docker-compose exec temporal temporal operator cluster health
```

### Step 6: Test with a Workflow (Optional)

If you have Temporal SDK installed:

**Python Example:**
```python
from temporalio.client import Client

async def main():
    client = await Client.connect("localhost:7233")
    # Your workflow code here

asyncio.run(main())
```

**Go Example:**
```go
package main

import (
    "go.temporal.io/sdk/client"
)

func main() {
    c, err := client.Dial(client.Options{
        HostPort: "localhost:7233",
    })
    // Your workflow code here
}
```

## 🔧 Configuration Options

### Standalone Mode (Default - No PostgreSQL)

```bash
docker-compose --profile standalone up -d
```

**Features:**
- ✅ SQLite database (in Docker volume)
- ✅ No external dependencies
- ✅ Perfect for testing
- ❌ Not for production

### With PostgreSQL (More realistic)

```bash
docker-compose --profile with-postgres up -d
```

**Features:**
- ✅ PostgreSQL database
- ✅ Better for development
- ✅ Closer to production setup
- ⚠️ Requires postgres:14-alpine image

### With Web UI (Optional)

```bash
# Standalone + UI
docker-compose --profile standalone --profile with-ui up -d

# Access UI at http://localhost:8080
```

**Note:** Requires `temporalio/ui:2.22.3` image. If not available:
- Download image on internet machine
- Save: `docker save temporalio/ui:2.22.3 > temporal-ui.tar`
- Transfer to target
- Load: `docker load < temporal-ui.tar`

## 🔍 Troubleshooting

### Binaries Not Found During Build

```bash
# Error: COPY binaries/temporal-server: no such file or directory

# Fix: Verify binaries exist
ls -la binaries/

# If missing, re-run download or extract from Nexus
```

### Permission Denied

```bash
# Fix: Make binaries executable
chmod +x binaries/*

# Rebuild
docker-compose build --no-cache
```

### Container Won't Start

```bash
# Check logs
docker-compose logs temporal

# Common issues:
# 1. Binary architecture mismatch (e.g., ARM vs AMD64)
# 2. Missing configuration files
# 3. Port 7233 already in use

# Verify binary
docker-compose run --rm temporal /usr/local/bin/temporal-server --version
```

### Port Already in Use

```bash
# Check what's using port 7233
lsof -i :7233

# Option 1: Stop the conflicting service
# Option 2: Change port in docker-compose.yml
ports:
  - "17233:7233"  # Use different external port
```

## 📊 Resource Requirements

### Minimum (Standalone)
- CPU: 1 core
- Memory: 2 GB
- Disk: 5 GB

### Recommended
- CPU: 2 cores
- Memory: 4 GB
- Disk: 10 GB

## 🔒 Security Considerations

### For Production

1. **Don't use SQLite** - Use PostgreSQL or Cassandra
2. **Change passwords** - Update POSTGRES_PASSWORD
3. **Enable TLS** - Configure certificates
4. **Restrict ports** - Don't expose all ports
5. **Use secrets** - Docker secrets or env files

### Configuration Files

Sensitive data should be in `.env` file (not committed):

```bash
# .env
POSTGRES_PASSWORD=your-secure-password
NEXUS_USER=your-username
NEXUS_PASS=your-password
```

## 📦 Binary Versions

| Component | Version | Size |
|-----------|---------|------|
| temporal-server | 1.24.2 | ~70 MB |
| temporal CLI | 0.13.2 | ~60 MB |
| Total | - | ~130 MB |

## 🔄 Updating Temporal

```bash
# 1. Download new version
TEMPORAL_VERSION=1.25.0 ./download-binaries.sh

# 2. Upload to Nexus
./nexus-upload.sh

# 3. Transfer to target machine (if needed)

# 4. Rebuild image
docker-compose build --no-cache

# 5. Restart
docker-compose down
docker-compose --profile standalone up -d
```

## ✅ Success Checklist

- [ ] Binaries downloaded and verified
- [ ] Binaries uploaded to Nexus (or transferred)
- [ ] Docker image built successfully
- [ ] Temporal started (docker-compose ps shows "Up")
- [ ] Health check passing (curl http://localhost:8233/)
- [ ] Can connect from application (localhost:7233)

## 🆘 Getting Help

If you encounter issues:

1. Check logs: `docker-compose logs temporal`
2. Verify binaries: `ls -lh binaries/`
3. Test connectivity: `curl http://localhost:8233/`
4. Check ports: `lsof -i :7233`
5. Rebuild: `docker-compose build --no-cache`

## 📚 Next Steps

1. ✅ Setup complete
2. ✅ Temporal running
3. 📖 Read [Temporal Documentation](https://docs.temporal.io/)
4. 💻 Try [Sample Workflows](https://github.com/temporalio/samples-go)
5. 🚀 Build your workflows!

## 🏢 Production Deployment

For production, use the Helm chart in `../temporal-helm/`:
- High availability
- Scalability
- Monitoring
- Security

This Docker setup is for **development and testing only**.
