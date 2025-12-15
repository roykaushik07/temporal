# Temporal Docker - Air-Gapped / Corporate Environment Setup

This setup is designed for corporate environments with restricted internet access where you need to:
- Download binaries externally and upload to internal Nexus
- Build Docker images without accessing public Docker registries
- Run Temporal standalone without external dependencies

## 🏢 Corporate Environment Features

✅ No external Docker registry access required
✅ Binaries downloaded from your internal Nexus
✅ PostgreSQL is **optional** (can use SQLite)
✅ Standalone mode for quick testing
✅ Air-gapped deployment ready

## 📋 Prerequisites

- Docker installed locally
- Access to download binaries (one-time, from a machine with internet)
- Access to your corporate Nexus repository
- (Optional) PostgreSQL if you want persistence

## 🚀 Quick Start Options

### Option 1: Standalone (No PostgreSQL, Simplest)

```bash
# 1. Download binaries
./download-binaries.sh

# 2. Build image
docker-compose build

# 3. Start Temporal (standalone mode with SQLite)
docker-compose --profile standalone up -d

# Access at: http://localhost:7233
```

### Option 2: With PostgreSQL (Production-like)

```bash
# 1. Download binaries
./download-binaries.sh

# 2. Build image
docker-compose build

# 3. Start with PostgreSQL
docker-compose --profile with-postgres up -d
```

## 📦 Step-by-Step Setup

### Step 1: Download Binaries (One-time)

On a machine with internet access:

```bash
cd temporal-docker

# Download latest binaries
./download-binaries.sh

# Or specify version
TEMPORAL_VERSION=1.24.2 ./download-binaries.sh
```

This creates:
- `binaries/temporal-server` - Main server binary
- `binaries/temporal` - CLI tool
- `temporal-binaries-1.24.2.tar.gz` - Archive for Nexus

### Step 2: Upload to Nexus (Corporate Environment)

Upload the archive or individual binaries to your Nexus repository:

```bash
# Example using curl
curl -v -u username:password \
  --upload-file temporal-binaries-1.24.2.tar.gz \
  http://nexus.company.com/repository/temporal/

# Or use Nexus UI to upload
```

### Step 3: Build Docker Image

#### Option A: Using Local Binaries (Recommended)

```bash
# Binaries are already in binaries/ directory
docker-compose build
```

#### Option B: Download from Nexus

Update `Dockerfile.airgap` with your Nexus URL:

```dockerfile
ARG NEXUS_URL=http://nexus.company.com/repository/temporal
```

Then build:

```bash
docker build -f Dockerfile.airgap \
  --build-arg NEXUS_URL=http://nexus.company.com/repository/temporal \
  --build-arg TEMPORAL_VERSION=1.24.2 \
  -t temporal-server:1.24.2 .
```

### Step 4: Choose Your Deployment Mode

#### Standalone Mode (SQLite, No PostgreSQL)

Best for: Quick testing, development, learning

```bash
# Start
docker-compose --profile standalone up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f temporal
```

#### With PostgreSQL

Best for: More realistic testing, persistence

```bash
# Start
docker-compose --profile with-postgres up -d

# Check status
docker-compose ps
```

## 🔧 Configuration

### Directory Structure

```
temporal-docker/
├── binaries/                          # Downloaded binaries (git-ignored)
│   ├── temporal-server               # Main server binary
│   ├── temporal                      # CLI binary
│   └── checksums.txt                 # SHA256 checksums
├── config/
│   ├── development.yaml              # PostgreSQL config
│   ├── development-sqlite.yaml       # SQLite config
│   └── dynamicconfig/
│       └── development.yaml          # Runtime settings
├── scripts/
│   └── init-db.sh                    # PostgreSQL init
├── Dockerfile                         # Main Dockerfile (local binaries)
├── Dockerfile.airgap                  # Alternative (Nexus download)
├── docker-compose.yml                 # Orchestration
├── download-binaries.sh               # Binary download script
└── README.md                          # This file
```

### Profiles

The `docker-compose.yml` uses profiles to control what starts:

- `standalone` - Temporal with SQLite (no PostgreSQL)
- `with-postgres` - Temporal with PostgreSQL
- `with-ui` - Include Web UI (optional)

Examples:

```bash
# Just Temporal standalone
docker-compose --profile standalone up -d

# Temporal + PostgreSQL
docker-compose --profile with-postgres up -d

# Temporal standalone + Web UI
docker-compose --profile standalone --profile with-ui up -d
```

## 🌐 Nexus Integration

### Upload Binaries to Nexus

1. **Create Repository** (if not exists):
   - Type: Raw (hosted)
   - Name: temporal
   - Deployment policy: Allow redeploy

2. **Upload Archive**:
   ```bash
   curl -v -u admin:password \
     --upload-file temporal-binaries-1.24.2.tar.gz \
     http://nexus.company.com/repository/temporal/temporal-binaries-1.24.2.tar.gz
   ```

3. **Verify Upload**:
   ```bash
   curl http://nexus.company.com/repository/temporal/temporal-binaries-1.24.2.tar.gz -I
   ```

