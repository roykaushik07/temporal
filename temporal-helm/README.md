# Temporal on OpenShift - Production Deployment Guide

This Helm chart deploys Temporal workflow engine on OpenShift with enterprise-grade features including PostgreSQL persistence, Active Directory authentication, Prometheus monitoring, and production-ready security configurations.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Installation](#detailed-installation)
- [Configuration](#configuration)
- [Active Directory Integration](#active-directory-integration)
- [Security Configuration](#security-configuration)
- [Monitoring and Observability](#monitoring-and-observability)
- [High Availability](#high-availability)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)
- [Backup and Recovery](#backup-and-recovery)

---

## Overview

Temporal is a microservice orchestration platform that enables developers to build scalable and reliable applications. This Helm chart provides a production-ready deployment with:

- **High Availability**: Multi-replica deployments with autoscaling
- **Security**: TLS encryption, Active Directory authentication, network policies
- **Monitoring**: Prometheus metrics, Grafana dashboards, alerting
- **Persistence**: PostgreSQL with replication for data durability
- **OpenShift Integration**: Routes, SecurityContextConstraints, and OpenShift-native features

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        OpenShift Cluster                            │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  Temporal Namespace                                           │ │
│  │                                                               │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │ │
│  │  │  Frontend   │  │   History   │  │  Matching   │          │ │
│  │  │  (3 pods)   │  │  (3 pods)   │  │  (3 pods)   │          │ │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │ │
│  │         │                │                │                   │ │
│  │         └────────────────┴────────────────┘                   │ │
│  │                          │                                    │ │
│  │         ┌────────────────┴──────────────┐                    │ │
│  │         │                               │                    │ │
│  │  ┌──────▼──────┐              ┌────────▼──────┐             │ │
│  │  │  PostgreSQL │              │   Worker      │             │ │
│  │  │  (HA Setup) │              │   (2 pods)    │             │ │
│  │  └─────────────┘              └───────────────┘             │ │
│  │                                                               │ │
│  │  ┌──────────────┐             ┌───────────────┐             │ │
│  │  │  Temporal    │             │  Prometheus   │             │ │
│  │  │  Web UI      │◄────────────│   Metrics     │             │ │
│  │  │  (2 pods)    │             │               │             │ │
│  │  └──────────────┘             └───────────────┘             │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  External Integration                                         │ │
│  │  - Active Directory (LDAP/LDAPS)                              │ │
│  │  - External Monitoring (Optional)                             │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

**Components:**
- **Frontend Service**: Handles API requests from clients
- **History Service**: Manages workflow execution state
- **Matching Service**: Task queue management and routing
- **Worker Service**: Internal background workflows
- **Web UI**: Web-based dashboard for monitoring and management
- **PostgreSQL**: Primary data store (default + visibility databases)
- **Prometheus**: Metrics collection and monitoring
- **Grafana**: Visualization and dashboards (optional)

---

## Prerequisites

### Required Components

Before deploying Temporal, ensure the following are available in your OpenShift environment:

#### 1. OpenShift Cluster
- **Version**: OpenShift 4.10 or higher
- **Access Level**: Cluster-admin or namespace-admin
- **CLI Tools**:
  - `oc` (OpenShift CLI)
  - `helm` v3.8+

#### 2. Storage
- **Storage Class**: Dynamic provisioning-capable storage class
- **Required Capacity**:
  - PostgreSQL: 100Gi (primary) + 100Gi per replica
  - Prometheus: 50Gi
  - Grafana: 10Gi
  - Total: ~300-500Gi depending on configuration

Check available storage classes:
```bash
oc get storageclass
```

#### 3. Namespace/Project
- **Resource Quotas**: Ensure sufficient CPU/Memory quotas
  - **Minimum**: 16 CPUs, 32Gi Memory
  - **Recommended**: 32 CPUs, 64Gi Memory for production

Create namespace:
```bash
oc new-project temporal-production
```

#### 4. Network Access
- **Internal**: Pod-to-pod communication
- **External**:
  - Active Directory/LDAP: Port 389 (LDAP) or 636 (LDAPS)
  - External databases (if used)
  - Container registry for pulling images

#### 5. Active Directory (Optional but Recommended)
- **Service Account**: Read-only account for LDAP queries
- **Groups**: AD groups for authorization mapping
- **Network**: OpenShift cluster can reach AD servers
- **Credentials**: Bind DN and password

#### 6. TLS Certificates (Recommended for Production)
- **Frontend TLS**: Certificate for external API access
- **Internode TLS**: Certificates for service-to-service communication
- **CA Certificate**: Certificate Authority for validation

#### 7. Container Registry Access
- **Public Registry**: Access to Docker Hub or Temporal registry
- **Private Registry**: ImagePullSecrets configured if using private registry

#### 8. Monitoring Stack (Optional)
- **Prometheus Operator**: For ServiceMonitor resources
- **Grafana**: For dashboards and visualization

---

## Quick Start

### 1. Add Helm Dependencies

```bash
cd temporal-helm
helm dependency update
```

This will download:
- PostgreSQL chart (Bitnami)
- Prometheus chart (Prometheus Community)

### 2. Create Namespace

```bash
oc new-project temporal-production
```

### 3. Create Secrets

Create a secrets file `secrets.yaml`:

```yaml
# Database password
secrets:
  database:
    password: "<your-strong-password>"  # Base64 encode this

  # Active Directory bind password
  activeDirectory:
    bindPassword: "<ad-service-account-password>"  # Base64 encode this

  # TLS certificates (if using)
  tls:
    frontend:
      cert: |
        LS0tLS1CRUdJTi... (base64 encoded cert)
      key: |
        LS0tLS1CRUdJTi... (base64 encoded key)
```

To base64 encode:
```bash
echo -n "your-password" | base64
```

### 4. Create Custom Values

Create `my-values.yaml`:

```yaml
# Minimum configuration for quick start
global:
  openshift:
    enabled: true
    createRoute: true

server:
  enabled: true

web:
  enabled: true
  route:
    host: temporal.apps.your-cluster.company.com

postgresql:
  enabled: true
  auth:
    password: "your-db-password"

auth:
  enabled: false  # Enable after initial setup

prometheus:
  enabled: true
```

### 5. Install Temporal

```bash
helm install temporal . \
  -f my-values.yaml \
  -f secrets.yaml \
  -n temporal-production
```

### 6. Verify Installation

```bash
# Check pods
oc get pods -n temporal-production

# Check services
oc get svc -n temporal-production

# Check routes
oc get route -n temporal-production

# View logs
oc logs -l app.kubernetes.io/component=frontend -n temporal-production
```

### 7. Access Web UI

Get the Web UI URL:
```bash
oc get route temporal-web -n temporal-production -o jsonpath='{.spec.host}'
```

Open in browser: `https://<route-host>`

---

## Detailed Installation

### Step 1: Prepare Your Environment

#### 1.1. Create Namespace with Resource Quotas

```bash
# Create namespace
oc new-project temporal-production

# Set resource quotas
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: temporal-quota
  namespace: temporal-production
spec:
  hard:
    requests.cpu: "32"
    requests.memory: 64Gi
    limits.cpu: "64"
    limits.memory: 128Gi
    persistentvolumeclaims: "10"
EOF
```

#### 1.2. Configure Image Pull Secrets (if needed)

```bash
oc create secret docker-registry temporal-registry \
  --docker-server=your-registry.company.com \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email> \
  -n temporal-production
```

Update `values.yaml`:
```yaml
global:
  imagePullSecrets:
    - name: temporal-registry
```

### Step 2: Configure PostgreSQL

#### Option A: Use Bundled PostgreSQL (Recommended for Getting Started)

Default configuration in `values.yaml` includes PostgreSQL with HA:

```yaml
postgresql:
  enabled: true
  architecture: replication
  auth:
    username: temporal
    database: temporal
    password: ""  # Will be auto-generated if not set

  primary:
    resources:
      requests:
        cpu: 1000m
        memory: 2Gi
    persistence:
      enabled: true
      size: 100Gi
```

#### Option B: Use External PostgreSQL

If using existing PostgreSQL:

```yaml
postgresql:
  enabled: false

externalDatabase:
  enabled: true
  host: postgres.company.com
  port: 5432
  user: temporal
  database: temporal
  existingSecret: temporal-external-db-secret
  passwordKey: password
```

Create the secret:
```bash
oc create secret generic temporal-external-db-secret \
  --from-literal=password='your-db-password' \
  -n temporal-production
```

#### Initialize Databases

If using external database, initialize schema:

```bash
# Download Temporal schema
wget https://raw.githubusercontent.com/temporalio/temporal/master/schema/postgresql/v96/temporal/schema.sql
wget https://raw.githubusercontent.com/temporalio/temporal/master/schema/postgresql/v96/visibility/schema.sql

# Apply schema
psql -h postgres.company.com -U temporal -d temporal < schema.sql
psql -h postgres.company.com -U temporal -d temporal_visibility < visibility_schema.sql
```

### Step 3: Configure TLS Certificates

#### 3.1. Generate Self-Signed Certificates (Development Only)

```bash
# Create CA
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
  -subj "/CN=Temporal CA"

# Create frontend certificate
openssl genrsa -out frontend.key 2048
openssl req -new -key frontend.key -out frontend.csr \
  -subj "/CN=temporal-frontend"
openssl x509 -req -in frontend.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out frontend.crt -days 365

# Create internode certificate
openssl genrsa -out internode.key 2048
openssl req -new -key internode.key -out internode.csr \
  -subj "/CN=temporal"
openssl x509 -req -in internode.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out internode.crt -days 365
```

#### 3.2. Create TLS Secrets

```bash
# Frontend TLS
oc create secret tls temporal-frontend-tls \
  --cert=frontend.crt \
  --key=frontend.key \
  -n temporal-production

# Internode TLS
oc create secret tls temporal-internode-tls \
  --cert=internode.crt \
  --key=internode.key \
  -n temporal-production

# CA Certificate
oc create secret generic temporal-client-ca \
  --from-file=ca.crt=ca.crt \
  -n temporal-production
```

#### 3.3. Use Production Certificates (Recommended)

For production, use certificates from your organization's PKI:

```bash
# Get certificates from cert-manager or your PKI
oc create secret tls temporal-frontend-tls \
  --cert=/path/to/your/cert.pem \
  --key=/path/to/your/key.pem \
  -n temporal-production
```

### Step 4: Configure Active Directory Authentication

See the detailed [Active Directory Integration Guide](./docs/active-directory-setup.md).

#### 4.1. Create AD Service Account

In Active Directory, create a service account:
- **Username**: `temporal-service@company.com`
- **Password**: Strong password
- **Permissions**: Read-only access to Users and Groups OUs

#### 4.2. Create AD Secret

```bash
oc create secret generic temporal-ad-secret \
  --from-literal=ad-bind-password='your-ad-service-account-password' \
  -n temporal-production
```

#### 4.3. Configure AD in values.yaml

```yaml
auth:
  enabled: true
  activeDirectory:
    enabled: true
    server:
      host: ldap.company.com
      port: 636
      useSSL: true
      bindDN: "CN=temporal-service,OU=Service Accounts,DC=company,DC=com"
      bindPasswordSecret: temporal-ad-secret
      bindPasswordKey: ad-bind-password

    user:
      baseDN: "OU=Users,DC=company,DC=com"
      filter: "(sAMAccountName=%s)"

    group:
      baseDN: "OU=Groups,DC=company,DC=com"

    authorization:
      enabled: true
      adminGroups:
        - "CN=Temporal-Admins,OU=Groups,DC=company,DC=com"
```

### Step 5: Configure Monitoring

#### 5.1. Enable Prometheus

Already enabled by default in `values.yaml`:

```yaml
prometheus:
  enabled: true
  server:
    retention: 15d
```

#### 5.2. Configure ServiceMonitor

```yaml
serviceMonitor:
  enabled: true
  interval: 30s
```

#### 5.3. Install Grafana Dashboards

```yaml
grafana:
  enabled: true
  dashboards:
    temporal:
      temporal-overview:
        url: https://raw.githubusercontent.com/temporalio/dashboards/master/server/server_general.json
```

### Step 6: Deploy Temporal

#### 6.1. Validate Configuration

```bash
# Dry-run to check for errors
helm install temporal . \
  -f values.yaml \
  -n temporal-production \
  --dry-run --debug
```

#### 6.2. Install

```bash
helm install temporal . \
  -f values.yaml \
  -n temporal-production \
  --timeout 10m
```

#### 6.3. Monitor Deployment

```bash
# Watch pods coming up
watch oc get pods -n temporal-production

# Check deployment status
helm status temporal -n temporal-production

# View logs
oc logs -f -l app.kubernetes.io/component=frontend -n temporal-production
```

### Step 7: Post-Installation Configuration

#### 7.1. Create Namespaces

```bash
# Install temporal CLI
# Visit: https://docs.temporal.io/cli

# Create namespaces
temporal operator namespace create default
temporal operator namespace create aiops-workflows
temporal operator namespace create monitoring-workflows
```

#### 7.2. Configure Default Namespace Retention

```bash
temporal operator namespace update default \
  --retention 30
```

#### 7.3. Register Search Attributes (if using advanced search)

```bash
temporal operator search-attribute create \
  --namespace default \
  --name CustomerId --type Keyword

temporal operator search-attribute create \
  --namespace default \
  --name Environment --type Keyword
```

---

## Configuration

### Core Configuration Options

#### Server Configuration

```yaml
server:
  # Replica counts for each service
  replicaCount:
    frontend: 3      # API gateway
    history: 3       # Workflow state
    matching: 3      # Task routing
    worker: 2        # Internal workflows

  # Resource limits
  resources:
    frontend:
      requests:
        cpu: 500m
        memory: 512Mi
      limits:
        cpu: 2000m
        memory: 2Gi
```

#### Autoscaling

```yaml
server:
  autoscaling:
    enabled: true
    frontend:
      minReplicas: 3
      maxReplicas: 10
      targetCPUUtilizationPercentage: 70
```

#### Database Configuration

```yaml
postgresql:
  enabled: true
  architecture: replication  # HA setup
  replication:
    enabled: true
    readReplicas: 2
    synchronousCommit: "on"
```

#### Dynamic Configuration

Adjust runtime behavior without restart:

```yaml
dynamicConfig:
  "frontend.rps":
    - value: 2400  # Requests per second limit

  "history.maxPageSize":
    - value: 1000  # Max workflows per query

  "system.namespaceDefaultRetentionDays":
    - value: 30  # Default retention period
```

### Network Configuration

#### Routes (OpenShift)

```yaml
web:
  route:
    enabled: true
    host: temporal.apps.openshift.company.com
    tls:
      enabled: true
      termination: edge  # edge, passthrough, or reencrypt
```

#### Network Policies

```yaml
networkPolicy:
  enabled: true
  ingress:
    - from:
      - podSelector: {}  # Same namespace
    - from:
      - namespaceSelector:
          matchLabels:
            name: openshift-ingress
```

### Security Configuration

#### Security Context

```yaml
securityContext:
  enabled: true
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
  containerSecurityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
```

---

## Active Directory Integration

### Overview

Active Directory authentication allows users to login with their corporate credentials and provides role-based access control (RBAC) based on AD group membership.

### Architecture

```
User → Web UI/API → Temporal Frontend → LDAP Query → Active Directory
                                      ↓
                              Group Membership Check
                                      ↓
                              Authorization Decision
```

### Configuration Steps

#### 1. Test AD Connectivity

Before configuring Temporal, test LDAP connectivity:

```bash
# Install ldapsearch
oc debug node/<node-name>
chroot /host
dnf install openldap-clients

# Test LDAP connection
ldapsearch -x -H ldaps://ldap.company.com:636 \
  -D "CN=temporal-service,OU=Service Accounts,DC=company,DC=com" \
  -w "password" \
  -b "DC=company,DC=com" \
  "(sAMAccountName=yourusername)"
```

#### 2. Configure AD in values.yaml

```yaml
auth:
  enabled: true
  activeDirectory:
    enabled: true

    # LDAP Server Configuration
    server:
      host: ldap.company.com
      port: 636  # 389 for LDAP, 636 for LDAPS
      useSSL: true
      useTLS: true
      skipVerify: false  # Set to false with valid certs

      # Service account credentials
      bindDN: "CN=temporal-service,OU=Service Accounts,DC=company,DC=com"
      bindPasswordSecret: temporal-ad-secret
      bindPasswordKey: ad-bind-password

    # User Search Configuration
    user:
      baseDN: "OU=Users,DC=company,DC=com"
      filter: "(sAMAccountName=%s)"  # %s = username
      usernameAttribute: sAMAccountName
      emailAttribute: mail
      displayNameAttribute: displayName
      groupMembershipAttribute: memberOf

    # Group Search Configuration
    group:
      baseDN: "OU=Groups,DC=company,DC=com"
      filter: "(objectClass=group)"
      nameAttribute: cn
      memberAttribute: member

    # Authorization - Map AD groups to Temporal roles
    authorization:
      enabled: true

      # Admins: Full access
      adminGroups:
        - "CN=Temporal-Admins,OU=Groups,DC=company,DC=com"
        - "CN=Platform-Engineers,OU=Groups,DC=company,DC=com"

      # Operators: Can manage workflows
      operatorGroups:
        - "CN=Temporal-Operators,OU=Groups,DC=company,DC=com"

      # Developers: Can start/query workflows
      developerGroups:
        - "CN=Temporal-Developers,OU=Groups,DC=company,DC=com"

      # Read-only: View-only access
      readOnlyGroups:
        - "CN=Temporal-Readers,OU=Groups,DC=company,DC=com"
```

#### 3. Create Required AD Groups

Create these groups in Active Directory:

| Group Name | Purpose | Permissions |
|------------|---------|-------------|
| Temporal-Admins | Full administrative access | All operations |
| Temporal-Operators | Workflow management | Start, stop, query workflows |
| Temporal-Developers | Development access | Start workflows, view results |
| Temporal-Readers | Read-only monitoring | View workflows only |

#### 4. Add Users to Groups

Add your users to appropriate groups based on their role.

### Testing AD Authentication

After deployment, test authentication:

```bash
# Using Temporal CLI
temporal operator namespace list \
  --address temporal-frontend.temporal-production.svc.cluster.local:7233 \
  --tls-cert-path client.crt \
  --tls-key-path client.key
```

### Troubleshooting AD Integration

#### Common Issues

**Issue 1: Cannot connect to LDAP server**

```bash
# Check network connectivity
oc debug
nc -zv ldap.company.com 636

# Check DNS resolution
nslookup ldap.company.com
```

**Issue 2: Authentication fails with correct credentials**

Check logs:
```bash
oc logs -l app.kubernetes.io/component=frontend | grep -i ldap
```

Common causes:
- Incorrect bindDN format
- Wrong base DN
- User not in specified base DN
- Invalid filter syntax

**Issue 3: User authenticated but no permissions**

- Verify group membership in AD
- Check group DN format in configuration
- Ensure user's `memberOf` attribute includes the group

### Alternative: OIDC with ADFS

If you have Active Directory Federation Services (ADFS):

```yaml
auth:
  oidc:
    enabled: true
    issuer: "https://adfs.company.com/adfs"
    clientId: "temporal-web-ui"
    clientSecretKey: oidc-client-secret
    redirectURL: "https://temporal.apps.company.com/auth/callback"
    scopes:
      - openid
      - profile
      - email
```

---

## Monitoring and Observability

### Prometheus Metrics

Temporal exports comprehensive metrics:

#### Key Metrics to Monitor

**Service Health:**
- `temporal_service_requests_total` - Total requests
- `temporal_service_errors_total` - Total errors
- `temporal_service_latency_bucket` - Request latency

**Workflow Metrics:**
- `temporal_workflow_started_total` - Workflows started
- `temporal_workflow_completed_total` - Completed workflows
- `temporal_workflow_failed_total` - Failed workflows
- `temporal_workflow_timeout_total` - Timed out workflows

**Task Queue Metrics:**
- `temporal_task_queue_depth` - Tasks waiting in queue
- `temporal_task_queue_lag_seconds` - Queue processing lag

**Resource Metrics:**
- `temporal_history_size_bytes` - Workflow history size
- `temporal_activity_execution_latency` - Activity latency

### Grafana Dashboards

Import pre-built dashboards:

```bash
# Access Grafana
oc get route grafana -n temporal-production

# Dashboards included:
# 1. Temporal Overview - High-level metrics
# 2. Frontend Service - API metrics
# 3. History Service - Workflow execution
# 4. Matching Service - Task queue metrics
```

### Alerting Rules

Configure alerts in `values.yaml`:

```yaml
prometheus:
  serverFiles:
    alerting_rules.yml:
      groups:
        - name: temporal-critical
          rules:
            - alert: TemporalServiceDown
              expr: up{job="temporal"} == 0
              for: 5m
              labels:
                severity: critical

            - alert: HighWorkflowFailureRate
              expr: rate(temporal_workflow_failed_total[5m]) > 0.1
              for: 5m
              labels:
                severity: warning

            - alert: HighTaskQueueLag
              expr: temporal_task_queue_lag_seconds > 300
              for: 10m
              labels:
                severity: warning
```

### Log Aggregation

Temporal outputs structured JSON logs:

```bash
# View logs
oc logs -l app.kubernetes.io/component=frontend -n temporal-production

# With jq for filtering
oc logs -l app.kubernetes.io/component=frontend | jq 'select(.level=="error")'
```

Configure centralized logging:
- Forward to ELK stack
- Send to Splunk
- Use OpenShift logging operator

---

## High Availability

### Multi-Replica Deployment

Ensure HA for all services:

```yaml
server:
  replicaCount:
    frontend: 3
    history: 3
    matching: 3
    worker: 2
```

### Pod Disruption Budgets

Prevent too many pods being evicted:

```yaml
server:
  podDisruptionBudget:
    enabled: true
    minAvailable: 2  # At least 2 pods must be running
```

### Database HA

PostgreSQL replication:

```yaml
postgresql:
  architecture: replication
  replication:
    enabled: true
    readReplicas: 2
    synchronousCommit: "on"
    numSynchronousReplicas: 1
```

### Anti-Affinity Rules

Spread pods across nodes:

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - temporal
          topologyKey: kubernetes.io/hostname
```

### Backup Strategy

#### Database Backups

```yaml
postgresql:
  backup:
    enabled: true
    cronjob:
      schedule: "0 2 * * *"  # Daily at 2 AM
```

Manual backup:
```bash
oc exec -it temporal-postgresql-0 -- \
  pg_dump -U temporal temporal > temporal-backup-$(date +%Y%m%d).sql
```

---

## Troubleshooting

### Common Issues

#### 1. Pods Not Starting

**Check pod status:**
```bash
oc get pods -n temporal-production
oc describe pod <pod-name> -n temporal-production
```

**Common causes:**
- Insufficient resources
- Image pull errors
- Storage provisioning issues
- Security context constraints

**Solutions:**
```bash
# Check resource quotas
oc describe quota -n temporal-production

# Check events
oc get events -n temporal-production --sort-by='.lastTimestamp'

# Check SCC
oc get pod <pod-name> -o yaml | grep scc
```

#### 2. Database Connection Failures

**Symptoms:**
- Pods in CrashLoopBackOff
- Logs show "connection refused" or "authentication failed"

**Debug:**
```bash
# Check PostgreSQL status
oc get pods -l app=postgresql

# Test connectivity
oc run -it --rm debug --image=postgres:14 --restart=Never -- \
  psql -h temporal-postgresql -U temporal -d temporal

# Check secrets
oc get secret temporal-db-secret -o yaml
```

#### 3. High Latency

**Check metrics:**
```bash
# Query Prometheus
curl -G http://prometheus-server/api/v1/query \
  --data-urlencode 'query=temporal_service_latency_bucket'
```

**Possible solutions:**
- Scale up services
- Increase database resources
- Check network policies
- Review dynamic config limits

#### 4. Web UI Not Accessible

**Check route:**
```bash
oc get route temporal-web -n temporal-production
oc describe route temporal-web
```

**Test service:**
```bash
oc port-forward svc/temporal-web 8080:8080
# Access http://localhost:8080
```

#### 5. Authentication Issues

**Check AD connectivity:**
```bash
# From a pod
oc exec -it <frontend-pod> -- /bin/sh
nc -zv ldap.company.com 636
```

**View auth logs:**
```bash
oc logs -l app.kubernetes.io/component=frontend | grep -i auth
```

### Debug Mode

Enable debug logging:

```yaml
server:
  config:
    log:
      level: debug  # Change from 'info' to 'debug'
```

```bash
# Apply changes
helm upgrade temporal . -f values.yaml -n temporal-production
```

### Health Checks

Check service health:

```bash
# Frontend health
oc port-forward svc/temporal-frontend 7233:7233
grpcurl -plaintext localhost:7233 temporal.api.workflowservice.v1.WorkflowService/GetSystemInfo
```

---

## Maintenance

### Upgrade Temporal

```bash
# Update chart version in Chart.yaml
# Update image tags in values.yaml

# Dry-run upgrade
helm upgrade temporal . \
  -f values.yaml \
  -n temporal-production \
  --dry-run --debug

# Perform upgrade
helm upgrade temporal . \
  -f values.yaml \
  -n temporal-production
```

### Rolling Restart

```bash
# Restart specific service
oc rollout restart deployment/temporal-frontend -n temporal-production

# Watch rollout
oc rollout status deployment/temporal-frontend -n temporal-production
```

### Scale Services

```bash
# Manual scaling
oc scale deployment temporal-history --replicas=5 -n temporal-production

# Or update values.yaml and helm upgrade
```

### Database Maintenance

#### Vacuum and Analyze

```bash
oc exec -it temporal-postgresql-0 -- \
  psql -U temporal -c "VACUUM ANALYZE;"
```

#### Check Database Size

```bash
oc exec -it temporal-postgresql-0 -- \
  psql -U temporal -c "\l+"
```

---

## Backup and Recovery

### Backup Strategy

#### 1. Database Backups

**Automated (via Helm):**
```yaml
postgresql:
  backup:
    enabled: true
    cronjob:
      schedule: "0 2 * * *"
      storage:
        size: 200Gi
```

**Manual:**
```bash
# Full backup
oc exec -it temporal-postgresql-0 -- \
  pg_dump -U temporal -Fc temporal > temporal-backup.dump

# Backup visibility database
oc exec -it temporal-postgresql-0 -- \
  pg_dump -U temporal -Fc temporal_visibility > visibility-backup.dump
```

#### 2. Configuration Backups

```bash
# Export all resources
oc get all,cm,secret,pvc -n temporal-production -o yaml > temporal-backup.yaml

# Backup Helm values
helm get values temporal -n temporal-production > temporal-values-backup.yaml
```

#### 3. Persistent Volume Snapshots

```bash
# Create PVC snapshot
oc get pvc -n temporal-production

cat <<EOF | oc apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: temporal-db-snapshot-$(date +%Y%m%d)
  namespace: temporal-production
spec:
  source:
    persistentVolumeClaimName: data-temporal-postgresql-0
EOF
```

### Recovery Procedures

#### 1. Restore from Database Backup

```bash
# Stop Temporal services
oc scale deployment --all --replicas=0 -n temporal-production

# Restore database
oc exec -it temporal-postgresql-0 -- \
  pg_restore -U temporal -d temporal -c temporal-backup.dump

# Start services
oc scale deployment --all --replicas=3 -n temporal-production
```

#### 2. Disaster Recovery

```bash
# Full reinstall
helm uninstall temporal -n temporal-production

# Restore database from backup
# (See above)

# Reinstall with same configuration
helm install temporal . -f temporal-values-backup.yaml -n temporal-production
```

---

## Performance Tuning

### Database Optimization

```yaml
postgresql:
  primary:
    extendedConfiguration: |
      max_connections = 500
      shared_buffers = 2GB
      effective_cache_size = 6GB
      maintenance_work_mem = 512MB
      checkpoint_completion_target = 0.9
      wal_buffers = 16MB
      default_statistics_target = 100
      random_page_cost = 1.1
      effective_io_concurrency = 200
      work_mem = 4MB
```

### Service Tuning

```yaml
dynamicConfig:
  # Rate limiting
  "frontend.rps":
    - value: 2400

  # Concurrent operations
  "history.maxAutoResetPoints":
    - value: 20

  # Task queue
  "matching.numTaskqueueReadPartitions":
    - value: 5
  "matching.numTaskqueueWritePartitions":
    - value: 5
```

---

## Security Hardening

### 1. Network Policies

Restrict traffic to only necessary connections:

```yaml
networkPolicy:
  enabled: true
  ingress:
    - from:
      - podSelector: {}  # Same namespace only
  egress:
    - to:
      - podSelector:
          matchLabels:
            app: postgresql
      ports:
        - protocol: TCP
          port: 5432
```

### 2. Pod Security

```yaml
securityContext:
  enabled: true
  containerSecurityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 1000
```

### 3. Secrets Management

Use external secrets operator:

```bash
# Install External Secrets Operator
oc apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml
```

### 4. RBAC

Limit service account permissions:

```yaml
serviceAccount:
  create: true
  annotations:
    # Add RBAC annotations
```

---

## Additional Resources

### Documentation
- [Temporal Documentation](https://docs.temporal.io/)
- [Temporal Architecture](https://docs.temporal.io/clusters)
- [OpenShift Documentation](https://docs.openshift.com/)

### Support
- GitHub Issues: https://github.com/temporalio/temporal
- Community Forum: https://community.temporal.io/
- Slack: https://temporal.io/slack

### Monitoring
- [Grafana Dashboards](https://github.com/temporalio/dashboards)
- [Prometheus Metrics](https://docs.temporal.io/references/cluster-metrics)

---

## License

This Helm chart is provided as-is for deploying Temporal in OpenShift environments.

---

**Version**: 1.0.0
**Last Updated**: 2025-12-14
**Maintained By**: Your DevOps Team
