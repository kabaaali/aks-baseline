# AKS Observability Configuration Guide

This guide provides detailed explanations of each observability layer, metric definitions, PromQL queries, and customization options.

## Table of Contents

- [Layer 1: Cluster Capacity & Health](#layer-1-cluster-capacity--health)
- [Layer 2: Node & Infrastructure Metrics](#layer-2-node--infrastructure-metrics)
- [Layer 3: Workload & Pod Health](#layer-3-workload--pod-health)
- [Layer 4: Network & Storage](#layer-4-network--storage)
- [Customizing Thresholds](#customizing-thresholds)
- [Adding Custom Metrics](#adding-custom-metrics)

---

## Layer 1: Cluster Capacity & Health

### Cluster CPU/Memory Commit %

**Purpose:** Shows how much of your cluster is reserved (Requests) vs. Capacity. If this hits >80%, the Cluster Autoscaler should kick in. If it hits 100%, new pods sit in Pending.

**PromQL Query:**
```promql
# CPU Commit
sum(kube_pod_container_resource_requests{resource="cpu"}) / sum(kube_node_status_allocatable{resource="cpu"}) * 100

# Memory Commit
sum(kube_pod_container_resource_requests{resource="memory"}) / sum(kube_node_status_allocatable{resource="memory"}) * 100
```

**Visualization:** Gauge with thresholds
- Green: 0-70%
- Yellow: 70-80%
- Red: >80%

**Why it matters:**
- **High commit (>80%)** → Cluster Autoscaler should add nodes
- **Commit at 100%** → New pods cannot be scheduled (Pending state)
- **Low commit with high usage** → Developers are under-requesting resources

**Tuning:**
```hcl
# Adjust alert threshold in prometheus/alert-rules.yaml
- alert: ClusterCPUCommitHigh
  expr: ... > 80  # Change to 85 or 90 if needed
```

### Cluster Actual Usage %

**Purpose:** Shows real resource consumption. If "Commit" is high but "Usage" is low, your developers are over-provisioning (wasting money).

**PromQL Query:**
```promql
# CPU Usage
sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) / sum(kube_node_status_allocatable{resource="cpu"}) * 100

# Memory Usage
sum(container_memory_working_set_bytes{container!=""}) / sum(kube_node_status_allocatable{resource="memory"}) * 100
```

**Visualization:** Time series graph

**Analysis:**
- **Commit > Usage** → Over-provisioning, wasting money
- **Usage > Commit** → Under-requesting, risk of OOMKills
- **Both high** → Healthy utilization

### Node Count (Ready vs Not Ready)

**Purpose:** Detects if nodes are failing to join the cluster or crashing.

**PromQL Query:**
```promql
# Ready nodes
sum(kube_node_status_condition{condition="Ready",status="true"})

# Not Ready nodes
sum(kube_node_status_condition{condition="Ready",status="false"})
```

**Visualization:** Stat panel with color coding
- Ready: Green
- Not Ready: Red

**Alert:** Triggers if any node is Not Ready for >2 minutes

### Pods in Pending State

**Purpose:** Indicator of capacity exhaustion or unschedulable taints.

**PromQL Query:**
```promql
sum(kube_pod_status_phase{phase="Pending"})
```

**Visualization:** Single stat with red background if > 0

**Common causes:**
- Insufficient cluster capacity
- Node taints preventing scheduling
- PVC provisioning failures
- Resource requests too large for any node

---

## Layer 2: Node & Infrastructure Metrics

### Node CPU/Memory Pressure

**Purpose:** K8s will start evicting pods if the node is under pressure. Monitor `kube_node_status_condition`.

**PromQL Query:**
```promql
kube_node_status_condition{condition=~"MemoryPressure|DiskPressure|PIDPressure",status="true"}
```

**Visualization:** Table with color-coded status
- OK (false): Green
- PRESSURE (true): Red

**What happens when pressure is detected:**
- Kubernetes starts evicting pods
- Node becomes unschedulable
- Workloads may be disrupted

**Prevention:**
- Set appropriate resource limits
- Monitor node resource usage trends
- Scale cluster before pressure occurs

### Disk I/O & IOPS

**Purpose:** High IOPS wait times can kill database performance running on AKS. Watch for `node_disk_io_time_seconds_total`.

**PromQL Query:**
```promql
rate(node_disk_io_time_seconds_total[5m])
```

**Visualization:** Time series

**Interpretation:**
- **High I/O time** → Disk is bottleneck
- **Spiky patterns** → Batch jobs or backups
- **Sustained high** → Consider Premium SSD or larger VM SKU

**Azure VM Disk Limits:**
- Standard SSD: 500-6000 IOPS
- Premium SSD: 120-20000 IOPS
- Ultra Disk: Up to 160000 IOPS

### Inodes Usage

**Purpose:** If a container writes millions of small files, you run out of Inodes before disk space. The node becomes unusable.

**PromQL Query:**
```promql
(1 - (node_filesystem_files_free{mountpoint="/"} / node_filesystem_files{mountpoint="/"})) * 100
```

**Visualization:** Gauge
- Green: 0-70%
- Yellow: 70-85%
- Red: >85%

**Common causes:**
- Log files not rotated
- Temp files accumulating
- Container image layers

**Fix:**
```bash
# Find directories with most files
find / -xdev -type f | cut -d "/" -f 2 | sort | uniq -c | sort -n
```

### Disk Space Used

**Purpose:** Standard monitoring. If /var/lib/docker or /var/log fills up, the node dies.

**PromQL Query:**
```promql
(1 - (node_filesystem_avail_bytes{mountpoint=~"/|/var/lib/docker|/var/log"} / node_filesystem_size_bytes{mountpoint=~"/|/var/lib/docker|/var/log"})) * 100
```

**Visualization:** Bar gauge

**Critical mountpoints:**
- `/` - Root filesystem
- `/var/lib/docker` - Container images and layers
- `/var/log` - System and application logs

**Mitigation:**
- Enable log rotation
- Clean up old container images
- Increase node disk size

---

## Layer 3: Workload & Pod Health

### CrashLoopBackOffs (Restarts)

**Purpose:** Top Priority. High restart rates indicate application bugs, OOMKills, or config errors.

**PromQL Query:**
```promql
# Restart rate
rate(kube_pod_container_status_restarts_total[15m]) > 0

# Restart count over time
rate(kube_pod_container_status_restarts_total[5m]) * 300
```

**Visualization:** Heatmap + Time series

**Investigation steps:**
1. Check pod logs: `kubectl logs <pod> --previous`
2. Describe pod: `kubectl describe pod <pod>`
3. Check events: `kubectl get events --sort-by='.lastTimestamp'`

**Common causes:**
- Application crashes (bugs)
- OOMKills (memory limits too low)
- Liveness probe failures
- Configuration errors

### OOMKills (Out of Memory)

**Purpose:** Specific detection of containers killed because they exceeded their Memory Limit.

**PromQL Query:**
```promql
sum by (namespace, pod, container) (increase(kube_pod_container_status_terminated_reason{reason="OOMKilled"}[5m]))
```

**Visualization:** Time series (bar chart)

**Resolution:**
1. **Increase memory limits:**
   ```yaml
   resources:
     limits:
       memory: "2Gi"  # Increase this
   ```

2. **Investigate memory leak:**
   ```bash
   kubectl top pod <pod>
   ```

3. **Profile application:**
   - Use memory profiling tools
   - Check for unbounded caches
   - Review database connection pools

### CPU Throttling

**Purpose:** Performance Killer. If a pod hits its CPU Limit, Linux CFS throttles it. The app doesn't crash, it just gets slow/laggy.

**PromQL Query:**
```promql
sum by (namespace, pod, container) (rate(container_cpu_cfs_throttled_seconds_total{container!=""}[5m]))
```

**Visualization:** Time series

**Interpretation:**
- **>0.25 (25%)** → Significant throttling, performance impact
- **>0.50 (50%)** → Severe throttling, application very slow

**Solutions:**
1. **Increase CPU limits:**
   ```yaml
   resources:
     limits:
       cpu: "2000m"  # Increase this
   ```

2. **Remove CPU limits** (if acceptable):
   ```yaml
   resources:
     requests:
       cpu: "500m"
     # No limits - allows bursting
   ```

3. **Optimize application:**
   - Profile CPU usage
   - Reduce computational complexity
   - Use caching

### Deployment Replicas (Ready vs Desired)

**Purpose:** Ensures deployments have the expected number of running pods.

**PromQL Query:**
```promql
# Ready replicas
sum by (namespace, deployment) (kube_deployment_status_replicas_ready)

# Desired replicas
sum by (namespace, deployment) (kube_deployment_spec_replicas)
```

**Visualization:** Stat panel
- Ready: Green
- Desired: Blue

**Alert:** Triggers if mismatch persists >10 minutes

---

## Layer 4: Network & Storage

### Network Packet Drops

**Purpose:** Indicates CNI issues (Azure CNI/Kubenet) or VM limit exhaustion.

**PromQL Query:**
```promql
# Receive drops
rate(node_network_receive_drop_total[5m])

# Transmit drops
rate(node_network_transmit_drop_total[5m])
```

**Visualization:** Time series

**Causes:**
- **VM network limits exceeded** - Check Azure VM SKU limits
- **CNI plugin issues** - Azure CNI or Kubenet problems
- **Network congestion** - Too much traffic

**Azure VM Network Limits:**
- Standard_D4s_v3: 2 Gbps
- Standard_D8s_v3: 4 Gbps
- Check your VM SKU limits

### Persistent Volume (PV) Usage

**Purpose:** PVCs are not elastic by default. If a DB volume fills up, the DB crashes.

**PromQL Query:**
```promql
(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100
```

**Visualization:** Bar gauge
- Green: 0-70%
- Yellow: 70-85%
- Red: >85%

**Prevention:**
1. **Expand PVC** (if storage class supports it):
   ```bash
   kubectl patch pvc <pvc-name> -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
   ```

2. **Clean up old data:**
   - Database maintenance
   - Log rotation
   - Archive old files

3. **Monitor growth rate:**
   - Predict when volume will fill
   - Plan expansion proactively

### CoreDNS Latency

**Purpose:** DNS is always the problem. High CoreDNS latency slows down every service-to-service call in the mesh.

**PromQL Query:**
```promql
# P99 latency
histogram_quantile(0.99, sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le, server))

# P95 latency
histogram_quantile(0.95, sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le, server))
```

**Visualization:** Time series

**Thresholds:**
- **<10ms** - Excellent
- **10-50ms** - Acceptable
- **50-100ms** - Warning
- **>100ms** - Critical

**Troubleshooting:**
1. **Check CoreDNS pods:**
   ```bash
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   kubectl top pods -n kube-system -l k8s-app=kube-dns
   ```

2. **Scale CoreDNS:**
   ```bash
   kubectl scale deployment coredns -n kube-system --replicas=3
   ```

3. **Enable DNS caching in applications:**
   - Use connection pooling
   - Cache DNS lookups
   - Use service mesh with DNS caching

---

## Customizing Thresholds

### Alert Thresholds

Edit `prometheus/alert-rules.yaml`:

```yaml
# Example: Change CPU commit warning from 80% to 85%
- alert: ClusterCPUCommitHigh
  expr: ... > 85  # Changed from 80
  for: 5m
```

### Dashboard Thresholds

Edit dashboard JSON files:

```json
"thresholds": {
  "mode": "absolute",
  "steps": [
    {"color": "green", "value": null},
    {"color": "yellow", "value": 75},  // Changed from 70
    {"color": "red", "value": 90}      // Changed from 80
  ]
}
```

### Recording Rule Intervals

Edit `prometheus/recording-rules.yaml`:

```yaml
- name: cluster_capacity_recordings
  interval: 60s  # Changed from 30s for less frequent evaluation
```

---

## Adding Custom Metrics

### 1. Create Recording Rule

Add to `prometheus/recording-rules.yaml`:

```yaml
- record: custom:my_metric:namespace
  expr: sum by (namespace) (my_custom_metric)
```

### 2. Create Alert Rule

Add to `prometheus/alert-rules.yaml`:

```yaml
- alert: MyCustomAlert
  expr: custom:my_metric:namespace > 100
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Custom metric threshold exceeded"
```

### 3. Add Dashboard Panel

Create new panel in Grafana dashboard JSON:

```json
{
  "targets": [{
    "expr": "custom:my_metric:namespace",
    "legendFormat": "{{namespace}}"
  }],
  "title": "My Custom Metric"
}
```

---

## Best Practices

### Resource Requests and Limits

**Recommendations:**
- Set requests based on average usage
- Set limits at 2x requests for CPU
- Set memory limits carefully (OOMKills are disruptive)

### Alert Fatigue Prevention

- Start with higher thresholds
- Use `for:` duration to avoid flapping
- Group related alerts
- Use severity levels appropriately

### Dashboard Organization

- Use folders for different teams/applications
- Create overview dashboards for executives
- Detailed dashboards for operators
- Use variables for namespace filtering

---

For deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

For troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
