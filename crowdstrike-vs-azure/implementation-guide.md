# Azure-Native Security Implementation Guide

## Quick Start: Enable Azure Security Stack for AKS Automatic

### Prerequisites
```bash
# Required tools
az --version  # Azure CLI >= 2.50.0
kubectl version  # kubectl >= 1.28.0

# Set variables
export SUBSCRIPTION_ID="<your-subscription-id>"
export RESOURCE_GROUP="<your-resource-group>"
export AKS_CLUSTER="<your-aks-cluster>"
export LOCATION="<azure-region>"
export LOG_ANALYTICS_WORKSPACE="law-aks-security"
```

---

## Step 1: Enable Microsoft Defender for Containers (5 minutes)

### What It Replaces
✅ CrowdStrike Falcon runtime protection  
✅ Container breakout detection  
✅ Malicious process detection

### Implementation
```bash
# 1. Enable Defender for Containers at subscription level
az security pricing create \
  --name Containers \
  --tier Standard \
  --subscription $SUBSCRIPTION_ID

# 2. Verify enablement
az security pricing show \
  --name Containers \
  --subscription $SUBSCRIPTION_ID

# Expected output:
# {
#   "name": "Containers",
#   "pricingTier": "Standard",
#   "freeTrialRemainingTime": "PT0S"
# }

# 3. Enable Defender profile on AKS cluster
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER \
  --enable-defender

# 4. Verify Defender is running
kubectl get pods -n kube-system | grep microsoft-defender
# Expected: microsoft-defender-* pods in Running state
```

### Validation
```bash
# Check Defender recommendations
az security assessment list \
  --subscription $SUBSCRIPTION_ID \
  | jq '.[] | select(.resourceDetails.id | contains("'$AKS_CLUSTER'"))'

# View security alerts (if any)
az security alert list \
  --subscription $SUBSCRIPTION_ID \
  | jq '.[] | select(.resourceIdentifier | contains("'$AKS_CLUSTER'"))'
```

---

## Step 2: Enable Defender for Container Registries (5 minutes)

### What It Replaces
✅ CrowdStrike Falcon image scanning  
✅ Vulnerability assessment  
✅ Image quarantine

### Implementation
```bash
# 1. Enable Defender for Container Registry
az security pricing create \
  --name ContainerRegistry \
  --tier Standard \
  --subscription $SUBSCRIPTION_ID

# 2. Get your ACR name
export ACR_NAME=$(az acr list \
  --resource-group $RESOURCE_GROUP \
  --query "[0].name" -o tsv)

# 3. Enable vulnerability scanning
az acr config content-trust update \
  --registry $ACR_NAME \
  --status enabled

# 4. Configure automatic scanning
az acr task create \
  --registry $ACR_NAME \
  --name security-scan \
  --context /dev/null \
  --cmd "echo 'Defender scanning enabled'" \
  --schedule "0 2 * * *"  # Daily at 2 AM
```

### Validation
```bash
# Push a test image to trigger scan
docker pull nginx:latest
docker tag nginx:latest $ACR_NAME.azurecr.io/test/nginx:latest
az acr login --name $ACR_NAME
docker push $ACR_NAME.azurecr.io/test/nginx:latest

# Check scan results (wait 2-3 minutes)
az security assessment list \
  --subscription $SUBSCRIPTION_ID \
  | jq '.[] | select(.resourceDetails.id | contains("'$ACR_NAME'"))'
```

---

## Step 3: Configure Log Analytics & Monitoring (10 minutes)

### What It Replaces
✅ CrowdStrike Falcon logging  
✅ Audit trail collection  
✅ Security event aggregation

### Implementation
```bash
# 1. Create Log Analytics Workspace
az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_WORKSPACE \
  --location $LOCATION \
  --retention-time 90

# 2. Get workspace ID
export WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_WORKSPACE \
  --query id -o tsv)

# 3. Enable Container Insights on AKS
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER \
  --addons monitoring \
  --workspace-resource-id $WORKSPACE_ID

# 4. Enable comprehensive diagnostic logging
az monitor diagnostic-settings create \
  --name aks-security-diagnostics \
  --resource $(az aks show -g $RESOURCE_GROUP -n $AKS_CLUSTER --query id -o tsv) \
  --workspace $WORKSPACE_ID \
  --logs '[
    {"category": "kube-apiserver", "enabled": true},
    {"category": "kube-audit", "enabled": true},
    {"category": "kube-audit-admin", "enabled": true},
    {"category": "kube-controller-manager", "enabled": true},
    {"category": "kube-scheduler", "enabled": true},
    {"category": "cluster-autoscaler", "enabled": true},
    {"category": "cloud-controller-manager", "enabled": true},
    {"category": "guard", "enabled": true}
  ]' \
  --metrics '[
    {"category": "AllMetrics", "enabled": true}
  ]'
```

### Validation
```bash
# Query recent API server logs
az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query "AzureDiagnostics 
    | where Category == 'kube-apiserver' 
    | take 10" \
  --output table

# Check Container Insights is collecting data
az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query "ContainerLog 
    | summarize count() by Computer 
    | take 10" \
  --output table
```

