# Learning Path Part 5: Production Patterns Deep Dive

> **Goal:** Master production-ready patterns for scaling, monitoring, and operating Kubernetes applications

---

## 🏗️ Foundational Structure: What You Need and Why

Getting an application running in Kubernetes is only half the job. Getting it **reliably running at scale, with visibility, and with the ability to recover from failure** is the production challenge. This requires an entirely different set of foundational structures — not application code, but **platform-level manifests and configurations** that govern how your workloads behave under real-world conditions.

Production readiness in AKS is built on three pillars, each with its own required structural components:

```
Production AKS Workload
├── Resilience Layer                  # Survives traffic spikes and node failures
│   ├── HorizontalPodAutoscaler       # Horizontal scaling based on metrics
│   ├── VerticalPodAutoscaler         # Right-sizing CPU/memory requests
│   ├── PodDisruptionBudget           # Guards availability during node drains
│   └── resource.requests/limits      # Accurate sizing for scheduler decisions
├── Observability Layer               # You can't fix what you can't see
│   ├── Prometheus                    # Metrics collection and storage
│   ├── Grafana                       # Metrics visualisation and dashboards
│   ├── AlertManager                  # Alert routing and deduplication
│   ├── ServiceMonitor                # Tells Prometheus which pods to scrape
│   ├── PrometheusRule                # Defines alert thresholds and conditions
│   └── Fluent Bit / OpenTelemetry   # Log shipping and distributed tracing
└── Reliability Layer                 # Fails gracefully and recovers fast
    ├── Health check probes            # Defined in Part 2, critical at scale
    ├── Rolling update strategy        # Zero-downtime deployments
    └── Topology spread constraints    # Distributes pods across fault domains
```

### Why Resource Requests and Limits Are Non-Negotiable

Before any autoscaling can work, every pod must declare **resource requests** (the minimum guaranteed capacity) and **resource limits** (the maximum allowed). These are not suggestions — they are the foundational contract between your application and the Kubernetes scheduler:

| Setting | What It Does | What Happens Without It |
|---------|-------------|------------------------|
| `resources.requests.cpu` | Reserves CPU on the node for this pod | The scheduler cannot make placement decisions — pods are deployed randomly and starve each other |
| `resources.requests.memory` | Reserves memory on the node | Pods compete for memory; high-memory pods OOMKill lower-priority ones unpredictably |
| `resources.limits.cpu` | Caps CPU usage (throttled, not killed) | One poorly-written pod can consume all node CPU, degrading every other pod on the node |
| `resources.limits.memory` | Caps memory usage (container killed + restarted if exceeded) | Memory leaks can consume an entire node's memory, causing cascading failures |

```yaml
# This is the minimum required for any production pod:
resources:
  requests:
    cpu: 200m      # 0.2 vCPU guaranteed
    memory: 256Mi  # 256MB guaranteed on the node
  limits:
    cpu: 500m      # Max 0.5 vCPU (throttled if exceeded)
    memory: 512Mi  # Max 512MB (OOMKilled if exceeded)
```

**The HPA cannot function without resource requests** — it calculates the scale target from the ratio of actual usage to requested capacity. No requests = HPA shows `<unknown>` utilisation and never scales.

### Why the Observability Stack Is a Mandatory Platform Component

Operating a production system without metrics, logs, and alerts is the equivalent of flying a plane without instruments. You can do it in good conditions, but any incident — a slow memory leak, a dependency timing out, a traffic spike — will go undetected until users are screaming.

The observability stack is installed **once at the platform level** and serves all applications:

```
kube-prometheus-stack (Helm chart)
├── Prometheus Operator           # Manages Prometheus instances, ServiceMonitors, PrometheusRules
├── Prometheus Server             # Scrapes and stores metrics
├── Grafana                       # Dashboards — pre-loaded with Kubernetes cluster dashboards
├── AlertManager                  # Groups, deduplicates, and routes alerts
├── kube-state-metrics            # Exports cluster state as metrics (node conditions, pod states)
└── node-exporter                 # Exports node-level OS metrics (CPU, disk, network)
```