### Build from Nexus

```bash
docker build -f Dockerfile.airgap \
  --build-arg NEXUS_URL=http://nexus.company.com/repository/temporal \
  --build-arg TEMPORAL_VERSION=1.24.2 \
  --build-arg DOWNLOAD_BINARIES=true \
  -t temporal-server:1.24.2 .
```

## 📊 Accessing Temporal

### Without Web UI

```bash
# Connect using CLI
docker-compose exec temporal temporal operator cluster health

# Or use temporal CLI from host (if installed)
temporal operator cluster health --address localhost:7233
```

### With Web UI

```bash
# Start with UI profile
docker-compose --profile standalone --profile with-ui up -d

# Access at: http://localhost:8080
```

### Using Temporal in Your Apps

Connect to `localhost:7233`:

**Go:**
```go
client, err := client.Dial(client.Options{
    HostPort: "localhost:7233",
})
```

**Python:**
```python
client = await Client.connect("localhost:7233")
```

**Java:**
```java
WorkflowServiceStubs service = WorkflowServiceStubs.newInstance(
    WorkflowServiceStubsOptions.newBuilder()
        .setTarget("localhost:7233")
        .build()
);
```

## 🛠️ Common Commands

```bash
# Start standalone
docker-compose --profile standalone up -d

# Start with PostgreSQL
docker-compose --profile with-postgres up -d

# View logs
docker-compose logs -f

# Check status
docker-compose ps

# Stop everything
docker-compose down

# Clean up (removes data)
docker-compose down -v

# Rebuild image
docker-compose build --no-cache

# Execute CLI commands
docker-compose exec temporal temporal operator cluster health
docker-compose exec temporal temporal operator namespace list
```

## 🔍 Troubleshooting

### Binaries Not Found

```bash
# Check binaries directory
ls -la binaries/

# If missing, download them
./download-binaries.sh

# Verify they're executable
chmod +x binaries/*
```

### Container Won't Start

```bash
# Check logs
docker-compose logs temporal

# Verify binary is in container
docker-compose run --rm temporal ls -la /usr/local/bin/

# Test binary
docker-compose run --rm temporal temporal-server --version
```

### Port Already in Use

```bash
# Check what's using port 7233
lsof -i :7233

# Or change port in docker-compose.yml
ports:
  - "17233:7233"  # Use port 17233 instead
```

### Database Issues (PostgreSQL mode)

```bash
# Check PostgreSQL logs
docker-compose logs postgresql

# Test connection
docker-compose exec postgresql psql -U temporal -c "SELECT version();"

# Reset database
docker-compose down -v
docker-compose --profile with-postgres up -d
```

## 🔒 Security Notes

### For Production Use

1. **Change default passwords**:
   ```yaml
   POSTGRES_PASSWORD: your-secure-password
   ```

2. **Use proper base image**:
   ```dockerfile
   FROM your-corporate-registry/alpine:3.18
   ```

3. **Don't expose ports**:
   ```yaml
   # Remove or comment out port mappings
   # ports:
   #   - "7233:7233"
   ```

4. **Add TLS**:
   - Configure TLS certificates
   - Update config/development.yaml

5. **Use secrets management**:
   - Docker secrets
   - Kubernetes secrets
   - HashiCorp Vault

## 📈 Resource Requirements

### Standalone Mode (SQLite)
- CPU: 1-2 cores
- Memory: 2-4 GB
- Disk: 10 GB

### With PostgreSQL
- CPU: 2-4 cores
- Memory: 4-8 GB
- Disk: 20 GB

## 🔄 Upgrading

```bash
# 1. Download new version
TEMPORAL_VERSION=1.25.0 ./download-binaries.sh

# 2. Upload to Nexus (if using)

# 3. Rebuild image
docker-compose build --no-cache

# 4. Stop old version
docker-compose down

# 5. Start new version
docker-compose --profile standalone up -d
```

## 📚 Additional Resources

- [Temporal Documentation](https://docs.temporal.io/)
- [Temporal GitHub](https://github.com/temporalio/temporal)
- [Binary Releases](https://github.com/temporalio/temporal/releases)
- [CLI Releases](https://github.com/temporalio/cli/releases)

## ⚡ Quick Reference

| Command | Description |
|---------|-------------|
| `./download-binaries.sh` | Download Temporal binaries |
| `docker-compose build` | Build Docker image |
| `docker-compose --profile standalone up -d` | Start standalone |
| `docker-compose --profile with-postgres up -d` | Start with PostgreSQL |
| `docker-compose logs -f` | View logs |
| `docker-compose down` | Stop services |
| `docker-compose down -v` | Stop and remove data |

## 🎯 Next Steps

1. ✅ Download binaries: `./download-binaries.sh`
2. ✅ Upload to Nexus (optional)
3. ✅ Build image: `docker-compose build`
4. ✅ Start Temporal: `docker-compose --profile standalone up -d`
5. ✅ Test connection: `curl http://localhost:8233/`
6. ✅ Run your workflows!

For production deployment with high availability, use the Helm chart in `../temporal-helm/`
