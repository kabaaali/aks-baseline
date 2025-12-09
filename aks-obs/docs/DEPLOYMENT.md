# AKS Observability Deployment Guide

This guide provides step-by-step instructions for deploying the complete AKS observability solution using Azure Managed Prometheus and Grafana.

## Prerequisites

### Required Tools

- **Azure CLI** (version 2.50.0 or later)
  ```bash
  az --version
  az login
  ```

- **Terraform** (version 1.5.0 or later)
  ```bash
  terraform --version
  ```

- **kubectl** (configured for your AKS cluster)
  ```bash
  kubectl version --client
  kubectl config current-context
  ```

### Required Permissions

Your Azure account needs:
- **Contributor** role on the subscription or resource group
- **Monitoring Metrics Publisher** role for data collection
- **Grafana Admin** role for dashboard management

### Existing Resources

- **AKS Automatic cluster** (already deployed and running)
- Resource group containing the AKS cluster

## Step 1: Prepare Configuration

1. **Navigate to the terraform directory**
   ```bash
   cd /Users/rekhasunil/Documents/Sunil/poc-antigravity/aks-obs/terraform
   ```

2. **Create your configuration file**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit terraform.tfvars with your values**
   ```bash
   # Open in your preferred editor
   vim terraform.tfvars
   # or
   code terraform.tfvars
   ```

   **Required values to update:**
   ```hcl
   # Your existing AKS cluster details
   aks_cluster_name        = "your-aks-cluster-name"
   aks_resource_group_name = "your-aks-resource-group"
   
   # Observability resource configuration
   resource_group_name     = "rg-aks-observability"
   location                = "australiaeast"  # Match your AKS region
   
   # Optional: Customize resource names
   prometheus_workspace_name = "amw-aks-prometheus"
   grafana_name             = "grafana-aks-observability"
   ```

## Step 2: Deploy Infrastructure with Terraform

1. **Initialize Terraform**
   ```bash
   terraform init
   ```
   
   This downloads required providers (azurerm, azapi).

2. **Validate configuration**
   ```bash
   terraform validate
   ```
   
   Ensure no syntax errors.

3. **Preview changes**
   ```bash
   terraform plan
   ```
   
   Review the resources that will be created:
   - Resource Group
   - Azure Monitor Workspace (Prometheus)
   - Azure Managed Grafana
   - Data Collection Endpoint
   - Data Collection Rule
   - Role Assignments

4. **Apply the configuration**
   ```bash
   terraform apply
   ```
   
   Type `yes` when prompted.
   
   **Deployment time:** 5-10 minutes

5. **Save the outputs**
   ```bash
   terraform output
   ```
   
   Important outputs:
   - `grafana_endpoint` - URL to access Grafana
   - `prometheus_query_endpoint` - Prometheus query endpoint
   - `next_steps` - Instructions for completing setup

## Step 3: Verify Data Collection

1. **Check data collection rule association**
   ```bash
   az monitor data-collection rule association list \
     --resource-group <your-aks-resource-group> \
     --resource-name <your-aks-cluster-name> \
     --resource-type Microsoft.ContainerService/managedClusters
   ```

2. **Verify metrics are flowing** (wait 2-3 minutes after deployment)
   ```bash
   # Get Prometheus workspace ID from Terraform output
   WORKSPACE_ID=$(terraform output -raw prometheus_workspace_id)
   
   # Query for basic metrics
   az monitor metrics list \
     --resource $WORKSPACE_ID \
     --metric-names "kube_node_status_condition"
   ```

## Step 4: Deploy Prometheus Rules

1. **Get AKS credentials**
   ```bash
   az aks get-credentials \
     --resource-group <your-aks-resource-group> \
     --name <your-aks-cluster-name>
   ```

2. **Deploy alert rules**
   ```bash
   kubectl apply -f ../prometheus/alert-rules.yaml
   ```
   
   Verify:
   ```bash
   kubectl get configmap -n kube-system aks-prometheus-alert-rules
   ```

3. **Deploy recording rules**
   ```bash
   kubectl apply -f ../prometheus/recording-rules.yaml
   ```
   
   Verify:
   ```bash
   kubectl get configmap -n kube-system aks-prometheus-recording-rules
   ```

> [!NOTE]
> For AKS Automatic clusters, Prometheus rule evaluation is handled by Azure Monitor. The ConfigMaps are used for rule definitions that Azure Monitor will evaluate.

## Step 5: Import Grafana Dashboards

