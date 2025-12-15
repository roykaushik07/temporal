# Temporal Quick Reference Guide

Quick commands and operations for managing Temporal on OpenShift.

## Table of Contents

- [Installation](#installation)
- [Common Operations](#common-operations)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Database Operations](#database-operations)
- [Security](#security)
- [Backup & Recovery](#backup--recovery)

---

## Installation

### Install Temporal

```bash
# Update dependencies
cd temporal-helm
helm dependency update

# Install
helm install temporal . \
  -f values.yaml \
  -n temporal-production \
  --create-namespace
```

### Upgrade Temporal

```bash
# Dry run first
helm upgrade temporal . \
  -f values.yaml \
  -n temporal-production \
  --dry-run --debug

# Perform upgrade
helm upgrade temporal . \
  -f values.yaml \
  -n temporal-production
```

### Uninstall Temporal

```bash
helm uninstall temporal -n temporal-production
```

---

## Common Operations

### Check Status

```bash
# All pods
oc get pods -n temporal-production

# Specific service
oc get pods -l app.kubernetes.io/component=frontend -n temporal-production

# Deployment status
helm status temporal -n temporal-production
```

### View Logs

```bash
# Frontend logs
oc logs -f -l app.kubernetes.io/component=frontend -n temporal-production

# History service logs
oc logs -f -l app.kubernetes.io/component=history -n temporal-production

# All temporal logs (last 100 lines)
oc logs -l app.kubernetes.io/name=temporal --tail=100 -n temporal-production

# Filter for errors
oc logs -l app.kubernetes.io/component=frontend -n temporal-production | grep -i error
```

### Scale Services

```bash
# Manual scaling
oc scale deployment temporal-frontend --replicas=5 -n temporal-production
oc scale deployment temporal-history --replicas=5 -n temporal-production

# Via Helm (update values.yaml and upgrade)
```

### Restart Services

```bash
# Rolling restart
oc rollout restart deployment/temporal-frontend -n temporal-production

# Restart all
oc rollout restart deployment -l app.kubernetes.io/name=temporal -n temporal-production

# Watch rollout
oc rollout status deployment/temporal-frontend -n temporal-production
```

### Access Services

```bash
# Web UI port forward
oc port-forward svc/temporal-web 8080:8080 -n temporal-production
# Access: http://localhost:8080

# Frontend gRPC port forward
oc port-forward svc/temporal-frontend 7233:7233 -n temporal-production

# PostgreSQL access
oc port-forward svc/temporal-postgresql 5432:5432 -n temporal-production
```

---

## Monitoring

### Prometheus

```bash
# Access Prometheus
oc port-forward svc/temporal-prometheus-server 9090:80 -n temporal-production
# Access: http://localhost:9090

# Check targets
# Go to: http://localhost:9090/targets

# Sample queries:
# - up{job="temporal"}
# - temporal_workflow_started_total
# - rate(temporal_workflow_failed_total[5m])
```

### Grafana

```bash
# Access Grafana
oc port-forward svc/temporal-grafana 3000:80 -n temporal-production
# Access: http://localhost:3000

# Get admin password
oc get secret temporal-grafana \
  -n temporal-production \
  -o jsonpath="{.data.admin-password}" | base64 --decode
```

### Metrics

```bash
# Get service metrics directly
oc exec -it <frontend-pod> -n temporal-production -- \
  wget -qO- http://localhost:9090/metrics

# Check specific metric
oc exec -it <frontend-pod> -n temporal-production -- \
  wget -qO- http://localhost:9090/metrics | grep temporal_workflow_started
```

### View Events

```bash
# Recent events
oc get events -n temporal-production --sort-by='.lastTimestamp'

# Watch events
oc get events -n temporal-production --watch
```

---

## Troubleshooting

### Pod Issues

```bash
# Describe pod
oc describe pod <pod-name> -n temporal-production

# Get pod events
oc get events --field-selector involvedObject.name=<pod-name> -n temporal-production

# Check pod logs (previous container)
oc logs <pod-name> --previous -n temporal-production

# Execute command in pod
oc exec -it <pod-name> -n temporal-production -- /bin/sh
```

### Database Connectivity

```bash
# Test DB connection
oc run -it --rm debug --image=postgres:14 --restart=Never \
  -n temporal-production -- \
  psql -h temporal-postgresql -U temporal -d temporal

# Check DB status
oc exec -it temporal-postgresql-0 -n temporal-production -- \
  psql -U temporal -c "SELECT version();"

# Check active connections
oc exec -it temporal-postgresql-0 -n temporal-production -- \
  psql -U temporal -c "SELECT count(*) FROM pg_stat_activity;"
```

### Network Debugging

```bash
# Test connectivity
oc run -it --rm netdebug --image=nicolaka/netshoot --restart=Never \
  -n temporal-production -- /bin/bash

# Inside pod:
# - nc -zv temporal-frontend 7233
# - nslookup temporal-frontend
# - curl -v http://temporal-frontend:9090/metrics
```

### Authentication Issues

```bash
# Test LDAP connectivity
oc run -it --rm ldaptest --image=ubuntu --restart=Never \
  -n temporal-production -- bash

# Inside pod:
# apt-get update && apt-get install -y ldap-utils
# ldapsearch -x -H ldaps://ldap.company.com:636 \
#   -D "CN=temporal-service,OU=Service Accounts,DC=company,DC=com" \
#   -w "password" \
#   -b "DC=company,DC=com" \
#   "(sAMAccountName=username)"

# Check auth logs
oc logs -l app.kubernetes.io/component=frontend -n temporal-production | grep -i "auth\|ldap"
```

### Resource Usage

```bash
# Pod resource usage
oc top pods -n temporal-production

# Node resource usage
oc top nodes

# Describe resource quotas
oc describe quota -n temporal-production

# Describe limit ranges
oc describe limitrange -n temporal-production
```

---

## Database Operations

### PostgreSQL Management

```bash
# Access PostgreSQL
oc exec -it temporal-postgresql-0 -n temporal-production -- \
  psql -U temporal

# Inside psql:
# \l                    # List databases
# \c temporal           # Connect to database
# \dt                   # List tables
# \du                   # List users
# \q                    # Quit
```

### Database Queries

```bash
# List workflows
oc exec -it temporal-postgresql-0 -n temporal-production -- \
  psql -U temporal -d temporal -c \
  "SELECT count(*) FROM executions;"

# Database size
oc exec -it temporal-postgresql-0 -n temporal-production -- \
  psql -U temporal -c "\l+"

# Table sizes
oc exec -it temporal-postgresql-0 -n temporal-production -- \
  psql -U temporal -d temporal -c \
  "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
   FROM pg_tables
   ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
   LIMIT 10;"
```

### Database Maintenance

```bash
# Vacuum database
oc exec -it temporal-postgresql-0 -n temporal-production -- \
  psql -U temporal -d temporal -c "VACUUM VERBOSE ANALYZE;"

# Check for bloat
oc exec -it temporal-postgresql-0 -n temporal-production -- \
  psql -U temporal -d temporal -c "SELECT schemaname, tablename, n_dead_tup FROM pg_stat_user_tables;"
```

---

## Security

### Secrets Management

```bash
# List secrets
oc get secrets -n temporal-production

# View secret (base64 encoded)
oc get secret temporal-db-secret -n temporal-production -o yaml

# Decode secret
oc get secret temporal-db-secret -n temporal-production \
  -o jsonpath='{.data.password}' | base64 --decode

# Create secret
oc create secret generic my-secret \
  --from-literal=key=value \
  -n temporal-production

# Update secret
oc create secret generic my-secret \
  --from-literal=key=newvalue \
  --dry-run=client -o yaml | oc apply -f -
```

### TLS Certificates

```bash
# Check certificate expiry
oc get secret temporal-frontend-tls -n temporal-production \
  -o jsonpath='{.data.tls\.crt}' | base64 --decode | \
  openssl x509 -noout -enddate

# View certificate details
oc get secret temporal-frontend-tls -n temporal-production \
  -o jsonpath='{.data.tls\.crt}' | base64 --decode | \
  openssl x509 -noout -text
```

### Network Policies

```bash
# List network policies
oc get networkpolicy -n temporal-production

# Describe network policy
oc describe networkpolicy temporal-temporal -n temporal-production

# Test network connectivity (create test pod)
oc run -it --rm nettest --image=busybox --restart=Never \
  -n temporal-production -- sh
```

---

## Backup & Recovery

### Database Backup

```bash
# Manual backup
oc exec -it temporal-postgresql-0 -n temporal-production -- \
  pg_dump -U temporal -Fc temporal > temporal-backup-$(date +%Y%m%d).dump

# Backup visibility database
oc exec -it temporal-postgresql-0 -n temporal-production -- \
  pg_dump -U temporal -Fc temporal_visibility > visibility-backup-$(date +%Y%m%d).dump

# List backup jobs
oc get cronjob -n temporal-production

# Trigger backup job manually
oc create job --from=cronjob/<backup-cronjob-name> manual-backup-$(date +%s) \
  -n temporal-production
```

### Database Restore

```bash
# Stop Temporal services
oc scale deployment --all --replicas=0 -n temporal-production

# Restore database
oc exec -i temporal-postgresql-0 -n temporal-production -- \
  pg_restore -U temporal -d temporal -c < temporal-backup.dump

# Start services
oc scale deployment temporal-frontend --replicas=3 -n temporal-production
oc scale deployment temporal-history --replicas=3 -n temporal-production
oc scale deployment temporal-matching --replicas=3 -n temporal-production
oc scale deployment temporal-worker --replicas=2 -n temporal-production
```

### Volume Snapshots

```bash
# List PVCs
oc get pvc -n temporal-production

# Create volume snapshot
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

# List snapshots
oc get volumesnapshot -n temporal-production
```

### Configuration Backup

```bash
# Export all resources
oc get all,cm,secret,pvc,route,networkpolicy \
  -n temporal-production \
  -o yaml > temporal-backup-$(date +%Y%m%d).yaml

# Export Helm values
helm get values temporal -n temporal-production > values-backup.yaml

# Export Helm manifest
helm get manifest temporal -n temporal-production > manifest-backup.yaml
```

---

## Temporal CLI Operations

### Namespace Management

```bash
# List namespaces
temporal operator namespace list

# Create namespace
temporal operator namespace create my-namespace

# Describe namespace
temporal operator namespace describe default

# Update retention
temporal operator namespace update default --retention 30

# Delete namespace
temporal operator namespace delete my-namespace
```

### Workflow Operations

```bash
# List workflows
temporal workflow list --namespace default

# Describe workflow
temporal workflow describe --workflow-id <workflow-id> --namespace default

# Show workflow history
temporal workflow show --workflow-id <workflow-id> --namespace default

# Terminate workflow
temporal workflow terminate --workflow-id <workflow-id> --namespace default

# Cancel workflow
temporal workflow cancel --workflow-id <workflow-id> --namespace default
```

### Search Attributes

```bash
# List search attributes
temporal operator search-attribute list --namespace default

# Create search attribute
temporal operator search-attribute create \
  --namespace default \
  --name CustomerId \
  --type Keyword

# Remove search attribute
temporal operator search-attribute remove \
  --namespace default \
  --name CustomerId
```

---

## Performance Tuning

### Check Resource Usage

```bash
# CPU and memory usage
oc top pods -n temporal-production --sort-by=cpu
oc top pods -n temporal-production --sort-by=memory

# HPA status
oc get hpa -n temporal-production

# Describe HPA
oc describe hpa temporal-frontend -n temporal-production
```

### Adjust Resources

```bash
# Update CPU limits
oc set resources deployment temporal-frontend \
  --limits=cpu=4000m,memory=4Gi \
  --requests=cpu=1000m,memory=1Gi \
  -n temporal-production

# Update replica count
oc scale deployment temporal-history --replicas=5 -n temporal-production
```

---

## Useful Aliases

Add these to your `.bashrc` or `.zshrc`:

```bash
# Temporal aliases
alias tmp='oc -n temporal-production'
alias tmpg='oc get pods -n temporal-production'
alias tmpl='oc logs -f -l app.kubernetes.io/component=frontend -n temporal-production'
alias tmpd='oc describe pod -n temporal-production'
alias tmpe='oc exec -it -n temporal-production'
alias tmpw='watch oc get pods -n temporal-production'
```

---

## Emergency Procedures

### Service Down

```bash
# 1. Check pod status
oc get pods -n temporal-production

# 2. Check logs
oc logs -l app.kubernetes.io/component=<service> -n temporal-production --tail=100

# 3. Restart service
oc rollout restart deployment/temporal-<service> -n temporal-production

# 4. Watch recovery
oc get pods -n temporal-production --watch
```

### Database Issues

```bash
# 1. Check database connectivity
oc exec -it temporal-postgresql-0 -n temporal-production -- \
  psql -U temporal -c "SELECT 1;"

# 2. Check connections
oc exec -it temporal-postgresql-0 -n temporal-production -- \
  psql -U temporal -c "SELECT count(*) FROM pg_stat_activity;"

# 3. Kill long-running queries
oc exec -it temporal-postgresql-0 -n temporal-production -- \
  psql -U temporal -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'active' AND query_start < now() - interval '1 hour';"
```

### Rollback Deployment

```bash
# View revision history
helm history temporal -n temporal-production

# Rollback to previous version
helm rollback temporal -n temporal-production

# Rollback to specific revision
helm rollback temporal 2 -n temporal-production
```

---

## Additional Resources

- **Full Documentation**: `../README.md`
- **AD Setup Guide**: `./active-directory-setup.md`
- **Deployment Checklist**: `./deployment-checklist.md`
- **Example Configs**: `../examples/`
- **Temporal Docs**: https://docs.temporal.io/
- **Community**: https://community.temporal.io/

---

**Last Updated**: 2025-12-14
