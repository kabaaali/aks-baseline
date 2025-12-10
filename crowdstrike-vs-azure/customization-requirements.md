# AKS Automatic: Customization Requirements for Implementation Teams

## Overview

This document provides a detailed breakdown of customization and configuration work required from implementation teams when deploying AKS Automatic clusters with Azure-native security.

---

## 📊 Effort Estimation Summary

### Quick Overview

| Configuration Category | Effort Level | Time Required | Frequency | Skill Level |
|------------------------|-------------|---------------|-----------|-------------|
| **Initial Cluster Setup** | 🟢 Low | 30 minutes | One-time | Junior |
| **Security Enablement** | 🟢 Low | 20 minutes | One-time | Junior |
| **Network Configuration** | 🟡 Medium | 2-4 hours | One-time | Intermediate |
| **Identity & RBAC** | 🟡 Medium | 4-8 hours | One-time | Intermediate |
| **Policy Configuration** | 🟡 Medium | 4-6 hours | One-time | Intermediate |
| **Monitoring Setup** | 🟢 Low | 1-2 hours | One-time | Junior |
| **Application Onboarding** | 🟡 Medium | 2-4 hours per app | Per app | Intermediate |
| **Ongoing Maintenance** | 🟢 Low | 2-4 hours/month | Monthly | Junior |

**Total Initial Setup**: 15-25 hours  
**Ongoing Maintenance**: 2-4 hours/month

---

## 1. Initial Cluster Setup

### 🟢 Effort Level: LOW
**Time**: 30 minutes  
**Skill Level**: Junior DevOps Engineer  
**Frequency**: One-time per cluster

### Required Customization

#### 1.1 Basic Cluster Configuration

**Decision Points**:
- Cluster name and resource group
- Azure region selection
- Kubernetes version (or use default)
- Node pool sizing (or use defaults)

**Configuration File**:
```bash
# cluster-config.sh
export SUBSCRIPTION_ID="<your-subscription>"
export RESOURCE_GROUP="rg-aks-prod"
export CLUSTER_NAME="aks-prod-001"
export LOCATION="eastus"
export K8S_VERSION="1.28"  # Optional, defaults to latest stable

# Create cluster (AKS Automatic handles most settings)
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --location $LOCATION \
  --tier automatic \
  --kubernetes-version $K8S_VERSION \
  --generate-ssh-keys
```

**Customization Required**:
- ✅ Naming conventions (5 minutes)
- ✅ Region selection (5 minutes)
- ✅ Resource group structure (10 minutes)
- ⚠️ Node pool sizing (optional, 10 minutes)

**Total Time**: 30 minutes

---

## 2. Security Enablement

### 🟢 Effort Level: LOW
**Time**: 20 minutes  
**Skill Level**: Junior DevOps Engineer  
**Frequency**: One-time per cluster

### Required Customization

#### 2.1 Enable Microsoft Defender

**No Customization Needed** - Just enable:
```bash
# Enable Defender for Containers
az security pricing create \
  --name Containers \
  --tier Standard \
  --subscription $SUBSCRIPTION_ID

# Enable Defender for Container Registry
az security pricing create \
  --name ContainerRegistry \
  --tier Standard \
  --subscription $SUBSCRIPTION_ID
```

**Time**: 5 minutes

#### 2.2 Enable Azure Policy

**No Customization Needed** - Just enable:
```bash
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --addons azure-policy
```

**Time**: 5 minutes

#### 2.3 Configure Diagnostic Settings

**Minimal Customization** - Choose log categories:
```bash
# Create Log Analytics workspace
az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name law-aks-prod \
  --location $LOCATION

# Enable diagnostic logging
az monitor diagnostic-settings create \
  --name aks-diagnostics \
  --resource $(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv) \
  --workspace $(az monitor log-analytics workspace show -g $RESOURCE_GROUP -n law-aks-prod --query id -o tsv) \
  --logs '[
    {"category": "kube-apiserver", "enabled": true},
    {"category": "kube-audit", "enabled": true},
    {"category": "kube-controller-manager", "enabled": true}
  ]'
```

**Customization Required**:
- ✅ Log retention period (default: 30 days)
- ✅ Log categories to enable (recommended: all)

**Time**: 10 minutes

**Total Time**: 20 minutes

---

## 3. Network Configuration

### 🟡 Effort Level: MEDIUM
**Time**: 2-4 hours  
**Skill Level**: Intermediate Network Engineer  
**Frequency**: One-time per cluster

### Required Customization

