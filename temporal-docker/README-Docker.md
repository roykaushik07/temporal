# Temporal Docker Setup

This directory contains a complete Docker setup for running Temporal locally.

## Components

The setup includes:

1. **Temporal Server** - The main Temporal server with all services (frontend, history, matching, worker)
2. **PostgreSQL** - Database for persistence
3. **Temporal UI** - Web interface for monitoring workflows
4. **Admin Tools** - CLI tools for administrative tasks

## Quick Start

### 1. Build and Start Services

```bash
# Build the custom Temporal image
docker-compose build

# Start all services
docker-compose up -d

# Check service status
docker-compose ps
```

### 2. Wait for Services to be Healthy

```bash
# Watch logs
docker-compose logs -f temporal

# Check health
docker-compose ps
```

The services should be healthy within 1-2 minutes.

### 3. Access the Services

- **Temporal UI**: http://localhost:8080
- **Temporal Frontend (gRPC)**: localhost:7233
- **PostgreSQL**: localhost:5432

### 4. Create a Default Namespace

```bash
# Using the admin tools container
docker-compose exec temporal-admin-tools temporal operator namespace create default

# Or register a namespace with retention
docker-compose exec temporal-admin-tools temporal operator namespace create my-namespace --retention 7
```

### 5. Verify Installation

```bash
# List namespaces
docker-compose exec temporal-admin-tools temporal operator namespace list

# Check cluster health
docker-compose exec temporal-admin-tools temporal operator cluster health

# Get system information
docker-compose exec temporal-admin-tools temporal operator cluster system
```

## Using the Temporal CLI

The `temporal-admin-tools` container has the Temporal CLI pre-installed:

```bash
# Interactive shell
docker-compose exec temporal-admin-tools bash

# Inside the container, you can run temporal commands:
temporal operator namespace list
temporal workflow list --namespace default
```

## Running Workflows

### Using the Temporal SDK

Connect your application to `localhost:7233`:

**Go Example:**
```go
client, err := client.Dial(client.Options{
    HostPort: "localhost:7233",
})
```

**Python Example:**
```python
client = await Client.connect("localhost:7233")
```

**Java Example:**
```java
WorkflowServiceStubs service = WorkflowServiceStubs.newInstance(
    WorkflowServiceStubsOptions.newBuilder()
        .setTarget("localhost:7233")
        .build()
);
```

**TypeScript Example:**
```typescript
const connection = await Connection.connect({
    address: 'localhost:7233',
});
```

## Database Schema

The PostgreSQL setup automatically creates two databases:
- `temporal` - Main database for workflow state
- `temporal_visibility` - Database for workflow visibility/search

The Temporal server will automatically apply the schema on first startup.

## Configuration

### Modify Server Configuration

Edit `config/development.yaml` to customize:
- Database connections
- Service ports
- Cluster settings
- Archival settings

### Environment Variables

Key environment variables in `docker-compose.yml`:
- `DB` - Database type (postgresql, mysql, cassandra)
- `POSTGRES_USER` - Database username
- `POSTGRES_PWD` - Database password
- `POSTGRES_SEEDS` - PostgreSQL host

## Persistence

Data is persisted in Docker volumes:
- `postgres-data` - PostgreSQL data

To reset all data:
```bash
docker-compose down -v
docker-compose up -d
```

## Monitoring

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f temporal
docker-compose logs -f postgresql
docker-compose logs -f temporal-ui
```

### Metrics

Temporal exports Prometheus metrics on port 9090 (not exposed by default).

To enable metrics monitoring, add Prometheus to `docker-compose.yml`:

```yaml
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - temporal-network
```

## Troubleshooting

### Services Not Starting

```bash
# Check logs
docker-compose logs temporal

# Check database connection
docker-compose exec postgresql psql -U temporal -d temporal -c "SELECT 1"
```

### Database Connection Issues

```bash
# Verify PostgreSQL is running
docker-compose ps postgresql

# Check PostgreSQL logs
docker-compose logs postgresql

# Test connection from temporal container
docker-compose exec temporal nc -zv postgresql 5432
```

### Reset Everything

```bash
# Stop and remove all containers and volumes
docker-compose down -v

# Rebuild and restart
docker-compose build --no-cache
docker-compose up -d
```

## Advanced Usage

### Using with External Database

To use an external PostgreSQL instance:

1. Modify `docker-compose.yml` to remove the `postgresql` service
2. Update environment variables in the `temporal` service:
   ```yaml
   environment:
     - POSTGRES_SEEDS=your-external-db.example.com
     - POSTGRES_USER=your-user
     - POSTGRES_PWD=your-password
   ```

### TLS/SSL Configuration

For production use with TLS:

1. Generate or obtain certificates
2. Mount certificates into the container
3. Update `config/development.yaml` with TLS settings

### Cluster Mode (Multi-node)

This setup runs all services in a single container. For a distributed setup:

1. Run separate containers for each service (frontend, history, matching, worker)
2. Configure service discovery
3. Use external load balancer

## Stopping Services

```bash
# Stop all services
docker-compose stop

# Stop and remove containers
docker-compose down

# Stop and remove containers and volumes
docker-compose down -v
```

## Production Considerations

This setup is designed for **development and testing**. For production:

1. Use the Helm chart in `temporal-helm/` for Kubernetes/OpenShift
2. Enable TLS/SSL encryption
3. Use external, managed database with replication
4. Configure proper resource limits
5. Set up monitoring and alerting
6. Enable archival for long-term storage
7. Configure authentication and authorization

See the main [README.md](temporal-helm/README.md) for production deployment with Helm.

## Resources

- [Temporal Documentation](https://docs.temporal.io/)
- [Temporal Server on Docker Hub](https://hub.docker.com/r/temporalio/server)
- [Temporal UI on Docker Hub](https://hub.docker.com/r/temporalio/ui)
- [Temporal CLI Documentation](https://docs.temporal.io/cli)

## Version Information

- **Temporal Server**: 1.24.2
- **Temporal UI**: 2.22.3
- **PostgreSQL**: 14
- **Admin Tools**: 1.24.2
