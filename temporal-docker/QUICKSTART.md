# Temporal Docker - Quick Start Guide

Get Temporal up and running in 5 minutes!

## Prerequisites

- Docker (20.10+)
- Docker Compose (1.29+)
- Make (optional, for convenience)

## Installation Steps

### Option 1: Using Make (Recommended)

```bash
# Start everything with one command
make start
```

This will:
1. Build the Docker image
2. Start all services (Temporal, PostgreSQL, UI)
3. Create the default namespace
4. Show you the status

### Option 2: Using Docker Compose

```bash
# Build the image
docker-compose build

# Start services
docker-compose up -d

# Wait for services to be healthy (check with docker-compose ps)
# Then create a namespace
docker-compose exec temporal-admin-tools temporal operator namespace create default
```

## Verify Installation

1. **Check services are running:**
   ```bash
   make status
   # or
   docker-compose ps
   ```

   All services should show "Up (healthy)"

2. **Open the Web UI:**

   Visit http://localhost:8080 in your browser

3. **Check cluster health:**
   ```bash
   make health
   # or
   docker-compose exec temporal-admin-tools temporal operator cluster health
   ```

## Next Steps

### 1. Explore the Web UI

Open http://localhost:8080 and explore:
- Namespaces
- Workflows (none yet!)
- Task Queues

### 2. Run a Sample Workflow

#### Using Go

```bash
# Clone temporal-go-samples
git clone https://github.com/temporalio/samples-go.git
cd samples-go

# Run the hello world example
go run hello/starter/main.go
```

#### Using Python

```bash
# Install Temporal SDK
pip install temporalio

# Clone temporal-python-samples
git clone https://github.com/temporalio/samples-python.git
cd samples-python

# Run hello world
python hello/hello_workflow.py
```

#### Using TypeScript

```bash
# Clone temporal-typescript-samples
git clone https://github.com/temporalio/samples-typescript.git
cd samples-typescript

# Install and run
npm install
npm run start.watch
```

### 3. View Your Workflow in the UI

After running a workflow, refresh the Web UI at http://localhost:8080 to see:
- Workflow execution
- Event history
- Task queue activity

## Common Commands

```bash
# View logs
make logs

# Open CLI shell
make shell

# List namespaces
make list-namespaces

# Restart services
make restart

# Stop services
make down

# Clean up everything (removes data!)
make clean
```

## Connection Details

When developing your applications, use these connection details:

- **Temporal Frontend (gRPC)**: `localhost:7233`
- **Web UI**: `http://localhost:8080`
- **PostgreSQL**: `localhost:5432` (user: temporal, password: temporal)

### Example Connection Code

**Go:**
```go
import "go.temporal.io/sdk/client"

c, err := client.Dial(client.Options{
    HostPort: "localhost:7233",
})
```

**Python:**
```python
from temporalio.client import Client

client = await Client.connect("localhost:7233")
```

**TypeScript:**
```typescript
import { Connection } from '@temporalio/client';

const connection = await Connection.connect({
    address: 'localhost:7233',
});
```

**Java:**
```java
import io.temporal.serviceclient.WorkflowServiceStubs;

WorkflowServiceStubs service = WorkflowServiceStubs.newInstance(
    WorkflowServiceStubsOptions.newBuilder()
        .setTarget("localhost:7233")
        .build()
);
```

## Troubleshooting

### Services won't start

```bash
# Check logs
make logs-temporal

# Check database
make test-db

# Full restart
make restart
```

### Can't connect to Temporal

1. Wait 1-2 minutes for services to be fully ready
2. Check health: `make health`
3. Verify port 7233 is not in use: `lsof -i :7233`

### Database issues

```bash
# Check PostgreSQL logs
make logs-db

# Test connection
make test-db

# Reset everything (WARNING: deletes data)
make clean
make start
```

### Port conflicts

If ports 7233, 8080, or 5432 are already in use, edit `docker-compose.yml` to change the port mappings:

```yaml
ports:
  - "17233:7233"  # Use 17233 instead of 7233
```

## What's Running?

After `make start`, you'll have:

1. **PostgreSQL** (port 5432)
   - Database: temporal
   - Database: temporal_visibility
   - User: temporal

2. **Temporal Server** (ports 7233, 7234, 7235, 7236, 8233)
   - Frontend service
   - History service
   - Matching service
   - Worker service

3. **Temporal UI** (port 8080)
   - Web-based workflow viewer

4. **Admin Tools**
   - CLI for managing namespaces and clusters

## Production Use

**⚠️ This setup is for development only!**

For production, use the Helm chart in `temporal-helm/`:
- High availability
- TLS/SSL encryption
- Active Directory authentication
- Monitoring with Prometheus
- Scalable architecture

See [temporal-helm/README.md](temporal-helm/README.md) for production deployment.

## Resources

- 📖 [Temporal Documentation](https://docs.temporal.io/)
- 💬 [Community Forum](https://community.temporal.io/)
- 💻 [Sample Applications](https://github.com/temporalio/samples-go)
- 📺 [YouTube Tutorials](https://www.youtube.com/c/Temporalio)

## Getting Help

```bash
# Make help
make help

# Temporal CLI help
docker-compose exec temporal-admin-tools temporal --help

# Check service status
make status

# View all logs
make watch-logs
```

Happy coding with Temporal! 🚀
