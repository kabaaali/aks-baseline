# Implementation Checklist: Exact Files and Configurations

This document provides the **exact file names and locations** for implementing the complete AKS microservices architecture with ArgoCD GitOps deployment.

---

## Table of Contents
1. [Azure Infrastructure (Terraform/Bicep)](#azure-infrastructure-terraformbicep)
2. [Azure Networking & Firewall](#azure-networking--firewall)
3. [AKS Cluster Configuration](#aks-cluster-configuration)
4. [Azure Key Vault](#azure-key-vault)
5. [Git Repository Structure](#git-repository-structure)
6. [ArgoCD Installation & Configuration](#argocd-installation--configuration)
7. [Kubernetes Manifests](#kubernetes-manifests)
8. [Azure DevOps Pipelines](#azure-devops-pipelines)
9. [Monitoring & Observability](#monitoring--observability)
10. [Implementation Order](#implementation-order)

---

## Azure Infrastructure (Terraform/Bicep)

### Directory: `infrastructure/terraform/` or `infrastructure/bicep/`

#### Core Infrastructure Files

```
infrastructure/
├── terraform/                                    # OR bicep/
│   ├── main.tf                                  # Main Terraform configuration
│   ├── variables.tf                             # Input variables
│   ├── outputs.tf                               # Output values
│   ├── providers.tf                             # Provider configuration
│   ├── terraform.tfvars                         # Variable values (gitignored)
│   │
│   ├── modules/
│   │   ├── resource-group/
│   │   │   ├── main.tf                          # Resource group module
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   ├── vnet/
│   │   │   ├── main.tf                          # Virtual network module
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   ├── aks/
│   │   │   ├── main.tf                          # AKS cluster module
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   ├── key-vault/
│   │   │   ├── main.tf                          # Azure Key Vault module
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   ├── private-dns/
│   │   │   ├── main.tf                          # Private DNS zones
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   ├── apim/
│   │   │   ├── main.tf                          # Azure API Management
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   └── acr/
│   │       ├── main.tf                          # Azure Container Registry
│   │       ├── variables.tf
│   │       └── outputs.tf
│   │
│   └── environments/
│       ├── dev.tfvars                           # Dev environment variables
│       ├── staging.tfvars                       # Staging environment variables
│       └── prod.tfvars                          # Production environment variables
```

#### Specific Files to Create/Modify

**File: `infrastructure/terraform/main.tf`**
```hcl
# Main infrastructure orchestration
module "resource_group" { ... }
module "vnet" { ... }
module "aks" { ... }
module "key_vault" { ... }
module "private_dns" { ... }
module "apim" { ... }
module "acr" { ... }
```

**File: `infrastructure/terraform/modules/aks/main.tf`**
```hcl
# AKS automatic private cluster configuration
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  sku_tier            = "Standard"  # Automatic cluster
  
  private_cluster_enabled = true
  
  # Workload Identity
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  
  # Network configuration
  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    # ... additional network settings
  }
  
  # Add-ons
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }
}
```

---

## Azure Networking & Firewall

### Network Security Groups (NSGs)

**File: `infrastructure/terraform/modules/vnet/nsg-rules.tf`**
```hcl
# NSG for AKS subnet
resource "azurerm_network_security_group" "aks_subnet_nsg" {
  name                = "nsg-aks-subnet"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# NSG rules
resource "azurerm_network_security_rule" "allow_apim_to_aks" {
  name                        = "AllowAPIMtoAKS"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "10.100.2.0/24"  # APIM subnet
  destination_address_prefix  = "10.240.0.0/16"  # AKS subnet
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks_subnet_nsg.name
}
```

### Private DNS Zones

**File: `infrastructure/terraform/modules/private-dns/main.tf`**
```hcl
# Private DNS zone for internal services
resource "azurerm_private_dns_zone" "internal_local" {
  name                = "apps.internal.local"
  resource_group_name = var.resource_group_name
}

# A records for services
resource "azurerm_private_dns_a_record" "users_api" {
  name                = "users-api"
  zone_name           = azurerm_private_dns_zone.internal_local.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = ["10.240.0.10"]  # NGINX Ingress IP
}

resource "azurerm_private_dns_a_record" "orders_api" {
  name                = "orders-api"
  zone_name           = azurerm_private_dns_zone.internal_local.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = ["10.240.0.10"]
}

resource "azurerm_private_dns_a_record" "argocd" {
  name                = "argocd"
  zone_name           = azurerm_private_dns_zone.internal_local.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = ["10.240.0.10"]
}
```

### FortiGate Firewall Configuration

**File: `infrastructure/fortigate/policies.conf`** (or via FortiManager)
```
# Firewall policy: APIM to AKS
config firewall policy
    edit 100
        set name "APIM-to-AKS-HTTPS"
        set srcintf "apim-interface"
        set dstintf "aks-interface"
        set srcaddr "apim-subnet"
        set dstaddr "aks-nginx-ingress"
        set action accept
        set schedule "always"
        set service "HTTPS"
        set logtraffic all
    next
end
```

---

## AKS Cluster Configuration

### Post-Deployment AKS Configuration

**File: `aks-config/enable-addons.sh`**
```bash
#!/bin/bash
# Enable required AKS add-ons

RESOURCE_GROUP="rg-aks-prod"
CLUSTER_NAME="aks-prod"

# Enable Workload Identity
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-oidc-issuer \
  --enable-workload-identity

# Enable Azure Key Vault CSI Driver
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --addons azure-keyvault-secrets-provider \
  --enable-secret-rotation

# Enable monitoring
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --addons monitoring \
  --workspace-resource-id /subscriptions/.../workspaces/log-analytics-aks
```

---

## Azure Key Vault

### Key Vault Secrets Setup

**File: `scripts/setup-keyvault-secrets.sh`**
```bash
#!/bin/bash
# Populate Azure Key Vault with secrets

KEYVAULT_NAME="kv-aks-prod-secrets"

# Database connection strings
az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name users-api-db-connection \
  --value "Server=sqlserver-prod.database.windows.net;Database=usersdb;User ID=usersapi;Password=${DB_PASSWORD}"

az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name orders-api-db-connection \
  --value "Server=sqlserver-prod.database.windows.net;Database=ordersdb;User ID=ordersapi;Password=${DB_PASSWORD}"

# Redis connection strings
az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name redis-connection \
  --value "redis-prod.redis.cache.windows.net:6380,password=${REDIS_PASSWORD},ssl=True"

# API keys for inter-service communication
az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name orders-api-key \
  --value "${ORDERS_API_KEY}"
```

### Workload Identity Setup

**File: `scripts/setup-workload-identity.sh`**
```bash
#!/bin/bash
# Create and configure Workload Identity for each microservice

RESOURCE_GROUP="rg-aks-prod"
KEYVAULT_NAME="kv-aks-prod-secrets"
OIDC_ISSUER=$(az aks show --resource-group $RESOURCE_GROUP --name aks-prod --query "oidcIssuerProfile.issuerUrl" -o tsv)

# For each microservice
for SERVICE in users-api orders-api products-api; do
  # Create managed identity
  az identity create \
    --name id-${SERVICE}-workload \
    --resource-group $RESOURCE_GROUP
  
  CLIENT_ID=$(az identity show --name id-${SERVICE}-workload --resource-group $RESOURCE_GROUP --query clientId -o tsv)
  PRINCIPAL_ID=$(az identity show --name id-${SERVICE}-workload --resource-group $RESOURCE_GROUP --query principalId -o tsv)
  
  # Grant Key Vault access
  az role assignment create \
    --role "Key Vault Secrets User" \
    --assignee-object-id $PRINCIPAL_ID \
    --assignee-principal-type ServicePrincipal \
    --scope $(az keyvault show --name $KEYVAULT_NAME --query id -o tsv)
  
  # Create federated credential
  az identity federated-credential create \
    --name ${SERVICE}-federated-credential \
    --identity-name id-${SERVICE}-workload \
    --resource-group $RESOURCE_GROUP \
    --issuer $OIDC_ISSUER \
    --subject system:serviceaccount:${SERVICE}-ns:${SERVICE}-sa \
    --audience api://AzureADTokenExchange
  
  echo "Created Workload Identity for $SERVICE: $CLIENT_ID"
done
```

---

## Git Repository Structure

### Repository: `k8s-manifests`

**Complete directory structure to create:**

```
k8s-manifests/
├── README.md
├── .gitignore
│
├── argocd/
│   ├── install/
│   │   ├── argocd-namespace.yaml
│   │   ├── argocd-install.yaml
│   │   ├── argocd-cm.yaml
│   │   ├── argocd-rbac-cm.yaml
│   │   └── argocd-ingress.yaml
│   │
│   ├── projects/
│   │   ├── microservices-project.yaml
│   │   └── infrastructure-project.yaml
│   │
│   ├── applications/
│   │   ├── root-app.yaml
│   │   ├── users-api-dev.yaml
│   │   ├── users-api-staging.yaml
│   │   ├── users-api-prod.yaml
│   │   ├── orders-api-dev.yaml
│   │   ├── orders-api-staging.yaml
│   │   ├── orders-api-prod.yaml
│   │   ├── products-api-dev.yaml
│   │   ├── products-api-staging.yaml
│   │   └── products-api-prod.yaml
│   │
│   └── applicationsets/
│       └── microservices-appset.yaml
│
├── base/
│   ├── users-api/
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── serviceaccount.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   ├── secretproviderclass.yaml
│   │   ├── configmap.yaml
│   │   └── hpa.yaml
│   │
│   ├── orders-api/
│   │   └── (same structure as users-api)
│   │
│   └── products-api/
│       └── (same structure as users-api)
│
├── overlays/
│   ├── dev/
│   │   ├── users-api/
│   │   │   ├── kustomization.yaml
│   │   │   ├── deployment-patch.yaml
│   │   │   ├── configmap-patch.yaml
│   │   │   └── ingress-patch.yaml
│   │   ├── orders-api/
│   │   │   └── (same structure)
│   │   └── products-api/
│   │       └── (same structure)
│   │
│   ├── staging/
│   │   └── (same structure as dev)
│   │
│   └── prod/
│       └── (same structure as dev)
│
├── infrastructure/
│   ├── nginx-ingress/
│   │   ├── namespace.yaml
│   │   ├── helm-values.yaml
│   │   └── install.sh
│   │
│   ├── cert-manager/
│   │   ├── namespace.yaml
│   │   ├── helm-values.yaml
│   │   ├── cluster-issuer-letsencrypt.yaml
│   │   └── install.sh
│   │
│   └── istio/  (optional)
│       ├── istio-operator.yaml
│       ├── install.sh
│       └── configs/
│
└── scripts/
    ├── install-argocd.sh
    ├── create-new-microservice.sh
    ├── promote-to-prod.sh
    ├── sync-app.sh
    └── backup-argocd.sh
```

---

## ArgoCD Installation & Configuration

### Files to Create

**File: `argocd/install/argocd-namespace.yaml`**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
```

**File: `argocd/install/argocd-install.yaml`**
```yaml
# Download from: https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# Or use: kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**File: `argocd/install/argocd-cm.yaml`**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  timeout.reconciliation: "180s"
  application.resourceTrackingMethod: "annotation"
  url: "https://argocd.apps.internal.local"
```

**File: `argocd/install/argocd-rbac-cm.yaml`**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:devops, applications, *, */*, allow
    g, devops-team@example.com, role:devops
    g, developers@example.com, role:developer
```

**File: `argocd/install/argocd-ingress.yaml`**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  tls:
  - hosts:
    - argocd.apps.internal.local
    secretName: argocd-tls
  rules:
  - host: argocd.apps.internal.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
```

**File: `argocd/projects/microservices-project.yaml`**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: microservices
  namespace: argocd
spec:
  description: Microservices applications
  sourceRepos:
  - 'https://github.com/your-org/k8s-manifests.git'
  destinations:
  - namespace: '*-ns'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
```

**File: `argocd/applications/root-app.yaml`**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/k8s-manifests.git
    targetRevision: main
    path: argocd/applications
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## Kubernetes Manifests

### Base Manifests (Example: users-api)

**File: `base/users-api/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: users-ns
resources:
- namespace.yaml
- serviceaccount.yaml
- deployment.yaml
- service.yaml
- ingress.yaml
- secretproviderclass.yaml
- configmap.yaml
- hpa.yaml
commonLabels:
  app: users-api
  managed-by: argocd
```

**File: `base/users-api/namespace.yaml`**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: users-ns
  labels:
    name: users-ns
```

**File: `base/users-api/serviceaccount.yaml`**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: users-api-sa
  namespace: users-ns
  annotations:
    azure.workload.identity/client-id: "${WORKLOAD_IDENTITY_CLIENT_ID}"
    azure.workload.identity/tenant-id: "${AZURE_TENANT_ID}"
```

**File: `base/users-api/deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: users-api
  namespace: users-ns
spec:
  replicas: 3
  selector:
    matchLabels:
      app: users-api
  template:
    metadata:
      labels:
        app: users-api
        version: v1
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: users-api-sa
      containers:
      - name: users-api
        image: myregistry.azurecr.io/users-api:latest
        ports:
        - containerPort: 8080
        envFrom:
        - configMapRef:
            name: users-api-config
        env:
        - name: Database__ConnectionString
          valueFrom:
            secretKeyRef:
              name: users-api-kv-secrets
              key: database-connection
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        volumeMounts:
        - name: secrets-store
          mountPath: "/mnt/secrets-store"
          readOnly: true
      volumes:
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "users-api-secrets"
```

**File: `base/users-api/service.yaml`**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: users-api-service
  namespace: users-ns
spec:
  type: ClusterIP
  selector:
    app: users-api
  ports:
  - name: http
    port: 8080
    targetPort: 8080
```

**File: `base/users-api/ingress.yaml`**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: users-api-ingress
  namespace: users-ns
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - users-api.apps.internal.local
    secretName: users-api-tls
  rules:
  - host: users-api.apps.internal.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: users-api-service
            port:
              number: 8080
```

**File: `base/users-api/secretproviderclass.yaml`**
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: users-api-secrets
  namespace: users-ns
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    clientID: "${WORKLOAD_IDENTITY_CLIENT_ID}"
    keyvaultName: "kv-aks-prod-secrets"
    cloudName: "AzurePublicCloud"
    objects: |
      array:
        - |
          objectName: users-api-db-connection
          objectType: secret
    tenantId: "${AZURE_TENANT_ID}"
  secretObjects:
  - secretName: users-api-kv-secrets
    type: Opaque
    data:
    - objectName: users-api-db-connection
      key: database-connection
```

**File: `base/users-api/configmap.yaml`**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: users-api-config
  namespace: users-ns
data:
  ASPNETCORE_ENVIRONMENT: "Production"
  App__Name: "UsersAPIService"
  App__Version: "1.0.0"
  Logging__LogLevel__Default: "Information"
  Services__OrdersAPI__BaseUrl: "http://orders-api-service.orders-ns.svc.cluster.local:8080"
```

**File: `base/users-api/hpa.yaml`**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: users-api-hpa
  namespace: users-ns
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: users-api
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Environment Overlays

**File: `overlays/dev/users-api/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: users-ns-dev
bases:
- ../../../base/users-api
nameSuffix: -dev
images:
- name: myregistry.azurecr.io/users-api
  newTag: dev-latest
replicas:
- name: users-api
  count: 1
patches:
- path: deployment-patch.yaml
- path: configmap-patch.yaml
- path: ingress-patch.yaml
```

**File: `overlays/prod/users-api/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: users-ns-prod
bases:
- ../../../base/users-api
nameSuffix: -prod
images:
- name: myregistry.azurecr.io/users-api
  newTag: v1.2.3  # Specific version for prod
replicas:
- name: users-api
  count: 5
patches:
- path: deployment-patch.yaml
- path: configmap-patch.yaml
- path: ingress-patch.yaml
- path: hpa-patch.yaml
```

---

## Azure DevOps Pipelines

### Repository: Application Code (e.g., `users-api`)

**File: `azure-pipelines.yml`** (in application repo root)
```yaml
trigger:
  branches:
    include:
    - main
    - develop
  paths:
    exclude:
    - README.md
    - docs/*

variables:
  dockerRegistryServiceConnection: 'acr-connection'
  imageRepository: 'users-api'
  containerRegistry: 'myregistry.azurecr.io'
  dockerfilePath: '$(Build.SourcesDirectory)/Dockerfile'
  tag: '$(Build.BuildId)'
  
  # Environment-specific tags
  devTag: 'dev-$(Build.BuildId)'
  stagingTag: 'staging-$(Build.BuildId)'
  prodTag: 'v$(Build.BuildNumber)'

stages:
- stage: Build
  displayName: Build and Push Docker Image
  jobs:
  - job: Build
    displayName: Build
    pool:
      vmImage: 'ubuntu-latest'
    steps:
    - task: Docker@2
      displayName: Build and push image to ACR
      inputs:
        command: buildAndPush
        repository: $(imageRepository)
        dockerfile: $(dockerfilePath)
        containerRegistry: $(dockerRegistryServiceConnection)
        tags: |
          $(tag)
          latest

- stage: UpdateManifestDev
  displayName: Update K8s Manifest for Dev
  dependsOn: Build
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/develop'))
  jobs:
  - job: UpdateManifest
    displayName: Update Kustomization
    pool:
      vmImage: 'ubuntu-latest'
    steps:
    - checkout: git://YourProject/k8s-manifests@main
      persistCredentials: true
    
    - bash: |
        cd overlays/dev/users-api
        sed -i "s/newTag: .*/newTag: $(devTag)/" kustomization.yaml
        git config user.email "azuredevops@example.com"
        git config user.name "Azure DevOps"
        git add kustomization.yaml
        git commit -m "Update users-api dev image to $(devTag)"
        git push origin main
      displayName: 'Update dev image tag'

- stage: UpdateManifestProd
  displayName: Update K8s Manifest for Prod
  dependsOn: Build
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - job: UpdateManifest
    displayName: Update Kustomization (Manual Approval Required)
    pool:
      vmImage: 'ubuntu-latest'
    steps:
    - checkout: git://YourProject/k8s-manifests@main
      persistCredentials: true
    
    - bash: |
        cd overlays/prod/users-api
        sed -i "s/newTag: .*/newTag: $(prodTag)/" kustomization.yaml
        git config user.email "azuredevops@example.com"
        git config user.name "Azure DevOps"
        git add kustomization.yaml
        git commit -m "Update users-api prod image to $(prodTag)"
        git push origin main
      displayName: 'Update prod image tag'
```

### Pipeline for Infrastructure

**File: `infrastructure-pipeline.yml`**
```yaml
trigger:
  branches:
    include:
    - main
  paths:
    include:
    - infrastructure/terraform/*

variables:
  terraformVersion: '1.6.0'
  backendServiceConnection: 'azure-service-connection'
  backendResourceGroup: 'rg-terraform-state'
  backendStorageAccount: 'sttfstate'
  backendContainerName: 'tfstate'

stages:
- stage: Plan
  displayName: Terraform Plan
  jobs:
  - job: TerraformPlan
    pool:
      vmImage: 'ubuntu-latest'
    steps:
    - task: TerraformInstaller@0
      inputs:
        terraformVersion: $(terraformVersion)
    
    - task: TerraformTaskV4@4
      displayName: Terraform Init
      inputs:
        provider: 'azurerm'
        command: 'init'
        workingDirectory: '$(System.DefaultWorkingDirectory)/infrastructure/terraform'
        backendServiceArm: $(backendServiceConnection)
        backendAzureRmResourceGroupName: $(backendResourceGroup)
        backendAzureRmStorageAccountName: $(backendStorageAccount)
        backendAzureRmContainerName: $(backendContainerName)
        backendAzureRmKey: 'terraform.tfstate'
    
    - task: TerraformTaskV4@4
      displayName: Terraform Plan
      inputs:
        provider: 'azurerm'
        command: 'plan'
        workingDirectory: '$(System.DefaultWorkingDirectory)/infrastructure/terraform'
        environmentServiceNameAzureRM: $(backendServiceConnection)
        commandOptions: '-var-file=environments/prod.tfvars -out=tfplan'

- stage: Apply
  displayName: Terraform Apply
  dependsOn: Plan
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - deployment: TerraformApply
    environment: 'production'
    pool:
      vmImage: 'ubuntu-latest'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: TerraformTaskV4@4
            displayName: Terraform Apply
            inputs:
              provider: 'azurerm'
              command: 'apply'
              workingDirectory: '$(System.DefaultWorkingDirectory)/infrastructure/terraform'
              environmentServiceNameAzureRM: $(backendServiceConnection)
              commandOptions: 'tfplan'
```

---

## Monitoring & Observability

### Prometheus & Grafana

**File: `infrastructure/monitoring/prometheus-values.yaml`**
```yaml
# Helm values for kube-prometheus-stack
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi

grafana:
  adminPassword: ${GRAFANA_ADMIN_PASSWORD}
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
    - grafana.apps.internal.local
```

**File: `infrastructure/monitoring/install-monitoring.sh`**
```bash
#!/bin/bash
# Install Prometheus and Grafana

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values prometheus-values.yaml
```

### Application Insights

**File: `infrastructure/terraform/modules/app-insights/main.tf`**
```hcl
resource "azurerm_application_insights" "aks_monitoring" {
  name                = "appi-aks-prod"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "other"
  
  tags = var.tags
}

output "instrumentation_key" {
  value     = azurerm_application_insights.aks_monitoring.instrumentation_key
  sensitive = true
}
```

---

## Implementation Order

### Phase 1: Azure Infrastructure (Week 1)

1. **Create Terraform/Bicep files**
   - [ ] `infrastructure/terraform/main.tf`
   - [ ] `infrastructure/terraform/modules/resource-group/main.tf`
   - [ ] `infrastructure/terraform/modules/vnet/main.tf`
   - [ ] `infrastructure/terraform/modules/aks/main.tf`
   - [ ] `infrastructure/terraform/modules/key-vault/main.tf`
   - [ ] `infrastructure/terraform/modules/private-dns/main.tf`
   - [ ] `infrastructure/terraform/modules/acr/main.tf`

2. **Deploy infrastructure**
   ```bash
   cd infrastructure/terraform
   terraform init
   terraform plan -var-file=environments/prod.tfvars
   terraform apply -var-file=environments/prod.tfvars
   ```

3. **Configure networking**
   - [ ] Update NSG rules in `infrastructure/terraform/modules/vnet/nsg-rules.tf`
   - [ ] Configure FortiGate policies in `infrastructure/fortigate/policies.conf`
   - [ ] Create Private DNS records

### Phase 2: AKS Configuration (Week 2)

1. **Enable AKS add-ons**
   ```bash
   ./aks-config/enable-addons.sh
   ```

2. **Setup Workload Identity**
   ```bash
   ./scripts/setup-workload-identity.sh
   ```

3. **Populate Key Vault**
   ```bash
   ./scripts/setup-keyvault-secrets.sh
   ```

4. **Install infrastructure components**
   ```bash
   ./infrastructure/nginx-ingress/install.sh
   ./infrastructure/cert-manager/install.sh
   ```

### Phase 3: ArgoCD Setup (Week 2)

1. **Create Git repository structure**
   ```bash
   mkdir -p k8s-manifests/{argocd,base,overlays,infrastructure,scripts}
   # Create all files listed in Git Repository Structure section
   ```

2. **Install ArgoCD**
   ```bash
   ./scripts/install-argocd.sh
   kubectl apply -f argocd/install/argocd-cm.yaml
   kubectl apply -f argocd/install/argocd-rbac-cm.yaml
   kubectl apply -f argocd/install/argocd-ingress.yaml
   ```

3. **Create ArgoCD projects and applications**
   ```bash
   kubectl apply -f argocd/projects/microservices-project.yaml
   kubectl apply -f argocd/applications/root-app.yaml
   ```

### Phase 4: Application Deployment (Week 3)

1. **Create base manifests for each microservice**
   - [ ] `base/users-api/` (all 8 files)
   - [ ] `base/orders-api/` (all 8 files)
   - [ ] `base/products-api/` (all 8 files)

2. **Create environment overlays**
   - [ ] `overlays/dev/users-api/` (4 files)
   - [ ] `overlays/staging/users-api/` (4 files)
   - [ ] `overlays/prod/users-api/` (5 files)
   - [ ] Repeat for orders-api and products-api

3. **Create ArgoCD applications**
   - [ ] `argocd/applications/users-api-dev.yaml`
   - [ ] `argocd/applications/users-api-staging.yaml`
   - [ ] `argocd/applications/users-api-prod.yaml`
   - [ ] Repeat for other services

4. **Deploy applications**
   ```bash
   git add .
   git commit -m "Add microservice manifests"
   git push origin main
   # ArgoCD will automatically sync
   ```

### Phase 5: CI/CD Pipelines (Week 3-4)

1. **Create Azure DevOps pipelines**
   - [ ] `users-api/azure-pipelines.yml`
   - [ ] `orders-api/azure-pipelines.yml`
   - [ ] `products-api/azure-pipelines.yml`
   - [ ] `infrastructure-pipeline.yml`

2. **Configure service connections in Azure DevOps**
   - [ ] ACR service connection
   - [ ] Azure subscription service connection
   - [ ] Git repository connection

3. **Test CI/CD flow**
   - Make code change → Push to Git → Pipeline builds → Updates manifest → ArgoCD syncs

### Phase 6: Monitoring & Operations (Week 4)

1. **Install monitoring stack**
   ```bash
   ./infrastructure/monitoring/install-monitoring.sh
   ```

2. **Configure alerts and dashboards**
   - [ ] Import Grafana dashboards
   - [ ] Configure Prometheus alerts
   - [ ] Setup ArgoCD notifications

3. **Setup backup procedures**
   ```bash
   ./scripts/backup-argocd.sh
   ```

---

## Quick Reference: Critical Files Checklist

### Must Create First (Foundation)
- [ ] `infrastructure/terraform/main.tf`
- [ ] `infrastructure/terraform/modules/aks/main.tf`
- [ ] `infrastructure/terraform/modules/key-vault/main.tf`
- [ ] `scripts/setup-workload-identity.sh`
- [ ] `scripts/setup-keyvault-secrets.sh`

### ArgoCD Core Files
- [ ] `argocd/install/argocd-namespace.yaml`
- [ ] `argocd/install/argocd-cm.yaml`
- [ ] `argocd/install/argocd-rbac-cm.yaml`
- [ ] `argocd/projects/microservices-project.yaml`
- [ ] `argocd/applications/root-app.yaml`

### Per Microservice (Repeat for each service)
- [ ] `base/{service}/kustomization.yaml`
- [ ] `base/{service}/deployment.yaml`
- [ ] `base/{service}/service.yaml`
- [ ] `base/{service}/ingress.yaml`
- [ ] `base/{service}/secretproviderclass.yaml`
- [ ] `overlays/{env}/{service}/kustomization.yaml`
- [ ] `argocd/applications/{service}-{env}.yaml`

### CI/CD
- [ ] `{service-repo}/azure-pipelines.yml`
- [ ] `infrastructure-pipeline.yml`

---

## Summary

This checklist provides **exact file names and locations** for implementing the complete architecture. Follow the implementation order to ensure dependencies are met. Each file listed contains the specific configuration needed for that component.

**Total files to create: ~150+ files** across infrastructure, Kubernetes manifests, ArgoCD configs, and pipelines.

Start with Phase 1 (Infrastructure) and progress sequentially through each phase.