This entire stack is deployed with one `helm install` command. The reason it's packaged together is that each component depends on the others: for example, AlertManager is useless without Prometheus, and PrometheusRules are useless without AlertManager configured to route them.

### The ServiceMonitor: Connecting Your App to Prometheus

After installing the platform observability stack, your application does **not** automatically get scraped. You must tell Prometheus which pods expose metrics and where to find them. This is done with a `ServiceMonitor` resource (a Custom Resource Definition introduced by the Prometheus Operator):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-metrics          # Identifies this scrape configuration
  namespace: production         # Must match the namespace of your Service
spec:
  selector:
    matchLabels:
      app: my-app               # Matches your app's Service labels
  endpoints:
  - port: metrics               # The named port on your Service that serves /metrics
    interval: 30s               # Scrape every 30 seconds
    path: /metrics              # The Prometheus metrics endpoint path
```

Without the `ServiceMonitor`, Prometheus scrapes zero metrics from your application. Without metrics, your Grafana dashboards show nothing, your HPA using custom metrics cannot function, and your alert rules have no data to evaluate.

### The PrometheusRule: Your Alert Structure

Alerts are not configured in Prometheus's config file — they are defined as Kubernetes resources called `PrometheusRule`. This means alert definitions are:
- Version-controlled in Git
- Deployed via ArgoCD like any other manifest
- Visible as Kubernetes resources (`kubectl get prometheusrule`)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-app-alerts
  namespace: monitoring
spec:
  groups:
  - name: my-app                # Group name (organises alerts in the UI)
    rules:
    - alert: HighErrorRate      # Human-readable alert name
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
      for: 5m                   # Must be true for 5 continuous minutes before firing
      labels:
        severity: critical      # Used by AlertManager to route to PagerDuty vs Slack
      annotations:
        summary: "Error rate above 5%"
        description: "Current error rate: {{ $value }}"
```

### The PodDisruptionBudget: Your Safety Net for Node Maintenance

AKS automatically drains nodes for maintenance, OS patching, and node pool upgrades. Without a `PodDisruptionBudget` (PDB), Kubernetes may terminate all replicas of your application simultaneously during a drain — causing complete downtime.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 2          # At least 2 replicas must always be running
  selector:
    matchLabels:
      app: my-app
```

This single YAML file guarantees that if you have 5 replicas, Kubernetes will never drain more nodes simultaneously than would cause the count to drop below 2. **This is the minimum required for any Deployment with multiple replicas in production.**

---

## 1. Configure Auto-Scaling

### Horizontal Pod Autoscaler (HPA)

**Concept:** Automatically scale pods based on metrics (CPU, memory, custom metrics).

#### Basic CPU-Based HPA

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # Scale when avg CPU > 70%
```

**How it Works:**
```
Current: 3 pods @ 90% CPU
Desired: ceil(3 * (90 / 70)) = ceil(3.86) = 4 pods
```

**Deploy:**
```bash
kubectl apply -f hpa.yaml

# Watch HPA
kubectl get hpa -w

# Generate load to test
kubectl run -it load-generator --rm --image=busybox -- /bin/sh
while true; do wget -q -O- http://myapp; done
```

#### Memory-Based HPA

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-memory-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

#### Custom Metrics HPA (Advanced)

**Example: Scale based on HTTP requests per second**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-custom-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"  # Scale when > 1000 req/s per pod
```

**Requires:** Prometheus Adapter or Azure Monitor metrics adapter

#### Prevent Thrashing

**Problem:** Rapid scale up/down causes instability

**Solution:** Behavior policies

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-stable-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 3
  maxReplicas: 15
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5min before scaling down
      policies:
      - type: Percent
        value: 50  # Max 50% reduction
        periodSeconds: 60  # Per minute
      - type: Pods
        value: 2  # Max 2 pods
        periodSeconds: 60
      selectPolicy: Min  # Use most conservative policy
    scaleUp:
      stabilizationWindowSeconds: 0  # Scale up immediately
      policies:
      - type: Percent
        value: 100  # Max 100% increase
        periodSeconds: 15  # Every 15 seconds
      - type: Pods
        value: 4  # Max 4 pods
        periodSeconds: 15
      selectPolicy: Max  # Use most aggressive policy
```