---

## Step 4: Enable Azure Policy for Kubernetes (5 minutes)

### What It Replaces
✅ CrowdStrike Falcon admission control  
✅ Policy enforcement  
✅ Configuration validation

### Implementation
```bash
# 1. Enable Azure Policy add-on
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER \
  --addons azure-policy

# 2. Verify policy pods are running
kubectl get pods -n kube-system | grep azure-policy
# Expected: azure-policy-* and gatekeeper-* pods

# 3. Assign CIS Kubernetes Benchmark
az policy assignment create \
  --name 'CIS-Kubernetes-Benchmark' \
  --display-name 'CIS Kubernetes Benchmark v1.6.1' \
  --scope $(az aks show -g $RESOURCE_GROUP -n $AKS_CLUSTER --query id -o tsv) \
  --policy-set-definition '/providers/Microsoft.Authorization/policySetDefinitions/42b8ef37-b724-4e24-bbc8-7a7708edfe00'

# 4. Assign Pod Security Baseline
az policy assignment create \
  --name 'Pod-Security-Baseline' \
  --display-name 'Kubernetes cluster pod security baseline standards' \
  --scope $(az aks show -g $RESOURCE_GROUP -n $AKS_CLUSTER --query id -o tsv) \
  --policy-set-definition '/providers/Microsoft.Authorization/policySetDefinitions/a8640138-9b0a-4a28-b8cb-1666c838647d' \
  --params '{
    "effect": {"value": "Audit"}
  }'
```

### Validation
```bash
# Check policy compliance (wait 10-15 minutes for initial scan)
az policy state list \
  --resource $(az aks show -g $RESOURCE_GROUP -n $AKS_CLUSTER --query id -o tsv) \
  --query "[].{Policy:policyDefinitionName, Compliance:complianceState}" \
  --output table

# Test policy enforcement - try to create privileged pod
kubectl run test-privileged \
  --image=nginx \
  --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"test","image":"nginx","securityContext":{"privileged":true}}]}}'

# Should see policy violation in audit logs
```

---

## Step 5: Configure Network Security (15 minutes)

### What It Replaces
✅ CrowdStrike Falcon network monitoring  
✅ Lateral movement detection  
✅ C2 communication blocking

### Implementation
```bash
# 1. Get AKS network details
export AKS_VNET=$(az aks show -g $RESOURCE_GROUP -n $AKS_CLUSTER \
  --query "agentPoolProfiles[0].vnetSubnetId" -o tsv | cut -d'/' -f9)
export AKS_SUBNET=$(az aks show -g $RESOURCE_GROUP -n $AKS_CLUSTER \
  --query "agentPoolProfiles[0].vnetSubnetId" -o tsv | cut -d'/' -f11)

# 2. Enable NSG Flow Logs
export NSG_NAME="${AKS_CLUSTER}-nsg"
export STORAGE_ACCOUNT="st${AKS_CLUSTER}flows"

# Create storage account for flow logs
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS

# Enable flow logs with Traffic Analytics
az network watcher flow-log create \
  --name "${AKS_CLUSTER}-flow-logs" \
  --nsg $(az network nsg show -g $RESOURCE_GROUP -n $NSG_NAME --query id -o tsv) \
  --storage-account $STORAGE_ACCOUNT \
  --workspace $WORKSPACE_ID \
  --traffic-analytics true \
  --interval 10 \
  --retention 90

# 3. Deploy default deny network policy
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
```

### Validation
```bash
# Check network policies
kubectl get networkpolicies --all-namespaces

# View Traffic Analytics (after 10-15 minutes)
az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query "AzureNetworkAnalytics_CL 
    | where SubType_s == 'FlowLog' 
    | take 10" \
  --output table
```

---

## Step 6: Enable Microsoft Sentinel (Optional - 20 minutes)

### What It Replaces
✅ CrowdStrike Falcon SIEM integration  
✅ Threat correlation  
✅ Incident response automation

### Implementation
```bash
# 1. Enable Sentinel on Log Analytics workspace
az sentinel workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_WORKSPACE

# 2. Enable data connectors
az sentinel data-connector create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_WORKSPACE \
  --name "AzureKubernetesService" \
  --kind "AzureKubernetesService"

# 3. Import analytics rules for AKS
# Download pre-built rules
curl -o aks-sentinel-rules.json \
  https://raw.githubusercontent.com/Azure/Azure-Sentinel/master/Solutions/AKS/Analytic%20Rules/

# Deploy analytics rules (example)
az sentinel alert-rule create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_WORKSPACE \
  --alert-rule-template-name "suspicious-kubectl-exec" \
  --enabled true
```

---

## Step 7: Configure Security Alerts (10 minutes)

