# Active Directory Authentication Setup Guide

This guide provides detailed instructions for integrating Temporal with Active Directory (AD) for enterprise authentication and authorization.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Step-by-Step Setup](#step-by-step-setup)
- [Configuration Examples](#configuration-examples)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Alternative: ADFS/Azure AD](#alternative-adfsazure-ad)

---

## Overview

Active Directory integration provides:
- **Single Sign-On (SSO)**: Users authenticate with corporate credentials
- **Centralized User Management**: Users managed in AD, not Temporal
- **Group-Based Authorization**: Permissions based on AD group membership
- **Audit Trail**: Authentication events logged centrally

### Authentication Flow

```
┌──────┐         ┌──────────┐         ┌──────────┐         ┌────────────┐
│ User │────────>│Temporal  │────────>│ Temporal │────────>│   Active   │
│      │         │  Web UI  │         │ Frontend │         │ Directory  │
└──────┘         └──────────┘         └──────────┘         └────────────┘
   1. Login          2. Forward           3. LDAP              4. Verify
   Request           Credentials          Bind                 Credentials
                                                                    │
                                                                    │
   ┌────────────────────────────────────────────────────────────────┘
   │
   ▼
5. Return User Info + Groups
   │
   ▼
6. Map Groups to Roles
   │
   ▼
7. Grant Access
```

---

## Prerequisites

### Active Directory Requirements

1. **LDAP/LDAPS Access**
   - Network connectivity from OpenShift to AD servers
   - Port 389 (LDAP) or 636 (LDAPS)
   - Firewall rules allowing traffic

2. **Service Account**
   - Read-only account for LDAP queries
   - No special privileges required
   - Must be able to read user and group information

3. **Organizational Units (OUs)**
   - Users OU containing user accounts
   - Groups OU containing security groups

4. **Security Groups**
   - Groups for different access levels
   - Groups should use standard AD group types

### OpenShift/Temporal Requirements

1. **Network Access**
   - Pods can reach AD controllers
   - DNS resolution for AD domain

2. **Certificates** (for LDAPS)
   - AD server certificates trusted by OpenShift
   - CA certificate available

---

## Architecture

### LDAP Directory Structure

Your Active Directory should be organized like:

```
DC=company,DC=com
│
├── OU=Service Accounts
│   └── CN=temporal-service
│
├── OU=Users
│   ├── CN=John Doe
│   ├── CN=Jane Smith
│   └── CN=...
│
└── OU=Groups
    ├── CN=Temporal-Admins
    ├── CN=Temporal-Operators
    ├── CN=Temporal-Developers
    └── CN=Temporal-Readers
```

### Role Mapping

| AD Group | Temporal Role | Permissions |
|----------|---------------|-------------|
| Temporal-Admins | Admin | Full access to all namespaces, server configuration |
| Temporal-Operators | Operator | Manage workflows, view all data |
| Temporal-Developers | Developer | Start workflows, query own workflows |
| Temporal-Readers | Reader | Read-only access to workflows |

---

## Step-by-Step Setup

### Step 1: Create Service Account in AD

#### Option A: Using PowerShell (on AD Controller)

```powershell
# Create service account
New-ADUser -Name "temporal-service" `
  -SamAccountName "temporal-service" `
  -UserPrincipalName "temporal-service@company.com" `
  -Path "OU=Service Accounts,DC=company,DC=com" `
  -AccountPassword (ConvertTo-SecureString "YourStrongPassword123!" -AsPlainText -Force) `
  -Enabled $true `
  -PasswordNeverExpires $true `
  -CannotChangePassword $true `
  -Description "Temporal LDAP service account"

# Verify creation
Get-ADUser -Identity temporal-service
```

#### Option B: Using Active Directory Users and Computers (GUI)

1. Open "Active Directory Users and Computers"
2. Navigate to "Service Accounts" OU
3. Right-click → New → User
4. Fill in:
   - First name: temporal
   - Last name: service
   - User logon name: temporal-service
5. Set password (strong password required)
6. Check: "Password never expires"
7. Uncheck: "User must change password at next logon"
8. Finish

#### Verify Service Account

```bash
# Test from any machine with AD tools
ldapsearch -x -H ldap://ldap.company.com \
  -D "CN=temporal-service,OU=Service Accounts,DC=company,DC=com" \
  -w "YourStrongPassword123!" \
  -b "DC=company,DC=com" \
  "(objectClass=user)" cn
```

### Step 2: Create Security Groups

Create groups for different access levels:

#### PowerShell Commands

```powershell
# Create groups
New-ADGroup -Name "Temporal-Admins" `
  -SamAccountName "Temporal-Admins" `
  -GroupCategory Security `
  -GroupScope Global `
  -Path "OU=Groups,DC=company,DC=com" `
  -Description "Temporal administrators with full access"

New-ADGroup -Name "Temporal-Operators" `
  -SamAccountName "Temporal-Operators" `
  -GroupCategory Security `
  -GroupScope Global `
  -Path "OU=Groups,DC=company,DC=com" `
  -Description "Temporal operators who can manage workflows"

New-ADGroup -Name "Temporal-Developers" `
  -SamAccountName "Temporal-Developers" `
  -GroupCategory Security `
  -GroupScope Global `
  -Path "OU=Groups,DC=company,DC=com" `
  -Description "Temporal developers who can start workflows"

New-ADGroup -Name "Temporal-Readers" `
  -SamAccountName "Temporal-Readers" `
  -GroupCategory Security `
  -GroupScope Global `
  -Path "OU=Groups,DC=company,DC=com" `
  -Description "Temporal read-only users"

# Verify creation
Get-ADGroup -Filter {Name -like "Temporal-*"}
```

### Step 3: Add Users to Groups

```powershell
# Add users to groups
Add-ADGroupMember -Identity "Temporal-Admins" -Members "john.doe", "jane.admin"
Add-ADGroupMember -Identity "Temporal-Developers" -Members "dev.user1", "dev.user2"
Add-ADGroupMember -Identity "Temporal-Readers" -Members "readonly.user"

# Verify membership
Get-ADGroupMember -Identity "Temporal-Admins"
```

### Step 4: Configure Network Access

#### Test Connectivity from OpenShift

```bash
# Create a test pod
oc run ldap-test --image=ubuntu --restart=Never -it --rm -- bash

# Inside pod
apt-get update && apt-get install -y ldap-utils

# Test LDAPS connection (port 636)
ldapsearch -x -H ldaps://ldap.company.com:636 \
  -D "CN=temporal-service,OU=Service Accounts,DC=company,DC=com" \
  -w "YourStrongPassword123!" \
  -b "DC=company,DC=com" \
  "(objectClass=*)" dn

# Test LDAP connection (port 389)
ldapsearch -x -H ldap://ldap.company.com:389 \
  -D "CN=temporal-service,OU=Service Accounts,DC=company,DC=com" \
  -w "YourStrongPassword123!" \
  -b "DC=company,DC=com" \
  "(objectClass=*)" dn
```

#### Configure Firewall Rules

Ensure these ports are open from OpenShift to AD:
- **389/TCP** - LDAP (unencrypted)
- **636/TCP** - LDAPS (SSL/TLS encrypted) ← **Recommended**
- **3268/TCP** - Global Catalog LDAP (optional)
- **3269/TCP** - Global Catalog LDAPS (optional)

### Step 5: Create Kubernetes Secret

Store the AD service account password securely:

```bash
# Create secret with AD bind password
oc create secret generic temporal-ad-secret \
  --from-literal=ad-bind-password='YourStrongPassword123!' \
  -n temporal-production

# Verify secret
oc get secret temporal-ad-secret -n temporal-production -o yaml
```

### Step 6: Configure Temporal Helm Values

Create or update `values.yaml`:

```yaml
auth:
  enabled: true

  activeDirectory:
    enabled: true

    # LDAP Server Configuration
    server:
      # AD server hostname or IP
      host: ldap.company.com

      # Port: 389 for LDAP, 636 for LDAPS (recommended)
      port: 636

      # Use SSL/TLS (recommended for production)
      useSSL: true
      useTLS: true

      # Certificate verification (set to false for testing only)
      skipVerify: false

      # Service account credentials
      bindDN: "CN=temporal-service,OU=Service Accounts,DC=company,DC=com"
      bindPasswordSecret: temporal-ad-secret
      bindPasswordKey: ad-bind-password

    # User Search Configuration
    user:
      # Base DN where users are located
      baseDN: "OU=Users,DC=company,DC=com"

      # Filter for finding users (%s will be replaced with username)
      filter: "(sAMAccountName=%s)"

      # User attributes
      usernameAttribute: sAMAccountName
      emailAttribute: mail
      displayNameAttribute: displayName
      groupMembershipAttribute: memberOf

    # Group Search Configuration
    group:
      # Base DN where groups are located
      baseDN: "OU=Groups,DC=company,DC=com"

      # Filter for finding groups
      filter: "(objectClass=group)"

      # Group attributes
      nameAttribute: cn
      memberAttribute: member

    # Authorization - Map AD groups to Temporal roles
    authorization:
      enabled: true

      # Full administrative access
      adminGroups:
        - "CN=Temporal-Admins,OU=Groups,DC=company,DC=com"
        - "CN=Platform-Engineers,OU=Groups,DC=company,DC=com"

      # Workflow management access
      operatorGroups:
        - "CN=Temporal-Operators,OU=Groups,DC=company,DC=com"
        - "CN=DevOps-Team,OU=Groups,DC=company,DC=com"

      # Development access
      developerGroups:
        - "CN=Temporal-Developers,OU=Groups,DC=company,DC=com"
        - "CN=Engineering,OU=Groups,DC=company,DC=com"

      # Read-only access
      readOnlyGroups:
        - "CN=Temporal-Readers,OU=Groups,DC=company,DC=com"
        - "CN=Support-Team,OU=Groups,DC=company,DC=com"
```

### Step 7: Deploy/Update Temporal

```bash
# If first time deployment
helm install temporal ./temporal-helm \
  -f values.yaml \
  -n temporal-production

# If updating existing deployment
helm upgrade temporal ./temporal-helm \
  -f values.yaml \
  -n temporal-production
```

### Step 8: Verify Deployment

```bash
# Check pods
oc get pods -n temporal-production

# Check logs for LDAP initialization
oc logs -l app.kubernetes.io/component=frontend -n temporal-production | grep -i ldap

# Should see logs like:
# "LDAP authentication enabled"
# "Connected to LDAP server: ldap.company.com:636"
```

---

## Configuration Examples

### Example 1: Basic LDAP (Non-SSL)

**Use for**: Internal testing only, not recommended for production

```yaml
auth:
  activeDirectory:
    enabled: true
    server:
      host: ldap.company.local
      port: 389
      useSSL: false
      useTLS: false
      skipVerify: true  # Skip cert verification
      bindDN: "CN=temporal-service,OU=Services,DC=company,DC=local"
```

### Example 2: LDAPS with Certificate Validation

**Use for**: Production environments (recommended)

```yaml
auth:
  activeDirectory:
    enabled: true
    server:
      host: ldap.company.com
      port: 636
      useSSL: true
      useTLS: true
      skipVerify: false  # Validate certificates
      bindDN: "CN=temporal-service,OU=Service Accounts,DC=company,DC=com"

      # Optional: Specify custom CA certificate
      caSecret: ad-ca-cert
```

Create CA secret:
```bash
# Get AD CA certificate
# Export from AD or download from Certificate Authority

# Create secret
oc create secret generic ad-ca-cert \
  --from-file=ca.crt=/path/to/ad-ca.crt \
  -n temporal-production
```

### Example 3: Multiple AD Domains

If you have multiple AD domains or forests:

```yaml
auth:
  activeDirectory:
    enabled: true
    server:
      # Use Global Catalog for multi-domain
      host: gc.company.com
      port: 3269  # Global Catalog LDAPS port
      useSSL: true
      bindDN: "CN=temporal-service,OU=Services,DC=company,DC=com"

    user:
      # Search across entire forest
      baseDN: "DC=company,DC=com"
      filter: "(sAMAccountName=%s)"
```

### Example 4: Custom User Filter

Filter by specific organizational unit or user attributes:

```yaml
auth:
  activeDirectory:
    user:
      baseDN: "OU=Employees,OU=Users,DC=company,DC=com"

      # Only allow users with specific attribute
      filter: "(&(sAMAccountName=%s)(employeeType=FTE))"

      # Or only from specific department
      # filter: "(&(sAMAccountName=%s)(department=Engineering))"
```

### Example 5: Nested Group Support

Support for nested AD groups:

```yaml
auth:
  activeDirectory:
    user:
      # Use memberOf recursive filter
      groupMembershipAttribute: memberOf

    group:
      # Enable nested group resolution
      filter: "(objectClass=group)"

    authorization:
      adminGroups:
        # Parent group that contains other groups
        - "CN=Temporal-All-Admins,OU=Groups,DC=company,DC=com"
```

---

## Testing

### Test 1: Verify LDAP Connection

```bash
# From a pod in the same namespace
oc exec -it $(oc get pod -l app.kubernetes.io/component=frontend -o name | head -1) \
  -n temporal-production -- /bin/sh

# Inside pod, test LDAP query
# (requires ldapsearch tool)
```

### Test 2: Test User Authentication

Using Temporal CLI:

```bash
# Install Temporal CLI
# Download from: https://docs.temporal.io/cli

# Configure connection with auth
temporal operator namespace list \
  --address temporal-frontend.temporal-production.svc.cluster.local:7233 \
  --tls-cert-path /path/to/client.crt \
  --tls-key-path /path/to/client.key
```

### Test 3: Verify Group Membership

Check if user's groups are correctly identified:

```bash
# Query user information
ldapsearch -x -H ldaps://ldap.company.com:636 \
  -D "CN=temporal-service,OU=Service Accounts,DC=company,DC=com" \
  -w "password" \
  -b "OU=Users,DC=company,DC=com" \
  "(sAMAccountName=john.doe)" memberOf

# Should return all groups the user is member of
```

### Test 4: Web UI Login

1. Access Temporal Web UI via OpenShift route
2. Click "Login with Active Directory"
3. Enter credentials: `john.doe` / `password`
4. Should be redirected to dashboard
5. Verify permissions based on group membership

---

## Troubleshooting

### Issue 1: Cannot Connect to LDAP Server

**Symptoms:**
- Logs show "connection refused" or "connection timeout"
- Authentication always fails

**Diagnosis:**
```bash
# Test network connectivity
oc run nettest --image=busybox --rm -it --restart=Never -- sh
nc -zv ldap.company.com 636

# Test DNS resolution
nslookup ldap.company.com

# Check from frontend pod
oc exec -it <frontend-pod> -- nc -zv ldap.company.com 636
```

**Solutions:**
1. Verify firewall rules allow traffic
2. Check DNS resolution
3. Verify LDAP server is running
4. Check network policies in OpenShift

### Issue 2: Authentication Fails with Valid Credentials

**Symptoms:**
- Users can't login even with correct passwords
- Logs show "invalid credentials" or "bind failed"

**Diagnosis:**
```bash
# Check frontend logs
oc logs -l app.kubernetes.io/component=frontend | grep -i "ldap\|auth"

# Common error messages:
# - "LDAP bind failed" → Wrong bindDN or password
# - "User not found" → Wrong baseDN or filter
# - "Invalid credentials" → User password wrong or account locked
```

**Solutions:**

**Solution A: Wrong bindDN format**
```yaml
# Incorrect:
bindDN: "temporal-service@company.com"

# Correct:
bindDN: "CN=temporal-service,OU=Service Accounts,DC=company,DC=com"
```

**Solution B: Test bind manually**
```bash
ldapsearch -x -H ldaps://ldap.company.com:636 \
  -D "CN=temporal-service,OU=Service Accounts,DC=company,DC=com" \
  -w "password" \
  -b "DC=company,DC=com" \
  "(objectClass=*)"
```

**Solution C: Check user filter**
```yaml
# If users have different attribute
user:
  filter: "(userPrincipalName=%s@company.com)"  # Instead of sAMAccountName
```

### Issue 3: User Authenticates but Has No Permissions

**Symptoms:**
- Login successful
- Cannot view or perform any actions
- "Access Denied" errors

**Diagnosis:**
```bash
# Check user's group membership
ldapsearch -x -H ldaps://ldap.company.com:636 \
  -D "CN=temporal-service,OU=Service Accounts,DC=company,DC=com" \
  -w "password" \
  -b "OU=Users,DC=company,DC=com" \
  "(sAMAccountName=john.doe)" memberOf

# Output should include something like:
# memberOf: CN=Temporal-Developers,OU=Groups,DC=company,DC=com
```

**Solutions:**

1. **Verify group membership in AD**
   ```powershell
   Get-ADUser -Identity john.doe -Properties MemberOf | Select-Object -ExpandProperty MemberOf
   ```

2. **Check group DN format in config**
   ```yaml
   # Make sure DNs match exactly
   authorization:
     developerGroups:
       # Must match exactly including case
       - "CN=Temporal-Developers,OU=Groups,DC=company,DC=com"
   ```

3. **Enable debug logging**
   ```yaml
   server:
     config:
       log:
         level: debug
   ```

   Then check logs for group resolution:
   ```bash
   oc logs -l app.kubernetes.io/component=frontend | grep -i "group\|authz"
   ```

### Issue 4: SSL/TLS Certificate Errors

**Symptoms:**
- "certificate verification failed"
- "x509: certificate signed by unknown authority"

**Diagnosis:**
```bash
# Test SSL connection
openssl s_client -connect ldap.company.com:636 -showcerts

# Check if CA is trusted
oc exec -it <frontend-pod> -- cat /etc/ssl/certs/ca-certificates.crt | grep -i company
```

**Solutions:**

**Option 1: Add CA certificate**
```bash
# Get AD CA certificate
# Export from AD Certificate Authority

# Create ConfigMap with CA
oc create configmap ad-ca-cert \
  --from-file=ca.crt=/path/to/ad-ca.crt \
  -n temporal-production

# Update deployment to mount CA
# (requires custom deployment modification)
```

**Option 2: Skip verification (NOT recommended for production)**
```yaml
auth:
  activeDirectory:
    server:
      skipVerify: true  # Only for testing!
```

### Issue 5: Slow Authentication

**Symptoms:**
- Login takes 10+ seconds
- Timeouts during peak usage

**Solutions:**

1. **Enable connection pooling** (if supported by your LDAP client)

2. **Use Global Catalog for faster queries**
   ```yaml
   server:
     host: gc.company.com
     port: 3268  # or 3269 for LDAPS
   ```

3. **Optimize user filter**
   ```yaml
   user:
     # More specific filter = faster search
     baseDN: "OU=Temporal-Users,OU=Users,DC=company,DC=com"
     filter: "(&(sAMAccountName=%s)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"
     # Filters out disabled accounts
   ```

4. **Cache group memberships** (application-level caching)

### Issue 6: Special Characters in Password

**Symptoms:**
- Authentication fails only for passwords with special characters
- Works with simple passwords

**Solution:**
Ensure password is properly escaped in secret:

```bash
# If password contains special chars like: P@ssw0rd!$

# Create secret with single quotes to prevent shell interpretation
oc create secret generic temporal-ad-secret \
  --from-literal=ad-bind-password='P@ssw0rd!$' \
  -n temporal-production
```

---

## Best Practices

### Security

1. **Always use LDAPS (port 636)** instead of plain LDAP
2. **Enable certificate validation** (`skipVerify: false`)
3. **Use service account with minimal privileges** (read-only)
4. **Rotate service account password** regularly
5. **Use separate AD groups** specifically for Temporal (don't reuse existing groups)
6. **Enable audit logging** in AD for Temporal service account activity

### Performance

1. **Use specific base DNs** to reduce search scope
2. **Create efficient filters** to minimize returned results
3. **Consider using Global Catalog** for multi-domain environments
4. **Implement caching** at application level if possible
5. **Monitor LDAP query performance** and optimize as needed

### Operational

1. **Document your AD structure** and keep it updated
2. **Maintain a group naming convention** (e.g., `Temporal-*`)
3. **Test authentication changes** in dev environment first
4. **Have a rollback plan** for AD changes
5. **Monitor authentication failures** and alert on anomalies
6. **Keep service account credentials** in vault/secret manager

### Disaster Recovery

1. **Backup AD group memberships** regularly
2. **Document DN paths** for users and groups
3. **Have emergency admin access** that doesn't rely on AD
4. **Test failover scenarios** (AD server down, network issues)

---

## Alternative: ADFS/Azure AD

If your organization uses Active Directory Federation Services (ADFS) or Azure AD, you can use OIDC/SAML instead of LDAP.

### Azure AD (OIDC) Configuration

```yaml
auth:
  enabled: true

  # Disable LDAP
  activeDirectory:
    enabled: false

  # Enable OIDC
  oidc:
    enabled: true

    # Azure AD settings
    issuer: "https://login.microsoftonline.com/<tenant-id>/v2.0"

    # Client credentials (register app in Azure AD)
    clientId: "your-temporal-app-client-id"
    clientSecretKey: oidc-client-secret

    # Callback URL (must match Azure AD app registration)
    redirectURL: "https://temporal.apps.company.com/auth/callback"

    # Scopes
    scopes:
      - openid
      - profile
      - email
      - offline_access

    # Claims mapping
    claims:
      username: preferred_username
      email: email
      groups: groups  # Requires group claims in Azure AD
```

#### Azure AD Setup Steps

1. **Register Application in Azure AD**
   - Go to Azure Portal → Azure Active Directory → App registrations
   - New registration
   - Name: "Temporal Production"
   - Redirect URI: `https://temporal.apps.company.com/auth/callback`

2. **Configure API Permissions**
   - Add permissions: `User.Read`, `GroupMember.Read.All`
   - Grant admin consent

3. **Enable Group Claims**
   - Token configuration → Add groups claim
   - Select "Security groups"

4. **Create Client Secret**
   - Certificates & secrets → New client secret
   - Save the secret value

5. **Create Secret in OpenShift**
   ```bash
   oc create secret generic temporal-oidc-secret \
     --from-literal=client-secret='<azure-ad-client-secret>' \
     -n temporal-production
   ```

### ADFS (SAML) Configuration

For SAML-based authentication with ADFS, you'll need to:

1. Configure ADFS as Identity Provider
2. Register Temporal as Relying Party Trust
3. Configure claim rules
4. Update Temporal configuration

This is more complex and requires coordination with your ADFS administrators.

---

## Additional Resources

### Microsoft Active Directory
- [LDAP Query Basics](https://docs.microsoft.com/en-us/windows/win32/adsi/search-filter-syntax)
- [Common LDAP Filters](https://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx)

### Azure AD
- [Azure AD App Registration](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [Azure AD OIDC](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-protocols-oidc)

### Temporal
- [Temporal Security](https://docs.temporal.io/security)
- [Authorization and Claims](https://docs.temporal.io/security/authorization)

---

## Support

For issues or questions:
1. Check logs: `oc logs -l app.kubernetes.io/component=frontend`
2. Verify AD connectivity from pod
3. Test LDAP queries manually
4. Review this troubleshooting guide
5. Contact your IT/AD team for AD-specific issues

---

**Document Version**: 1.0
**Last Updated**: 2025-12-14
**Maintained By**: Platform Engineering Team