### Vertical Pod Autoscaler (VPA)

**Concept:** Automatically adjust CPU/memory requests and limits.

**Install VPA:**
```bash
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler
./hack/vpa-up.sh
```

**Create VPA:**
```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: myapp-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  updatePolicy:
    updateMode: "Auto"  # Recreate pods with new resources
  resourcePolicy:
    containerPolicies:
    - containerName: app
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 2000m
        memory: 4Gi
```

**Update Modes:**
- `Off`: Only provide recommendations
- `Initial`: Set resources on pod creation only
- `Recreate`: Update running pods (causes restart)
- `Auto`: Recreate + evict pods

### Cluster Autoscaler (AKS Automatic)

**In AKS Automatic, cluster autoscaling is enabled by default.**

Azure automatically adds/removes nodes based on pending pods.

**How it Works:**
```
1. Pod pending (no node has capacity)
2. Cluster Autoscaler provisions new node
3. Pod scheduled to new node
4. Node idle for 10min → Node deleted
```

**Best Practices:**
- Set pod resource requests accurately
- Use PodDisruptionBudgets to prevent disruption
- Monitor node scaling events

### Hands-On Exercise

**Deploy Auto-Scaling Application:**

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: php-apache
  template:
    metadata:
      labels:
        app: php-apache
    spec:
      containers:
      - name: php-apache
        image: registry.k8s.io/hpa-example
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 200m
          limits:
            cpu: 500m
---
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: php-apache
spec:
  ports:
  - port: 80
  selector:
    app: php-apache
---
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

**Test:**
```bash
kubectl apply -f deployment.yaml
kubectl apply -f hpa.yaml

# Generate load
kubectl run -it load-generator --rm --image=busybox -- /bin/sh
while sleep 0.01; do wget -q -O- http://php-apache; done

# Watch scaling (in another terminal)
kubectl get hpa php-apache -w
```

### External Resources

**HPA Documentation:**
- Kubernetes HPA: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
- HPA Walkthrough: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/

**VPA:**
- GitHub: https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler

**Industry Examples:**
- Airbnb's Autoscaling: https://medium.com/airbnb-engineering/auto-scaling-at-airbnb-b0d3e8e8e9c8
- Datadog's HPA Guide: https://www.datadoghq.com/blog/autoscale-kubernetes-datadog/

---

## 2. Set Up Monitoring and Alerts

### Observability Stack

**The Three Pillars:**
1. **Metrics:** Numerical data (CPU, memory, request rate)
2. **Logs:** Event records (application logs, errors)
3. **Traces:** Request flow across services

### Install Prometheus & Grafana

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=30d \
  --set grafana.adminPassword=admin123
```

**Access Grafana:**
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open: http://localhost:3000
# Username: admin
# Password: admin123
```

### Application Metrics

**Instrument Your App (.NET 8 Example):**

```csharp
// Program.cs
using System.Diagnostics;
using System.Diagnostics.Metrics;
using OpenTelemetry.Metrics;

var builder = WebApplication.CreateBuilder(args);

// Add OpenTelemetry metrics
builder.Services.AddOpenTelemetry()
    .WithMetrics(metrics =>
    {
        metrics.AddPrometheusExporter();
        metrics.AddMeter("MyApp.Metrics");
        metrics.AddAspNetCoreInstrumentation();
    });

var app = builder.Build();

// Create custom metrics
var meter = new Meter("MyApp.Metrics");
var requestCounter = meter.CreateCounter<long>("http_requests_total", description: "Total HTTP requests");
var requestDuration = meter.CreateHistogram<double>("http_request_duration_seconds", "ms", "HTTP request latency");

app.MapGet("/", () =>
{
    var sw = Stopwatch.StartNew();
    requestCounter.Add(1, new KeyValuePair<string, object?>("endpoint", "/"));
    
    // Simulate work
    Thread.Sleep(100);
    
    requestDuration.Record(sw.Elapsed.TotalSeconds, new KeyValuePair<string, object?>("endpoint", "/"));
    return "Hello World";
});

// Prometheus metrics endpoint
app.MapPrometheusScrapingEndpoint();

app.Run();
```