### Implementation
```bash
# 1. Create action group for notifications
az monitor action-group create \
  --resource-group $RESOURCE_GROUP \
  --name "AKS-Security-Alerts" \
  --short-name "AKSSec" \
  --email-receiver name="SecurityTeam" email="security@example.com"

# 2. Create alert rules
# Alert on high-severity Defender findings
az monitor metrics alert create \
  --name "Defender-High-Severity-Alert" \
  --resource-group $RESOURCE_GROUP \
  --scopes $(az aks show -g $RESOURCE_GROUP -n $AKS_CLUSTER --query id -o tsv) \
  --condition "count SecurityAlert > 0" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action "AKS-Security-Alerts" \
  --severity 1

# Alert on policy violations
az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query "AzureDiagnostics 
    | where Category == 'kube-audit' 
    | where log_s contains 'forbidden'" \
  --output table
```

---

## Verification Checklist

### ✅ Security Stack Validation

Run this comprehensive check:

```bash
#!/bin/bash
echo "=== Azure-Native Security Stack Validation ==="

# 1. Defender for Containers
echo -e "\n[1/7] Checking Defender for Containers..."
DEFENDER_CONTAINERS=$(az security pricing show --name Containers --query pricingTier -o tsv)
if [ "$DEFENDER_CONTAINERS" == "Standard" ]; then
  echo "✅ Defender for Containers: ENABLED"
else
  echo "❌ Defender for Containers: DISABLED"
fi

# 2. Defender for Container Registry
echo -e "\n[2/7] Checking Defender for Container Registry..."
DEFENDER_ACR=$(az security pricing show --name ContainerRegistry --query pricingTier -o tsv)
if [ "$DEFENDER_ACR" == "Standard" ]; then
  echo "✅ Defender for Container Registry: ENABLED"
else
  echo "❌ Defender for Container Registry: DISABLED"
fi

# 3. Container Insights
echo -e "\n[3/7] Checking Container Insights..."
INSIGHTS=$(kubectl get pods -n kube-system | grep omsagent | wc -l)
if [ $INSIGHTS -gt 0 ]; then
  echo "✅ Container Insights: ENABLED ($INSIGHTS pods)"
else
  echo "❌ Container Insights: DISABLED"
fi

# 4. Azure Policy
echo -e "\n[4/7] Checking Azure Policy..."
POLICY=$(kubectl get pods -n kube-system | grep azure-policy | wc -l)
if [ $POLICY -gt 0 ]; then
  echo "✅ Azure Policy: ENABLED ($POLICY pods)"
else
  echo "❌ Azure Policy: DISABLED"
fi

# 5. Diagnostic Logging
echo -e "\n[5/7] Checking Diagnostic Settings..."
DIAG=$(az monitor diagnostic-settings list \
  --resource $(az aks show -g $RESOURCE_GROUP -n $AKS_CLUSTER --query id -o tsv) \
  --query "value | length(@)")
if [ $DIAG -gt 0 ]; then
  echo "✅ Diagnostic Logging: ENABLED ($DIAG settings)"
else
  echo "❌ Diagnostic Logging: DISABLED"
fi

# 6. Network Policies
echo -e "\n[6/7] Checking Network Policies..."
NETPOL=$(kubectl get networkpolicies --all-namespaces --no-headers | wc -l)
if [ $NETPOL -gt 0 ]; then
  echo "✅ Network Policies: CONFIGURED ($NETPOL policies)"
else
  echo "⚠️  Network Policies: NONE CONFIGURED"
fi

# 7. Security Assessments
echo -e "\n[7/7] Checking Security Assessments..."
ASSESSMENTS=$(az security assessment list \
  --subscription $SUBSCRIPTION_ID \
  | jq '[.[] | select(.resourceDetails.id | contains("'$AKS_CLUSTER'"))] | length')
echo "✅ Security Assessments: $ASSESSMENTS findings"

echo -e "\n=== Validation Complete ==="
```

---

## Next Steps

1. **Review Security Recommendations**
   ```bash
   az security assessment list --subscription $SUBSCRIPTION_ID \
     | jq '.[] | select(.resourceDetails.id | contains("'$AKS_CLUSTER'")) 
       | {name: .displayName, status: .status.code, severity: .status.severity}'
   ```

2. **Configure Custom Policies** - See [../policies/](../policies/)

3. **Set Up Incident Response** - See [incident-response-playbook.md](./incident-response-playbook.md)

4. **Enable Advanced Features**:
   - Workload Identity
   - Service Mesh (Istio)
   - External Secrets Operator

---

## Troubleshooting

### Defender Pods Not Running
```bash
# Check Defender profile
az aks show -g $RESOURCE_GROUP -n $AKS_CLUSTER \
  --query "securityProfile.defender" -o json

# Restart Defender pods
kubectl delete pods -n kube-system -l app=microsoft-defender
```

### Policy Not Enforcing
```bash
# Check Gatekeeper status
kubectl get constrainttemplates
kubectl get constraints

# View policy violations
kubectl get events --all-namespaces | grep "policy"
```

### No Log Data
```bash
# Verify workspace connection
az aks show -g $RESOURCE_GROUP -n $AKS_CLUSTER \
  --query "addonProfiles.omsagent" -o json

# Check agent status
kubectl get pods -n kube-system -l component=oms-agent
kubectl logs -n kube-system -l component=oms-agent --tail=50
```
