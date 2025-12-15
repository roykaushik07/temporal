# Temporal Deployment Checklist

Use this checklist to ensure all prerequisites are met before deploying Temporal to production.

## Pre-Deployment Checklist

### Infrastructure Requirements

- [ ] **OpenShift Cluster**
  - [ ] OpenShift 4.10 or higher
  - [ ] Cluster admin or namespace admin access
  - [ ] `oc` CLI installed and configured
  - [ ] `helm` v3.8+ installed

- [ ] **Namespace/Project**
  - [ ] Namespace created: `oc new-project temporal-production`
  - [ ] Resource quotas sufficient (32 CPUs, 64Gi Memory minimum)
  - [ ] Limit ranges configured appropriately

- [ ] **Storage**
  - [ ] Storage class available and validated
  - [ ] ~300-500Gi storage capacity available
  - [ ] Dynamic provisioning working
  - [ ] Backup solution for PVCs

- [ ] **Network Access**
  - [ ] Pod-to-pod communication enabled
  - [ ] DNS resolution working
  - [ ] Egress rules for Active Directory (port 636/389)
  - [ ] Container registry accessible

### Database Setup

- [ ] **PostgreSQL Configuration**
  - [ ] Choose: Bundled PostgreSQL or External database
  - [ ] If external: Database created and accessible
  - [ ] Schema initialized (default + visibility databases)
  - [ ] User credentials created
  - [ ] Connection tested from OpenShift
  - [ ] Backup strategy in place

- [ ] **Database Credentials**
  - [ ] Secret created with database password
  - [ ] Secret name matches values.yaml configuration

### Security Configuration

- [ ] **TLS Certificates**
  - [ ] Frontend TLS certificate obtained
  - [ ] Internode TLS certificate obtained (if using mTLS)
  - [ ] CA certificate available
  - [ ] Certificates created as Kubernetes secrets
  - [ ] Certificate expiry monitoring configured

- [ ] **Active Directory Integration**
  - [ ] Service account created in AD
  - [ ] Service account password set (strong password)
  - [ ] Read permissions granted to Users and Groups OUs
  - [ ] Security groups created:
    - [ ] Temporal-Admins
    - [ ] Temporal-Operators
    - [ ] Temporal-Developers
    - [ ] Temporal-Readers
  - [ ] Users added to appropriate groups
  - [ ] AD connectivity tested from OpenShift pods
  - [ ] LDAP/LDAPS accessible (port 389/636)
  - [ ] AD credentials secret created

- [ ] **Network Policies**
  - [ ] Network policies reviewed and configured
  - [ ] Ingress rules defined
  - [ ] Egress rules defined
  - [ ] Policies tested

### Configuration Files

- [ ] **Helm Values**
  - [ ] values.yaml customized for environment
  - [ ] Sensitive values removed from values.yaml
  - [ ] Secrets created separately
  - [ ] Resource limits appropriate for workload
  - [ ] Image repositories accessible
  - [ ] Image pull secrets configured (if needed)

- [ ] **OpenShift Specific**
  - [ ] Route hostnames configured
  - [ ] Route TLS configured
  - [ ] SecurityContextConstraints configured
  - [ ] Service accounts created

### Monitoring Setup

- [ ] **Prometheus**
  - [ ] Prometheus enabled in values.yaml
  - [ ] Storage configured for metrics retention
  - [ ] ServiceMonitor resources will be created
  - [ ] Alert rules configured
  - [ ] Alert manager configured (if using)

- [ ] **Grafana** (Optional)
  - [ ] Grafana enabled if desired
  - [ ] Dashboard URLs validated
  - [ ] Admin credentials configured

- [ ] **Logging**
  - [ ] Log aggregation solution available
  - [ ] Log forwarding configured
  - [ ] Log retention policy defined

### High Availability

- [ ] **Replica Counts**
  - [ ] Frontend: minimum 3 replicas
  - [ ] History: minimum 3 replicas
  - [ ] Matching: minimum 3 replicas
  - [ ] Worker: minimum 2 replicas

- [ ] **Autoscaling**
  - [ ] HPA configured if using autoscaling
  - [ ] Min/max replicas set appropriately
  - [ ] Metrics server available

- [ ] **Pod Disruption Budgets**
  - [ ] PDB configured
  - [ ] minAvailable set appropriately

- [ ] **Anti-Affinity**
  - [ ] Pod anti-affinity rules configured
  - [ ] Topology spread constraints set (if needed)

### Backup and Recovery

- [ ] **Backup Strategy**
  - [ ] Database backup schedule defined
  - [ ] Backup storage configured
  - [ ] Backup retention policy set
  - [ ] Recovery procedure documented
  - [ ] Recovery tested

- [ ] **Disaster Recovery**
  - [ ] DR plan documented
  - [ ] RTO/RPO defined
  - [ ] Failover procedure documented
  - [ ] Multi-region setup (if required)

## Deployment Steps

### 1. Pre-Deployment Validation

- [ ] Validate Helm chart syntax
  ```bash
  helm lint ./temporal-helm
  ```

- [ ] Dry-run installation
  ```bash
  helm install temporal ./temporal-helm \
    -f values.yaml \
    -n temporal-production \
    --dry-run --debug
  ```

- [ ] Review generated manifests
  ```bash
  helm template temporal ./temporal-helm \
    -f values.yaml \
    -n temporal-production > /tmp/temporal-manifests.yaml
  ```