```xml
<!-- Add to .csproj -->
<ItemGroup>
  <PackageReference Include="OpenTelemetry.Exporter.Prometheus.AspNetCore" Version="1.7.0" />
  <PackageReference Include="OpenTelemetry.Extensions.Hosting" Version="1.7.0" />
  <PackageReference Include="OpenTelemetry.Instrumentation.AspNetCore" Version="1.7.0" />
</ItemGroup>
```

**ServiceMonitor (Prometheus Operator):**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-metrics
  namespace: production
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Alerting Rules

**PrometheusRule:**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: myapp-alerts
  namespace: monitoring
spec:
  groups:
  - name: myapp
    interval: 30s
    rules:
    # High error rate
    - alert: HighErrorRate
      expr: |
        rate(http_requests_total{status=~"5.."}[5m]) > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value }} req/s"
    
    # Pod down
    - alert: PodDown
      expr: |
        kube_pod_status_phase{namespace="production",pod=~"myapp-.*",phase!="Running"} > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.pod }} is down"
    
    # High memory usage
    - alert: HighMemoryUsage
      expr: |
        container_memory_usage_bytes{namespace="production",pod=~"myapp-.*"} 
        / container_spec_memory_limit_bytes > 0.9
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage on {{ $labels.pod }}"
        description: "Memory usage is {{ $value | humanizePercentage }}"
```

### Alert Manager Configuration

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-config
  namespace: monitoring
stringData:
  alertmanager.yaml: |
    global:
      resolve_timeout: 5m
    
    route:
      group_by: ['alertname', 'cluster']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'slack'
      routes:
      - match:
          severity: critical
        receiver: 'pagerduty'
    
    receivers:
    - name: 'slack'
      slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
    
    - name: 'pagerduty'
      pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_KEY'
```

### Logging with Fluent Bit

**Install Fluent Bit:**

```bash
helm repo add fluent https://fluent.github.io/helm-charts
helm install fluent-bit fluent/fluent-bit \
  --namespace logging \
  --create-namespace \
  --set backend.type=forward \
  --set backend.forward.host=fluentd.logging.svc.cluster.local
```

**Structured Logging (Application):**

```python
import logging
import json

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            'timestamp': self.formatTime(record),
            'level': record.levelname,
            'message': record.getMessage(),
            'logger': record.name,
        }
        if hasattr(record, 'user_id'):
            log_data['user_id'] = record.user_id
        return json.dumps(log_data)

handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logger = logging.getLogger(__name__)
logger.addHandler(handler)
logger.setLevel(logging.INFO)

# Usage
logger.info('User logged in', extra={'user_id': 12345})
```

### Distributed Tracing (OpenTelemetry)

**Install Jaeger:**

```bash
kubectl create namespace observability
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/crds/jaegertracing.io_jaegers_crd.yaml
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/service_account.yaml
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/role.yaml
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/role_binding.yaml
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/operator.yaml
```

**Instrument App:**

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.jaeger.thrift import JaegerExporter

# Setup tracing
trace.set_tracer_provider(TracerProvider())
jaeger_exporter = JaegerExporter(
    agent_host_name="jaeger-agent.observability.svc.cluster.local",
    agent_port=6831,
)
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(jaeger_exporter)
)

tracer = trace.get_tracer(__name__)

# Use in code
with tracer.start_as_current_span("process_order"):
    # Your code here
    pass
```

### Hands-On: Complete Monitoring Setup

```bash
# 1. Install monitoring stack
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# 2. Deploy sample app with metrics
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: sample
  template:
    metadata:
      labels:
        app: sample
    spec:
      containers:
      - name: app
        image: ghcr.io/stefanprodan/podinfo:latest
        ports:
        - containerPort: 9898
          name: http
        - containerPort: 9797
          name: metrics
---
apiVersion: v1
kind: Service
metadata:
  name: sample-app