1. **Access Grafana**
   ```bash
   # Get Grafana URL from Terraform output
   terraform output grafana_endpoint
   ```
   
   Open the URL in your browser.

2. **Authenticate to Grafana**
   - Use your Azure AD credentials
   - Ensure you have Grafana Admin role

3. **Import dashboards**
   
   For each dashboard JSON file in `../dashboards/`:
   
   a. Click **Dashboards** → **Import**
   
   b. Click **Upload JSON file**
   
   c. Select dashboard file:
      - `layer1-cluster-capacity-health.json`
      - `layer2-node-infrastructure.json`
      - `layer3-workload-pod-health.json`
      - `layer4-network-storage.json`
   
   d. Select the Prometheus data source (should be auto-configured)
   
   e. Click **Import**

4. **Verify dashboards are working**
   - Check that panels are showing data
   - If no data appears, wait 5 minutes for metrics to populate
   - Verify time range is set to "Last 1 hour"

## Step 6: Configure Alert Notifications (Optional)

1. **In Grafana, navigate to Alerting → Contact points**

2. **Add a contact point**
   - Name: `ops-team-email`
   - Type: Email
   - Addresses: Your team email

3. **Create notification policy**
   - Match alerts by label (e.g., `severity=critical`)
   - Route to appropriate contact point

4. **Test notifications**
   - Use "Test" button in contact point configuration
   - Verify email delivery

## Step 7: Validation

### Check Cluster Metrics

1. **Open Layer 1 Dashboard** (Cluster Capacity & Health)
   - Verify CPU/Memory commit gauges show values
   - Check node count is accurate
   - Ensure no pods are pending

2. **Open Layer 2 Dashboard** (Node & Infrastructure)
   - Verify node pressure table is populated
   - Check disk I/O graphs show activity
   - Confirm disk space gauges display correctly

3. **Open Layer 3 Dashboard** (Workload & Pod Health)
   - Check restart rate heatmap
   - Verify deployment replica counts
   - Ensure pod status is accurate

4. **Open Layer 4 Dashboard** (Network & Storage)
   - Verify network throughput graphs
   - Check PV usage if you have persistent volumes
   - Confirm CoreDNS latency is being tracked

### Test Alerts

1. **View active alerts in Grafana**
   - Navigate to **Alerting → Alert rules**
   - Check that rules are loaded

2. **Trigger a test alert** (optional)
   ```bash
   # Create a pod that will crash loop
   kubectl run test-crashloop --image=busybox --restart=Always -- sh -c "exit 1"
   
   # Wait 5 minutes and check for PodCrashLooping alert
   
   # Clean up
   kubectl delete pod test-crashloop
   ```

## Troubleshooting Deployment

### Terraform Errors

**Error: Insufficient permissions**
```
Solution: Ensure your Azure account has Contributor role on the subscription
```

**Error: Resource already exists**
```
Solution: Either import existing resource or change resource names in terraform.tfvars
```

### No Metrics in Grafana

**Symptoms:** Dashboards show "No data"

**Solutions:**
1. Wait 5-10 minutes for initial metrics to populate
2. Verify data collection rule is associated:
   ```bash
   kubectl get pods -n kube-system | grep ama-metrics
   ```
3. Check Azure Monitor Agent logs:
   ```bash
   kubectl logs -n kube-system -l rsName=ama-metrics
   ```

### Alert Rules Not Loading

**Symptoms:** No alerts visible in Grafana

**Solutions:**
1. Verify ConfigMaps are created:
   ```bash
   kubectl get configmap -n kube-system | grep prometheus
   ```
2. Check Azure Monitor workspace is receiving rules
3. Wait 5 minutes for rule synchronization

## Next Steps

After successful deployment:

1. **Customize thresholds** - See [CONFIGURATION.md](CONFIGURATION.md)
2. **Add custom dashboards** - Create additional panels for your workloads
3. **Set up alert routing** - Configure notification channels
4. **Enable long-term retention** - Configure Prometheus data retention policies
5. **Monitor costs** - Track Azure Monitor ingestion and Grafana usage

## Cleanup

To remove all deployed resources:

```bash
cd /Users/rekhasunil/Documents/Sunil/poc-antigravity/aks-obs/terraform
terraform destroy
```

Type `yes` when prompted.

> [!WARNING]
> This will delete all monitoring data and dashboards. Export any important dashboards before destroying.

---

For configuration details and metric explanations, see [CONFIGURATION.md](CONFIGURATION.md).

For common issues and solutions, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