### 2. Helm Dependencies

- [ ] Update Helm dependencies
  ```bash
  cd temporal-helm
  helm dependency update
  ```

- [ ] Verify dependencies downloaded
  ```bash
  ls charts/
  ```

### 3. Secrets Creation

- [ ] Database secret created
- [ ] AD secret created (if using AD)
- [ ] TLS secrets created (if using TLS)
- [ ] Secrets verified
  ```bash
  oc get secrets -n temporal-production
  ```

### 4. Installation

- [ ] Install Temporal
  ```bash
  helm install temporal ./temporal-helm \
    -f values.yaml \
    -n temporal-production \
    --timeout 10m
  ```

- [ ] Monitor installation
  ```bash
  watch oc get pods -n temporal-production
  ```

### 5. Post-Deployment Validation

- [ ] All pods running
  ```bash
  oc get pods -n temporal-production
  ```

- [ ] Services created
  ```bash
  oc get svc -n temporal-production
  ```

- [ ] Routes accessible
  ```bash
  oc get route -n temporal-production
  ```

- [ ] Database connectivity verified
  ```bash
  oc logs -l app.kubernetes.io/component=frontend | grep -i "database\|postgres"
  ```

- [ ] AD authentication working (if configured)
  ```bash
  oc logs -l app.kubernetes.io/component=frontend | grep -i "ldap\|auth"
  ```

## Post-Deployment Configuration

### 1. Temporal Namespaces

- [ ] Create default namespace
  ```bash
  temporal operator namespace create default
  ```

- [ ] Create application-specific namespaces
  ```bash
  temporal operator namespace create aiops-workflows
  temporal operator namespace create monitoring-workflows
  ```

- [ ] Set retention policies
  ```bash
  temporal operator namespace update default --retention 30
  ```

### 2. Search Attributes

- [ ] Create custom search attributes
  ```bash
  temporal operator search-attribute create \
    --namespace default \
    --name CustomerId --type Keyword
  ```

### 3. Monitoring Validation

- [ ] Prometheus scraping metrics
  - [ ] Access Prometheus UI
  - [ ] Query `up{job="temporal"}`
  - [ ] Verify all targets up

- [ ] Grafana dashboards loaded
  - [ ] Access Grafana
  - [ ] Import Temporal dashboards
  - [ ] Verify data visualization

- [ ] Alerts configured
  - [ ] Test alert rules
  - [ ] Verify alert manager integration

### 4. Access Control

- [ ] Web UI accessible
  - [ ] Access route URL
  - [ ] Login with AD credentials
  - [ ] Verify UI loads

- [ ] API access working
  - [ ] Test with Temporal CLI
  - [ ] Verify gRPC connectivity
  - [ ] Test with sample workflow

### 5. Performance Validation

- [ ] Run load test
- [ ] Monitor resource usage
- [ ] Validate autoscaling (if enabled)
- [ ] Check database performance

## Production Readiness

### Documentation

- [ ] Architecture documented
- [ ] Configuration documented
- [ ] Runbooks created
- [ ] Troubleshooting guide available
- [ ] Contact information documented

### Operations

- [ ] Monitoring dashboards created
- [ ] Alerts configured and tested
- [ ] On-call rotation established
- [ ] Escalation procedures defined
- [ ] Maintenance windows scheduled

### Security

- [ ] Security scan completed
- [ ] Vulnerabilities addressed
- [ ] Compliance requirements met
- [ ] Audit logging enabled
- [ ] Incident response plan ready

### Training

- [ ] Operations team trained
- [ ] Development team trained
- [ ] Documentation reviewed
- [ ] Support procedures established

## Go-Live Checklist

- [ ] Stakeholders notified
- [ ] Change request approved
- [ ] Maintenance window scheduled
- [ ] Rollback plan ready
- [ ] Communication plan ready
- [ ] Support team on standby

## Post Go-Live

### Immediate (First 24 hours)

- [ ] Monitor for errors
- [ ] Check all services healthy
- [ ] Verify authentication working
- [ ] Confirm workflows executing
- [ ] Review logs for issues
- [ ] Monitor resource usage

### Short Term (First Week)

- [ ] Daily health checks
- [ ] Performance monitoring
- [ ] User feedback collection
- [ ] Issue tracking
- [ ] Documentation updates

### Long Term (First Month)

- [ ] Weekly reviews
- [ ] Capacity planning
- [ ] Cost analysis
- [ ] Optimization opportunities
- [ ] Lessons learned documentation

## Rollback Procedure

If issues occur during deployment:

1. [ ] Stop new workflow submissions
2. [ ] Assess impact and severity
3. [ ] Execute rollback:
   ```bash
   helm rollback temporal -n temporal-production
   ```
4. [ ] Verify previous version running
5. [ ] Notify stakeholders
6. [ ] Root cause analysis
7. [ ] Plan remediation

## Sign-Off

- [ ] **Technical Lead**: __________________ Date: __________
- [ ] **Security Team**: __________________ Date: __________
- [ ] **Operations Team**: __________________ Date: __________
- [ ] **Management**: __________________ Date: __________

---

## Notes

Use this section for deployment-specific notes, issues encountered, or deviations from the standard process.

---

**Checklist Version**: 1.0
**Last Updated**: 2025-12-14