spec:
  selector:
    app: sample
  ports:
  - name: http
    port: 80
    targetPort: 9898
  - name: metrics
    port: 9797
    targetPort: 9797
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: sample-app
spec:
  selector:
    matchLabels:
      app: sample
  endpoints:
  - port: metrics
EOF

# 3. Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# 4. Import dashboard (ID: 15760 - Kubernetes Cluster Monitoring)
```

### External Resources

**Prometheus:**
- Official Docs: https://prometheus.io/docs/
- Best Practices: https://prometheus.io/docs/practices/naming/

**Grafana:**
- Dashboards: https://grafana.com/grafana/dashboards/
- Tutorials: https://grafana.com/tutorials/

**OpenTelemetry:**
- Getting Started: https://opentelemetry.io/docs/

**Industry Examples:**
- Uber's Observability: https://www.uber.com/blog/observability-at-scale/
- Netflix's Monitoring: https://netflixtechblog.com/telltale-netflix-application-monitoring-simplified-5c08bfa780ba

---

## 3. Practice Troubleshooting

### Common Scenarios & Solutions

#### Scenario 1: CrashLoopBackOff

**Symptoms:**
```bash
kubectl get pods
# NAME                    READY   STATUS             RESTARTS   AGE
# myapp-7d8f9c-abc123     0/1     CrashLoopBackOff   5          3m
```

**Investigation:**
```bash
# Check logs
kubectl logs myapp-7d8f9c-abc123

# Check previous container logs
kubectl logs myapp-7d8f9c-abc123 --previous

# Describe pod
kubectl describe pod myapp-7d8f9c-abc123
```

**Common Causes:**
1. Application error (check logs)
2. Missing environment variable
3. Failed liveness probe
4. OOMKilled (memory limit too low)

**Solution Example:**
```yaml
# Fix: Increase memory limit
resources:
  limits:
    memory: "512Mi"  # Was 128Mi
```

#### Scenario 2: ImagePullBackOff

**Symptoms:**
```bash
kubectl get pods
# NAME                    READY   STATUS             RESTARTS   AGE
# myapp-7d8f9c-abc123     0/1     ImagePullBackOff   0          1m
```

**Investigation:**
```bash
kubectl describe pod myapp-7d8f9c-abc123
# Events:
#   Failed to pull image "myregistry.azurecr.io/myapp:v1.2.3": rpc error: code = Unknown desc = Error response from daemon: pull access denied
```

**Common Causes:**
1. Image doesn't exist
2. Wrong image tag
3. Registry authentication failure
4. Network issue

**Solution:**
```bash
# Verify image exists
az acr repository show-tags --name myregistry --repository myapp

# Check image pull secret
kubectl get secret regcred -o yaml

# Create image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=myregistry.azurecr.io \
  --docker-username=<username> \
  --docker-password=<password>

# Add to deployment
spec:
  template:
    spec:
      imagePullSecrets:
      - name: regcred
```

#### Scenario 3: Pending Pods

**Symptoms:**
```bash
kubectl get pods
# NAME                    READY   STATUS    RESTARTS   AGE
# myapp-7d8f9c-abc123     0/1     Pending   0          5m
```

**Investigation:**
```bash
kubectl describe pod myapp-7d8f9c-abc123
# Events:
#   0/3 nodes are available: 3 Insufficient cpu.
```

**Common Causes:**
1. Insufficient cluster resources
2. Node selector/affinity not matched
3. Taints and tolerations
4. PersistentVolume not available

**Solution:**
```bash
# Check node resources
kubectl top nodes

# Check resource requests
kubectl describe deployment myapp

# Solution: Reduce requests or add nodes (AKS Automatic auto-scales)
```

#### Scenario 4: Service Not Accessible

**Symptoms:**
```bash
curl http://myapp-service
# curl: (7) Failed to connect
```

**Investigation:**
```bash
# Check service
kubectl get svc myapp-service

# Check endpoints
kubectl get endpoints myapp-service

# Check pod labels match service selector
kubectl get pods --show-labels
kubectl describe svc myapp-service
```

**Common Causes:**
1. Service selector doesn't match pod labels
2. Pods not ready (readiness probe failing)
3. Wrong port configuration

**Solution:**
```yaml
# Fix: Correct selector
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp  # Must match pod labels
  ports:
  - port: 80
    targetPort: 8080  # Must match container port