#### 3.1 VNet and Subnet Design

**Customization Required**:
```bash
# Design decisions needed:
# - VNet address space
# - Subnet sizing
# - Service CIDR
# - DNS service IP

# Example configuration
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name vnet-aks-prod \
  --address-prefixes 10.0.0.0/16 \
  --subnet-name snet-aks-nodes \
  --subnet-prefixes 10.0.1.0/24

# Additional subnets
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name vnet-aks-prod \
  --name snet-aks-pods \
  --address-prefixes 10.0.2.0/23

az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name vnet-aks-prod \
  --name snet-private-endpoints \
  --address-prefixes 10.0.4.0/27
```

**Decision Points**:
- ✅ IP address planning (1 hour)
- ✅ Subnet segmentation (30 minutes)
- ✅ Future growth planning (30 minutes)

**Time**: 2 hours

#### 3.2 Network Policies

**Customization Required**: Per application
```yaml
# Example: Default deny policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# Example: Allow specific traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

**Customization Required**:
- ✅ Application communication patterns (1-2 hours)
- ✅ Network policy definitions (1-2 hours)
- ✅ Testing and validation (1 hour)

**Time**: 2-4 hours per environment

#### 3.3 Azure Firewall (Optional)

**Customization Required**: If egress filtering needed
```bash
# Create Azure Firewall
az network firewall create \
  --resource-group $RESOURCE_GROUP \
  --name afw-aks-prod \
  --location $LOCATION

# Configure application rules
az network firewall application-rule create \
  --collection-name "AKS-Required" \
  --firewall-name afw-aks-prod \
  --name "Allow-AKS-Dependencies" \
  --protocols Https=443 \
  --resource-group $RESOURCE_GROUP \
  --target-fqdns \
    "*.hcp.${LOCATION}.azmk8s.io" \
    "mcr.microsoft.com" \
    "*.data.mcr.microsoft.com" \
  --source-addresses "10.0.0.0/16" \
  --priority 100 \
  --action Allow
```

**Decision Points**:
- ✅ Egress requirements (1 hour)
- ✅ Allowed destinations (1 hour)
- ✅ Rule configuration (1-2 hours)

**Time**: 3-4 hours (if required)

**Total Network Configuration Time**: 2-4 hours (basic) or 5-8 hours (with firewall)

---

## 4. Identity & RBAC Configuration

### 🟡 Effort Level: MEDIUM
**Time**: 4-8 hours  
**Skill Level**: Intermediate Security Engineer  
**Frequency**: One-time + updates per team/user

### Required Customization

#### 4.1 Azure AD Groups

**Customization Required**:
```bash
# Create Azure AD groups for different roles
az ad group create \
  --display-name "AKS-Prod-Admins" \
  --mail-nickname "aks-prod-admins"

az ad group create \
  --display-name "AKS-Prod-Developers" \
  --mail-nickname "aks-prod-developers"

az ad group create \
  --display-name "AKS-Prod-Viewers" \
  --mail-nickname "aks-prod-viewers"
```

**Decision Points**:
- ✅ Organizational structure mapping (2 hours)
- ✅ Role definitions (1 hour)
- ✅ Group creation (1 hour)

**Time**: 4 hours

#### 4.2 Azure RBAC Assignments

**Customization Required**:
```bash
# Assign Azure RBAC roles
az role assignment create \
  --assignee-object-id $(az ad group show -g "AKS-Prod-Admins" --query id -o tsv) \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope $(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv)

az role assignment create \
  --assignee-object-id $(az ad group show -g "AKS-Prod-Developers" --query id -o tsv) \
  --role "Azure Kubernetes Service RBAC Writer" \
  --scope $(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv)
