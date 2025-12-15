# Temporal Setup Repository

This repository contains two different ways to deploy Temporal:

## 📁 Directory Structure

```
temporal/
├── temporal-docker/          # Docker setup for corporate/air-gapped environments
│   ├── Dockerfile           # Build from local binaries
│   ├── Dockerfile.airgap    # Build from Nexus repository
│   ├── docker-compose.yml   # Orchestration (standalone & PostgreSQL modes)
│   ├── download-binaries.sh # Download Temporal binaries
│   ├── nexus-upload.sh      # Upload to Nexus
│   ├── SETUP-GUIDE.md       # Complete setup guide
│   └── README.md            # Full documentation
│
└── temporal-helm/           # Helm chart for OpenShift/Kubernetes
    ├── Chart.yaml
    ├── values.yaml
    ├── templates/
    └── README.md            # Production deployment guide
```

## 🐳 Docker Setup (Development & Testing)

**Location:** `temporal-docker/`

**Use for:**
- Local development
- Testing
- Corporate environments without external registry access
- Air-gapped deployments

**Features:**
- ✅ No external Docker registry required
- ✅ Uses locally downloaded binaries
- ✅ Optional PostgreSQL (can use SQLite)
- ✅ Works behind corporate firewall
- ✅ Nexus repository integration

**Quick Start:**
```bash
cd temporal-docker

# Download binaries
./download-binaries.sh

# Build and start
docker-compose build
docker-compose --profile standalone up -d

# Access at localhost:7233
```

**Documentation:** See [`temporal-docker/SETUP-GUIDE.md`](temporal-docker/SETUP-GUIDE.md)

## ☸️ Helm Chart (Production)

**Location:** `temporal-helm/`

**Use for:**
- Production deployments
- OpenShift/Kubernetes clusters
- High availability setups
- Enterprise requirements

**Features:**
- ✅ High availability
- ✅ Auto-scaling
- ✅ Active Directory integration
- ✅ TLS/SSL encryption
- ✅ Prometheus monitoring
- ✅ PostgreSQL replication

**Quick Start:**
```bash
cd temporal-helm

# Update dependencies
helm dependency update

# Install
helm install temporal . \
  -f values.yaml \
  -n temporal-production
```

**Documentation:** See [`temporal-helm/README.md`](temporal-helm/README.md)

## 🎯 Which One Should I Use?

| Scenario | Use | Why |
|----------|-----|-----|
| Local development | `temporal-docker/` | Lightweight, standalone |
| Testing workflows | `temporal-docker/` | Quick setup, no infrastructure |
| Corporate environment (restricted) | `temporal-docker/` | No external registries needed |
| Production deployment | `temporal-helm/` | HA, scalability, security |
| OpenShift/Kubernetes | `temporal-helm/` | Native K8s deployment |
| Learning Temporal | `temporal-docker/` | Simple, standalone |

## 🚀 Quick Comparison

### Docker Setup
- **Setup Time:** 5-10 minutes
- **Infrastructure:** Just Docker
- **Use Case:** Development, testing
- **High Availability:** No
- **Scalability:** Limited
- **Best For:** Getting started, learning, testing

### Helm Chart
- **Setup Time:** 30-60 minutes
- **Infrastructure:** Kubernetes/OpenShift cluster
- **Use Case:** Production
- **High Availability:** Yes
- **Scalability:** Auto-scaling
- **Best For:** Production workloads

## 📚 Documentation

- **Docker Setup:** [`temporal-docker/SETUP-GUIDE.md`](temporal-docker/SETUP-GUIDE.md)
- **Helm Chart:** [`temporal-helm/README.md`](temporal-helm/README.md)
- **Official Temporal Docs:** https://docs.temporal.io/

## 🔧 Common Workflows

### 1. Start Development Environment

```bash
cd temporal-docker
./download-binaries.sh
docker-compose build
docker-compose --profile standalone up -d
```

### 2. Deploy to Production (OpenShift)

```bash
cd temporal-helm
helm dependency update
helm install temporal . -f values.yaml -n temporal-production
```

### 3. Upload Binaries to Nexus

```bash
cd temporal-docker
./download-binaries.sh
./nexus-upload.sh
```

## 🆘 Support

For issues or questions:
- Check the respective README files
- Visit [Temporal Documentation](https://docs.temporal.io/)
- Join [Temporal Community](https://community.temporal.io/)

## 📋 Version Information

- **Temporal Server:** 1.24.2
- **Temporal CLI:** 0.13.2
- **Helm Chart:** See temporal-helm/Chart.yaml

## 🔐 Security Notice

The Docker setup is designed for **development and testing only**. For production:
- Use the Helm chart with proper security configurations
- Enable TLS/SSL
- Configure authentication and authorization
- Use external, managed databases
- Implement monitoring and alerting

---

**Note:** Both setups are independent. You can use one or both depending on your needs.
