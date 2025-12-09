# AKS Observability Troubleshooting Guide

This guide covers common issues you may encounter when deploying and operating the AKS observability solution.

## Table of Contents

- [Deployment Issues](#deployment-issues)
- [Metrics Not Appearing](#metrics-not-appearing)
- [Dashboard Issues](#dashboard-issues)
- [Alert Issues](#alert-issues)
- [Performance Issues](#performance-issues)
- [Data Collection Issues](#data-collection-issues)

---

## Deployment Issues

### Terraform: Insufficient Permissions

**Symptom:**
```
Error: Authorization failed for resource
```

**Solution:**
1. Verify your Azure account has required roles:
   ```bash
   az role assignment list --assignee $(az account show --query user.name -o tsv)
   ```

2. Required roles:
   - Contributor on subscription or resource group
   - Monitoring Metrics Publisher

3. Assign missing roles:
   ```bash
   az role assignment create \
     --assignee <your-email> \
     --role "Contributor" \
     --scope /subscriptions/<subscription-id>
   ```

### Terraform: Resource Already Exists

**Symptom:**
```
Error: A resource with the ID already exists
```

**Solutions:**

**Option 1: Import existing resource**
```bash
terraform import azurerm_resource_group.observability /subscriptions/<sub-id>/resourceGroups/<rg-name>
```

**Option 2: Change resource names**
Edit `terraform.tfvars`:
```hcl
grafana_name = "grafana-aks-observability-v2"
```

**Option 3: Destroy and recreate**
```bash
az group delete --name rg-aks-observability
terraform apply
```

### Terraform: Provider Version Conflict

**Symptom:**
```
Error: Failed to query available provider packages
```

**Solution:**
```bash
rm -rf .terraform .terraform.lock.hcl
terraform init -upgrade
```

### AKS Cluster Not Found

**Symptom:**
```
Error: kubernetes_cluster "aks" (Resource Group "rg-aks"): was not found
```

**Solution:**
1. Verify cluster exists:
   ```bash
   az aks list --output table
   ```

2. Update `terraform.tfvars` with correct values:
   ```hcl
   aks_cluster_name        = "actual-cluster-name"
   aks_resource_group_name = "actual-resource-group"
   ```

---

## Metrics Not Appearing

### No Data in Grafana Dashboards

**Symptom:** All dashboard panels show "No data"

**Diagnosis Steps:**

1. **Check data collection endpoint**
   ```bash
   az monitor data-collection endpoint list \
     --resource-group rg-aks-observability \
     --output table
   ```

2. **Verify data collection rule association**
   ```bash
   az monitor data-collection rule association list \
     --resource <aks-cluster-resource-id> \
     --output table
   ```

3. **Check Azure Monitor Agent pods**
   ```bash
   kubectl get pods -n kube-system | grep ama-metrics
   ```
   
   Should show pods like:
   ```
   ama-metrics-xxxxx   2/2   Running
   ama-metrics-yyyyy   2/2   Running
   ```

4. **Check agent logs**
   ```bash
   kubectl logs -n kube-system -l rsName=ama-metrics --tail=50
   ```
   
   Look for errors like:
   - Authentication failures
   - Network connectivity issues
   - Configuration errors

**Solutions:**

**If agents are not running:**
```bash
# Restart the daemonset
kubectl rollout restart daemonset ama-metrics -n kube-system
```

**If authentication fails:**
```bash
# Verify managed identity has correct permissions
az role assignment create \
  --assignee <aks-managed-identity-client-id> \
  --role "Monitoring Metrics Publisher" \
  --scope <prometheus-workspace-id>
```

**If still no data after 10 minutes:**
```bash
# Re-apply data collection rule association
cd terraform
terraform taint azurerm_monitor_data_collection_rule_association.aks_prometheus
terraform apply
```

### Specific Metrics Missing

**Symptom:** Some metrics appear, others don't

**Common Missing Metrics:**

**kube-state-metrics not available:**
```bash
# Check if kube-state-metrics is deployed
kubectl get deployment -n kube-system kube-state-metrics

# If not found, deploy it
kubectl apply -f https://github.com/kubernetes/kube-state-metrics/releases/latest/download/kube-state-metrics-standard.yaml
```

**node-exporter metrics missing:**
```bash
# For AKS Automatic, node metrics should be collected by Azure Monitor Agent
# Verify ama-metrics-node pods are running
kubectl get pods -n kube-system -l component=ama-metrics-node
```

**CoreDNS metrics missing:**
```bash
# Check CoreDNS is exposing metrics
kubectl get svc -n kube-system kube-dns -o yaml | grep -A 5 metrics

# Verify metrics endpoint
kubectl port-forward -n kube-system svc/kube-dns 9153:9153
curl localhost:9153/metrics
```

### Metrics Delayed

**Symptom:** Metrics appear but are 5-10 minutes old

**Expected Behavior:**
- Scrape interval: 30 seconds
- Ingestion delay: 1-2 minutes
- Total delay: 2-3 minutes

**If delay > 5 minutes:**

1. **Check Azure Monitor Workspace ingestion**
   ```bash
   az monitor metrics list \
     --resource <prometheus-workspace-id> \
     --metric-names "IngestedSamples" \
     --start-time $(date -u -d '10 minutes ago' '+%Y-%m-%dT%H:%M:%SZ') \
     --interval PT1M
   ```

2. **Check for throttling**
   ```bash
   kubectl logs -n kube-system -l rsName=ama-metrics | grep -i throttle
   ```

3. **Verify network connectivity**
   ```bash
   # From a pod in the cluster
   kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
     curl -v <data-collection-endpoint-url>
   ```

---

## Dashboard Issues

### Dashboard Import Fails

**Symptom:**
```
Error: Dashboard validation failed
```

**Solutions:**

1. **Check JSON syntax**
   ```bash
   cat dashboards/layer1-cluster-capacity-health.json | jq .
   ```

2. **Verify data source exists**
   - In Grafana, go to Configuration → Data sources
   - Ensure Prometheus data source is configured
   - Test connection

3. **Import with correct data source**
   - During import, select the correct Prometheus data source
   - If multiple exist, choose the Azure Monitor Workspace

### Panels Show "Error" or "N/A"

**Symptom:** Panel displays error message instead of data

**Common Errors:**

**"Bad Gateway"**
- Prometheus workspace is unreachable
- Check network connectivity
- Verify Grafana has permissions

**"Invalid PromQL"**
- Query syntax error
- Check query in Prometheus directly
- Verify metric names are correct

**"No data points"**
- Metric doesn't exist
- Check metric is being scraped
- Verify time range includes data

**Debugging:**

1. **Test query in Grafana Explore**
   - Go to Explore
   - Select Prometheus data source
   - Run the query manually
   - Check for errors

2. **Verify metric exists**
   ```promql
   # In Grafana Explore, search for metric
   {__name__=~"kube_.*"}
   ```

3. **Check time range**
   - Ensure dashboard time range has data
   - Try "Last 1 hour" or "Last 6 hours"

### Dashboard Variables Not Working

**Symptom:** Namespace filter or other variables show no options

**Solution:**

1. **Check variable query**
   - Edit dashboard
   - Settings → Variables
   - Check query syntax

2. **Verify data source**
   - Ensure variable uses correct data source
   - Test query in Explore

3. **Refresh variable**
   - Click refresh icon next to variable
   - Or reload dashboard

---

## Alert Issues

### Alerts Not Firing

**Symptom:** Expected alerts don't trigger

**Diagnosis:**

1. **Verify alert rules are loaded**
   ```bash
   kubectl get configmap -n kube-system aks-prometheus-alert-rules -o yaml
   ```

2. **Check Azure Monitor for rule evaluation**
   ```bash
   az monitor metrics alert list \
     --resource-group rg-aks-observability \
     --output table
   ```

3. **Manually evaluate alert expression**
   - In Grafana Explore, run the alert PromQL
   - Verify it returns expected value

**Common Issues:**

**Alert expression never true:**
```promql
# Check if metric exists and has expected values
kube_pod_status_phase{phase="Pending"}
```

**Alert duration too long:**
```yaml
# Reduce 'for' duration for testing
for: 1m  # Instead of 5m
```

**Alert labels don't match routing:**
- Check alert labels match notification policy
- Verify contact points are configured

### Too Many Alerts (Alert Fatigue)

**Symptom:** Constant alerts, many false positives

**Solutions:**

1. **Increase thresholds**
   ```yaml
   # In prometheus/alert-rules.yaml
   expr: ... > 90  # Instead of 80
   ```

2. **Increase duration**
   ```yaml
   for: 10m  # Instead of 5m
   ```

3. **Add filters**
   ```yaml
   # Exclude system namespaces
   expr: ... {namespace!~"kube-system|kube-public"}
   ```

4. **Use severity levels**
   ```yaml
   labels:
     severity: warning  # Not critical
   ```

### Alerts Not Routing to Contact Points

**Symptom:** Alerts fire but no notifications received

**Diagnosis:**

1. **Check notification policy**
   - Grafana → Alerting → Notification policies
   - Verify labels match alert labels

2. **Test contact point**
   - Grafana → Alerting → Contact points
   - Click "Test" button
   - Verify email/webhook receives test

3. **Check alert labels**
   ```yaml
   # Alert must have labels that match policy
   labels:
     severity: critical
     team: platform
   ```

**Solution:**

Create catch-all notification policy:
- Match: `.*` (all alerts)
- Contact point: Default
- Then create specific policies for subsets

---

## Performance Issues

### Grafana Slow to Load Dashboards

**Symptom:** Dashboards take >10 seconds to load

**Causes:**
- Too many panels
- Complex queries
- Large time ranges

**Solutions:**

1. **Use recording rules**
   - Pre-compute expensive queries
   - Already configured in `prometheus/recording-rules.yaml`

2. **Reduce time range**
   - Use "Last 1 hour" instead of "Last 24 hours"
   - Add time range selector to dashboard

3. **Optimize queries**
   ```promql
   # Instead of this (slow):
   sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace, pod, container)
   
   # Use recording rule (fast):
   workload:container_cpu_usage:namespace_pod_container
   ```

4. **Limit series**
   ```promql
   # Add topk to limit results
   topk(10, sum by (namespace) (...))
   ```

### High Azure Monitor Costs

**Symptom:** Unexpected high ingestion costs

**Diagnosis:**

1. **Check ingestion volume**
   ```bash
   az monitor metrics list \
     --resource <prometheus-workspace-id> \
     --metric-names "IngestedSamples" \
     --aggregation Total \
     --interval PT1H
   ```

2. **Identify high-cardinality metrics**
   ```promql
   # In Grafana Explore
   topk(20, count by (__name__) ({__name__=~".+"}))
   ```

**Solutions:**

1. **Reduce scrape frequency**
   - Edit recording rules interval from 30s to 60s

2. **Drop unnecessary metrics**
   - Configure metric relabeling in data collection rule

3. **Limit label cardinality**
   - Avoid labels with many unique values
   - Use label_replace to normalize

---

## Data Collection Issues

### Azure Monitor Agent Pods Crashing

**Symptom:**
```bash
kubectl get pods -n kube-system | grep ama-metrics
ama-metrics-xxxxx   0/2   CrashLoopBackOff
```

**Diagnosis:**
```bash
kubectl logs -n kube-system ama-metrics-xxxxx -c prometheus-collector
kubectl describe pod -n kube-system ama-metrics-xxxxx
```

**Common Causes:**

**Insufficient resources:**
```yaml
# Increase resources in daemonset
resources:
  requests:
    memory: "512Mi"
    cpu: "200m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

**Configuration error:**
```bash
# Check configmap
kubectl get configmap -n kube-system ama-metrics-prometheus-config -o yaml
```

**Network issues:**
```bash
# Test connectivity to data collection endpoint
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v <data-collection-endpoint-url>
```

### Metrics Scrape Failures

**Symptom:** Logs show "scrape failed" errors

**Diagnosis:**
```bash
kubectl logs -n kube-system -l rsName=ama-metrics | grep -i "scrape failed"
```

**Solutions:**

1. **Verify target is reachable**
   ```bash
   kubectl get endpoints -n kube-system kube-dns
   ```

2. **Check service monitor configuration**
   ```bash
   kubectl get servicemonitor -A
   ```

3. **Verify metrics endpoint**
   ```bash
   kubectl port-forward -n <namespace> <pod> 9090:9090
   curl localhost:9090/metrics
   ```

---

## Getting Help

If you've tried the above solutions and still have issues:

1. **Check Azure Monitor Workspace logs**
   ```bash
   az monitor diagnostic-settings list \
     --resource <prometheus-workspace-id>
   ```

2. **Review AKS cluster logs**
   ```bash
   az aks show --resource-group <rg> --name <cluster> \
     --query "agentPoolProfiles[].{name:name, provisioningState:provisioningState}"
   ```

3. **Open Azure support ticket**
   - Include Terraform outputs
   - Attach relevant logs
   - Describe steps to reproduce

4. **Community resources**
   - Azure AKS GitHub: https://github.com/Azure/AKS
   - Prometheus documentation: https://prometheus.io/docs/
   - Grafana community: https://community.grafana.com/

---

For configuration details, see [CONFIGURATION.md](CONFIGURATION.md).

For deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).