```

**Time**: 2 hours

#### 4.3 Kubernetes RBAC

**Customization Required**: Per namespace/team
```yaml
# Example: Developer role in namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: team-alpha
rules:
- apiGroups: ["", "apps", "batch"]
  resources: ["pods", "deployments", "jobs", "services"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: team-alpha
subjects:
- kind: Group
  name: "AKS-Prod-Developers"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

**Decision Points**:
- ✅ Namespace strategy (1 hour)
- ✅ Role definitions per team (2 hours)
- ✅ Testing access (1 hour)

**Time**: 4 hours

#### 4.4 Workload Identity (Per Application)

**Customization Required**: Per application needing Azure access
```bash
# Create managed identity
az identity create \
  --resource-group $RESOURCE_GROUP \
  --name id-app-backend

# Configure federated credential
az identity federated-credential create \
  --name "kubernetes-federated-credential" \
  --identity-name id-app-backend \
  --resource-group $RESOURCE_GROUP \
  --issuer $(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query "oidcIssuerProfile.issuerUrl" -o tsv) \
  --subject "system:serviceaccount:production:backend-sa" \
  --audience "api://AzureADTokenExchange"

# Grant permissions to Azure resources
az role assignment create \
  --assignee $(az identity show -g $RESOURCE_GROUP -n id-app-backend --query principalId -o tsv) \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/mystorageaccount"
```

**Time**: 30 minutes per application

**Total Identity Configuration Time**: 4-8 hours initial + 30 min per app

---

## 5. Policy Configuration

### 🟡 Effort Level: MEDIUM
**Time**: 4-6 hours  
**Skill Level**: Intermediate Security Engineer  
**Frequency**: One-time + updates per requirement

### Required Customization

#### 5.1 Assign Built-in Policies

**Minimal Customization**:
```bash
# Assign CIS Kubernetes Benchmark
az policy assignment create \
  --name 'CIS-Kubernetes-Benchmark' \
  --display-name 'CIS Kubernetes Benchmark v1.6.1' \
  --scope $(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv) \
  --policy-set-definition '/providers/Microsoft.Authorization/policySetDefinitions/42b8ef37-b724-4e24-bbc8-7a7708edfe00' \
  --params '{
    "effect": {"value": "Audit"}
  }'
```

**Decision Points**:
- ✅ Which compliance frameworks to enforce (1 hour)
- ✅ Audit vs. Deny mode (1 hour)
- ✅ Policy parameters (1 hour)

**Time**: 3 hours

#### 5.2 Custom Policies (If Needed)

**Customization Required**: Per organizational requirement
```json
{
  "policyRule": {
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.ContainerService/managedClusters/pods"
        },
        {
          "field": "Microsoft.ContainerService/managedClusters/pods/containers[*].image",
          "notContains": "myregistry.azurecr.io"
        }
      ]
    },
    "then": {
      "effect": "deny"
    }
  }
}
```

**Time**: 1-3 hours per custom policy

**Total Policy Configuration Time**: 4-6 hours

---

## 6. Monitoring Setup

### 🟢 Effort Level: LOW
**Time**: 1-2 hours  
**Skill Level**: Junior DevOps Engineer  
**Frequency**: One-time

### Required Customization

#### 6.1 Enable Container Insights

**Minimal Customization**:
```bash
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --addons monitoring \
  --workspace-resource-id $(az monitor log-analytics workspace show -g $RESOURCE_GROUP -n law-aks-prod --query id -o tsv)
```

**Time**: 10 minutes

#### 6.2 Configure Alerts

**Customization Required**:
```bash
# Create action group
az monitor action-group create \
  --resource-group $RESOURCE_GROUP \
  --name "AKS-Alerts" \
  --short-name "AKSAlert" \
  --email-receiver name="DevOps" email="devops@example.com"

# Create alert rule
az monitor metrics alert create \
  --name "High-CPU-Usage" \
  --resource-group $RESOURCE_GROUP \
  --scopes $(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv) \
  --condition "avg node_cpu_usage_percentage > 80" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action "AKS-Alerts"
```

**Decision Points**:
- ✅ Alert thresholds (30 minutes)
- ✅ Notification channels (30 minutes)
- ✅ Alert rules (30 minutes)

**Time**: 1-2 hours

**Total Monitoring Setup Time**: 1-2 hours

---

## 7. Application Onboarding

### 🟡 Effort Level: MEDIUM
**Time**: 2-4 hours per application  
**Skill Level**: Intermediate DevOps Engineer  
**Frequency**: Per application

### Required Customization

#### 7.1 Namespace Configuration

**Per Application**:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: app-backend
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted

---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: app-backend-quota
  namespace: app-backend
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
```

**Time**: 30 minutes per app

#### 7.2 Network Policies

**Per Application**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-backend-policy
  namespace: app-backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: app-frontend
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: app-database
    ports:
    - protocol: TCP
      port: 5432
```

**Time**: 1 hour per app

#### 7.3 Workload Identity Setup

**Per Application** (if Azure access needed):
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: app-backend
  annotations:
    azure.workload.identity/client-id: "<managed-identity-client-id>"
    azure.workload.identity/tenant-id: "<tenant-id>"
```

**Time**: 30 minutes per app

#### 7.4 Deployment Configuration

**Per Application**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: app-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: backend-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: backend
        image: myregistry.azurecr.io/backend:v1.0.0
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

**Time**: 1-2 hours per app

**Total Application Onboarding Time**: 2-4 hours per application

---

## 8. Ongoing Maintenance

### 🟢 Effort Level: LOW
**Time**: 2-4 hours/month  
**Skill Level**: Junior DevOps Engineer  
**Frequency**: Monthly

### Required Activities

#### 8.1 Review Security Recommendations

**Monthly Task**:
```bash
# Review Defender recommendations
az security assessment list \
  --subscription $SUBSCRIPTION_ID \
  | jq '.[] | select(.resourceDetails.id | contains("'$CLUSTER_NAME'"))'
```

**Time**: 1 hour/month

#### 8.2 Review Policy Compliance

**Monthly Task**:
```bash
# Check policy compliance
az policy state list \
  --resource $(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv) \
  --query "[?complianceState=='NonCompliant']"
```

**Time**: 1 hour/month

#### 8.3 Review and Update RBAC

**Quarterly Task**:
- Review user access
- Remove stale accounts
- Update role assignments

**Time**: 2 hours/quarter

#### 8.4 Update Network Policies

**As Needed**:
- New application deployments
- Application communication changes

**Time**: 1 hour per change

**Total Ongoing Maintenance**: 2-4 hours/month

---

## 📊 Total Effort Summary

### Initial Setup (One-Time)

| Phase | Effort | Time | Skill Level |
|-------|--------|------|-------------|
| Cluster Setup | 🟢 Low | 30 min | Junior |
| Security Enablement | 🟢 Low | 20 min | Junior |
| Network Configuration | 🟡 Medium | 2-4 hours | Intermediate |
| Identity & RBAC | 🟡 Medium | 4-8 hours | Intermediate |
| Policy Configuration | 🟡 Medium | 4-6 hours | Intermediate |
| Monitoring Setup | 🟢 Low | 1-2 hours | Junior |
| **Total Initial Setup** | | **12-21 hours** | |

### Per Application

| Task | Effort | Time | Skill Level |
|------|--------|------|-------------|
| Namespace Setup | 🟢 Low | 30 min | Junior |
| Network Policies | 🟡 Medium | 1 hour | Intermediate |
| Workload Identity | 🟢 Low | 30 min | Junior |
| Deployment Config | 🟡 Medium | 1-2 hours | Intermediate |
| **Total Per App** | | **2-4 hours** | |

### Ongoing Maintenance

| Task | Frequency | Time | Skill Level |
|------|-----------|------|-------------|
| Security Review | Monthly | 1 hour | Junior |
| Policy Compliance | Monthly | 1 hour | Junior |
| RBAC Review | Quarterly | 2 hours | Intermediate |
| **Total Monthly** | | **2-4 hours** | |

---

## 🆚 Comparison: AKS Automatic vs. CrowdStrike Falcon

### Implementation Effort

| Phase | AKS Automatic | CrowdStrike Falcon |
|-------|---------------|-------------------|
| **Initial Setup** | 12-21 hours | 40-80 hours |
| **Per Application** | 2-4 hours | 4-6 hours |
| **Monthly Maintenance** | 2-4 hours | 10-15 hours |
| **Skill Level Required** | Junior-Intermediate | Intermediate-Senior |
| **Complexity** | Low-Medium | High |

**Effort Savings**: 60-70% reduction with AKS Automatic

---

## 🎯 Recommendations

### Minimum Viable Security Configuration

**Time**: ~4 hours  
**Covers**: 90% of security requirements

1. ✅ Enable Defender (5 min)
2. ✅ Enable Azure Policy (5 min)
3. ✅ Enable Container Insights (10 min)
4. ✅ Configure basic RBAC (2 hours)
5. ✅ Assign CIS policies (1 hour)
6. ✅ Set up basic monitoring (30 min)

### Recommended Full Configuration

**Time**: ~15 hours  
**Covers**: 100% of security requirements

1. All minimum viable items
2. ✅ Network policies (2-4 hours)
3. ✅ Workload Identity setup (2 hours)
4. ✅ Custom policies (2-4 hours)
5. ✅ Advanced monitoring (2 hours)

---

## 📚 Related Documentation

- [Out-of-the-Box Features](./out-of-the-box-features.md) - What's automatic
- [Implementation Guide](./implementation-guide.md) - Step-by-step instructions
- [Quick Reference](./QUICK_REFERENCE.md) - Executive summary