```

### Troubleshooting Toolkit

**Essential Commands:**

```bash
# Pods
kubectl get pods -A
kubectl describe pod <pod-name>
kubectl logs <pod-name> -f
kubectl logs <pod-name> --previous
kubectl exec -it <pod-name> -- /bin/sh

# Deployments
kubectl get deployments
kubectl describe deployment <deployment-name>
kubectl rollout status deployment/<deployment-name>
kubectl rollout history deployment/<deployment-name>
kubectl rollout undo deployment/<deployment-name>

# Services
kubectl get svc
kubectl describe svc <service-name>
kubectl get endpoints <service-name>

# Events
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --field-selector involvedObject.name=<pod-name>

# Resources
kubectl top nodes
kubectl top pods
kubectl describe node <node-name>

# Network
kubectl run test-pod --rm -it --image=busybox -- sh
# Inside pod:
wget -O- http://service-name
nslookup service-name
```

**Debug Container (Ephemeral Containers):**

```bash
# Attach debug container to running pod
kubectl debug -it <pod-name> --image=busybox --target=<container-name>
```

### Hands-On: Troubleshooting Lab

**Deploy Broken Applications:**

```yaml
# 1. CrashLoop (missing env var)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crashloop-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: crashloop
  template:
    metadata:
      labels:
        app: crashloop
    spec:
      containers:
      - name: app
        image: busybox
        command: ["sh", "-c", "echo $REQUIRED_VAR && sleep 3600"]
        # Missing: env variable REQUIRED_VAR
---
# 2. ImagePull (wrong image)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: imagepull-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: imagepull
  template:
    metadata:
      labels:
        app: imagepull
    spec:
      containers:
      - name: app
        image: nonexistent/image:v1.0.0
---
# 3. Service mismatch
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend  # Label: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: app
        image: nginx
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: frontend  # Wrong selector!
  ports:
  - port: 80
```

**Your Task:** Fix each broken deployment.

### External Resources

**Troubleshooting Guides:**
- Kubernetes Debugging: https://kubernetes.io/docs/tasks/debug/
- AKS Troubleshooting: https://learn.microsoft.com/en-us/troubleshoot/azure/azure-kubernetes/welcome-azure-kubernetes

**Tools:**
- k9s (Terminal UI): https://k9scli.io/
- Lens (Desktop UI): https://k8slens.dev/
- Stern (Multi-pod logs): https://github.com/stern/stern

---

## Summary: Production Patterns Mastery

✅ **Auto-Scaling:** Configured HPA, VPA, and cluster autoscaling
✅ **Monitoring:** Set up Prometheus, Grafana, and alerting
✅ **Troubleshooting:** Practiced debugging common issues

---

## Congratulations! 🎉

You've completed the entire learning path:
- ✅ Part 1: Containers
- ✅ Part 2: Kubernetes Basics
- ✅ Part 3: Helm
- ✅ Part 4: ArgoCD
- ✅ Part 5: Production Patterns

### Next Steps

1. **Build a Real Project:** Deploy your own application end-to-end
2. **Contribute to Open Source:** Find Kubernetes projects on GitHub
3. **Get Certified:** Consider CKA (Certified Kubernetes Administrator) or CKAD (Certified Kubernetes Application Developer)
4. **Join the Community:** Attend KubeCon, join Slack channels, participate in meetups

### Recommended Certifications

- **CKAD:** Certified Kubernetes Application Developer
- **CKA:** Certified Kubernetes Administrator
- **CKS:** Certified Kubernetes Security Specialist
- **AZ-305:** Azure Solutions Architect Expert

### Community Resources

- **CNCF Slack:** https://slack.cncf.io/
- **Kubernetes Forum:** https://discuss.kubernetes.io/
- **KubeCon:** https://www.cncf.io/kubecon-cloudnativecon-events/
- **Awesome Kubernetes:** https://github.com/ramitsurana/awesome-kubernetes
