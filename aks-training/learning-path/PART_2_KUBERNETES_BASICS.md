# Learning Path Part 2: Kubernetes Basics Deep Dive

> **Goal:** Understand core Kubernetes concepts and deploy your first workloads

---

## 🏗️ Foundational Structure: What You Need and Why

Kubernetes is not a single tool — it is a **system of structured declarations**. Unlike traditional deployment scripts where you describe *how* to deploy, Kubernetes asks you to describe *what you want*, and then the system figures out how to get there. To work with Kubernetes effectively, you must understand the foundational **resource types**, **manifest anatomy**, and **supporting objects** that everything else is built upon.

### The Core Resource Hierarchy

```
Cluster
└── Namespace                    # Logical isolation boundary (dev, staging, prod)
    ├── Deployment                # Manages rollout & self-healing of Pods
    │   └── ReplicaSet            # Ensures desired number of Pods exist
    │       └── Pod               # The actual running workload unit
    ├── Service                   # Stable network endpoint for a set of Pods
    ├── ConfigMap                 # Non-sensitive configuration data
    ├── Secret                    # Sensitive configuration data (base64 encoded)
    └── ServiceAccount + RBAC    # Identity and permissions for workloads
```

This isn't an abstract diagram — every resource exists as a YAML file you will write, commit to Git, and apply to a cluster.

### The Anatomy of a Kubernetes Manifest

Every Kubernetes resource follows the same four-field skeleton. These are not arbitrary — Kubernetes validates each field before accepting any manifest:

```yaml
apiVersion: apps/v1       # Which API group & version? (v1, apps/v1, batch/v1, etc.)
kind: Deployment          # What type of resource is this?
metadata:                 # Identity metadata (name, namespace, labels, annotations)
  name: my-app
  namespace: production
  labels:
    app: my-app
    environment: production
spec:                     # The desired state — what you want Kubernetes to achieve
  replicas: 3
  ...
```

| Field | Purpose | Why Necessary |
|-------|---------|---------------|
| `apiVersion` | Selects the correct API handler on the control plane | Wrong version = 404 error or missing features in the spec |
| `kind` | Tells Kubernetes which controller will manage this resource | Omitting or misspelling causes immediate rejection |
| `metadata.labels` | Key-value pairs used by Services and selectors to discover Pods | Without labels, Services cannot route traffic; HPAs cannot target Deployments |
| `metadata.namespace` | Isolates resources per environment or team | Without namespaces, all teams share one flat space — names clash and RBAC is impossible |
| `spec` | The heart of every manifest — the declared desired state | This is what Kubernetes continuously reconciles against reality |

### Why Labels Are Not Optional

Labels are the **nerve system** of Kubernetes. A Service finds its target Pods by matching labels. An HPA targets a Deployment by name. A NetworkPolicy restricts traffic between Pods by labels. If your labels are inconsistent — say your Pod has `app: my-app` but your Service selector expects `app: myapp` — traffic will silently fail with no error message. This is one of the most common debugging scenarios for new Kubernetes engineers.

**Pattern to follow consistently:**

```yaml
labels:
  app: <service-name>          # Matches Service selectors
  version: v1.2.3              # Supports blue-green and canary deployments
  environment: production      # Supports environment-level policies
  managed-by: helm             # Tracks how the resource was deployed
```

### Why You Need a Deployment, Not Just a Pod

Running a bare Pod directly is like deploying a single server with no failover. If the Pod crashes, it stays dead. A **Deployment** wraps your Pod template in a controller that:

1. Maintains the desired number of running replicas
2. Performs rolling updates with zero downtime
3. Tracks rollout history for instant rollback
4. Self-heals by replacing failed Pods automatically

**The Pod template inside a Deployment is not a Pod manifest** — it is a template that the Deployment uses to create Pods. You never `kubectl apply` a Pod in production; you always go through a Deployment (or StatefulSet for stateful workloads).

### Why Services Are Required (Not Optional)

Pods are **ephemeral by design**. Every time a Pod restarts, it gets a new IP address. Any code that talks directly to a Pod IP will break on every restart. A Service:

- Gets a **stable virtual IP (ClusterIP)** that never changes
- Discovers backing Pods dynamically via label selectors
- Load-balances connections across all healthy Pods automatically
- Provides a **DNS name** (`service-name.namespace.svc.cluster.local`) that works from any Pod in the cluster

Without a Service, you cannot reliably connect microservices to each other or expose them externally.

### Supporting Structures: ConfigMaps and Secrets

Embedding configuration and credentials directly in container images is a fundamental anti-pattern. ConfigMaps and Secrets separate configuration from code:

- **ConfigMap**: Stores non-sensitive config (database hostname, feature flags, log levels) that can be injected as environment variables or mounted as files
- **Secret**: Stores sensitive data (passwords, API keys, TLS certificates) with base64 encoding and RBAC-restricted access

> **Important:** Secrets in Kubernetes are base64-encoded, not encrypted, by default. In AKS production environments, Secrets should be backed by **Azure Key Vault** via the Secrets Store CSI Driver.

---

## 1. Deploy a Pod

### Concept: What is a Pod?

A **Pod** is the smallest deployable unit in Kubernetes. It's a wrapper around one or more containers that:
- Share the same network namespace (same IP address)
- Share the same storage volumes
- Are scheduled together on the same node

**Analogy:** A pod is like a shared apartment where containers are roommates.

### Your First Pod

**Create `pod.yaml`:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-first-pod
  labels:
    app: demo
spec:
  containers:
  - name: web
    image: nginx:1.25
    ports:
    - containerPort: 80
```

**Deploy:**
```bash
# Apply the manifest
kubectl apply -f pod.yaml

# Check status
kubectl get pods

# Detailed info
kubectl describe pod my-first-pod

# View logs
kubectl logs my-first-pod

# Access the pod (port-forward)
kubectl port-forward pod/my-first-pod 8080:80

# Test
curl http://localhost:8080
```

### Pod Lifecycle

```
Pending → Running → Succeeded/Failed
   ↓         ↓
Creating  Terminating
```

**States:**
- **Pending:** Waiting for scheduling or image pull
- **Running:** At least one container is running
- **Succeeded:** All containers terminated successfully
- **Failed:** At least one container failed
- **Unknown:** Communication error with node

### Multi-Container Pod Pattern

**Sidecar Pattern:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-sidecar
spec:
  containers:
  # Main application
  - name: app
    image: myapp:v1
    ports:
    - containerPort: 8080
  
  # Sidecar: Log shipper
  - name: log-shipper
    image: fluent/fluentd:v1.16
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  
  volumes:
  - name: logs
    emptyDir: {}
```

**Use Cases:**
- Log aggregation (Fluentd, Filebeat)
- Service mesh proxies (Envoy, Linkerd)
- Configuration reloaders

### Hands-On Exercise

**Deploy a .NET 8 App Pod:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dotnet-app
  labels:
    app: dotnet-demo
spec:
  containers:
  - name: app
    image: mcr.microsoft.com/dotnet/samples:aspnetapp
    ports:
    - containerPort: 8080
    env:
    - name: ASPNETCORE_ENVIRONMENT
      value: "Development"
    - name: ASPNETCORE_URLS
      value: "http://+:8080"
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
```

**Deploy and Test:**
```bash
kubectl apply -f dotnet-pod.yaml
kubectl port-forward pod/dotnet-app 8080:8080
curl http://localhost:8080
```

### External Resources

**Official Kubernetes Docs:**
- Pod Overview: https://kubernetes.io/docs/concepts/workloads/pods/
- Pod Lifecycle: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/

**Interactive Learning:**
- Kubernetes Playground: https://www.katacoda.com/courses/kubernetes
- Play with Kubernetes: https://labs.play-with-k8s.com/

---

## 2. Create a Service

### Concept: Why Services?

**Problem:** Pods are ephemeral. When a pod dies and restarts, it gets a new IP address.

**Solution:** A Service provides a stable endpoint (virtual IP) that load-balances to pods.

### Service Types

| Type | Use Case | Access |
|------|----------|--------|
| **ClusterIP** | Internal communication | Only within cluster |
| **NodePort** | External access (dev/test) | `<NodeIP>:<NodePort>` |
| **LoadBalancer** | Production external access | Cloud provider LB |
| **ExternalName** | Alias to external service | DNS CNAME |

### ClusterIP Service (Most Common)

**Create Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
```

**Create Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: ClusterIP
  selector:
    app: web  # Matches pods with label app=web
  ports:
  - protocol: TCP
    port: 80        # Service port
    targetPort: 80  # Container port
```

**Deploy:**
```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# View service
kubectl get svc web-service

# Test from another pod
kubectl run test-pod --rm -it --image=busybox -- sh
wget -O- http://web-service
```

### How Services Work (iptables)

When you create a Service, kube-proxy creates iptables rules on every node:

```
Client → Service VIP (10.0.100.50:80)
         ↓ (iptables DNAT)
         → Pod 1 (10.244.1.5:80)  33% probability
         → Pod 2 (10.244.1.6:80)  33% probability
         → Pod 3 (10.244.1.7:80)  33% probability
```

### NodePort Service (External Access)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30080  # Optional: 30000-32767
```

**Access:**
```bash
# Get node IP
kubectl get nodes -o wide

# Access service
curl http://<NODE_IP>:30080
```

### LoadBalancer Service (Production)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-lb
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

**In AKS, this creates an Azure Load Balancer with a public IP.**

```bash
kubectl get svc web-lb
# EXTERNAL-IP will show public IP after ~2 minutes
```

### Service Discovery (DNS)

Kubernetes runs CoreDNS. Every service gets a DNS name:

```
<service-name>.<namespace>.svc.cluster.local
```

**Example:**
```yaml
# Service in namespace "production"
apiVersion: v1
kind: Service
metadata:
  name: database
  namespace: production
```

**Access from any pod:**
```bash
# Short form (same namespace)
curl http://database

# FQDN (any namespace)
curl http://database.production.svc.cluster.local
```

### Hands-On Exercise

**Deploy a Multi-Tier App:**

```yaml
# Backend Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo
        args:
        - "-text=Hello from Backend"
        ports:
        - containerPort: 5678
---
# Backend Service
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 5678
---
# Frontend Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
---
# Frontend Service (LoadBalancer)
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
```

**Test:**
```bash
kubectl apply -f multi-tier-app.yaml

# Test backend from frontend pod
kubectl exec -it deployment/frontend -- curl http://backend-service
```

### External Resources

**Kubernetes Services:**
- Service Docs: https://kubernetes.io/docs/concepts/services-networking/service/
- DNS for Services: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/

**Industry Examples:**
- Spotify's Service Mesh: https://engineering.atspotify.com/2018/09/service-mesh-at-spotify/
- Airbnb's Kubernetes Networking: https://medium.com/airbnb-engineering/kubernetes-networking-at-airbnb-8f9e1e2e0b3e

---

## 3. Understand Health Checks

### Why Health Checks Matter

**Without Health Checks:**
```
Pod starts → Kubernetes sends traffic → App still booting → 500 errors
Pod crashes → Kubernetes keeps sending traffic → Downtime
```

**With Health Checks:**
```
Pod starts → Readiness probe fails → No traffic sent → App ready → Traffic flows
Pod crashes → Liveness probe fails → Kubernetes restarts pod → Auto-recovery
```

### Three Types of Probes

| Probe | Purpose | Action on Failure |
|-------|---------|-------------------|
| **Liveness** | Is the app alive? | Restart container |
| **Readiness** | Can the app serve traffic? | Remove from Service |
| **Startup** | Has the app finished booting? | Wait before liveness kicks in |

### Liveness Probe

**Purpose:** Detect deadlocks or hung processes.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-demo
spec:
  containers:
  - name: app
    image: myapp:v1
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 30  # Wait 30s after start
      periodSeconds: 10        # Check every 10s
      timeoutSeconds: 5        # Timeout after 5s
      failureThreshold: 3      # Restart after 3 failures
```

**Probe Types:**

```yaml
# HTTP GET
livenessProbe:
  httpGet:
    path: /health
    port: 8080
    httpHeaders:
    - name: Custom-Header
      value: Awesome

# TCP Socket
livenessProbe:
  tcpSocket:
    port: 8080

# Exec Command
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
```

### Readiness Probe

**Purpose:** Determine if pod should receive traffic.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: api:v1
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 2
```

**Readiness vs Liveness:**

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var startTime = DateTime.UtcNow;
var isHealthy = true;
var dbConnected = false;

// Simulate DB connection after 10 seconds
app.Use(async (context, next) =>
{
    if ((DateTime.UtcNow - startTime).TotalSeconds > 10)
    {
        dbConnected = true;
    }
    await next();
});

// Liveness: "Am I alive?"
app.MapGet("/healthz", () =>
{
    return isHealthy ? Results.Ok("OK") : Results.StatusCode(500);
});

// Readiness: "Can I serve traffic?"
app.MapGet("/ready", () =>
{
    return dbConnected ? Results.Ok("Ready") : Results.StatusCode(503);
});

app.MapGet("/", () => Results.Ok(new { status = "running", db = dbConnected }));

app.Run();
```

### Startup Probe

**Purpose:** Give slow-starting apps extra time.

**Problem:**
```
Java app takes 60s to start
Liveness probe timeout: 5s
Result: Kubernetes kills pod before it finishes starting!
```

**Solution:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: slow-starter
spec:
  containers:
  - name: java-app
    image: my-java-app:v1
    ports:
    - containerPort: 8080
    startupProbe:
      httpGet:
        path: /health
        port: 8080
      initialDelaySeconds: 0
      periodSeconds: 10
      failureThreshold: 30  # 30 * 10s = 5 minutes max startup time
    livenessProbe:
      httpGet:
        path: /health
        port: 8080
      periodSeconds: 10
      failureThreshold: 3
```

**Flow:**
1. Startup probe runs (up to 5 minutes)
2. Once startup succeeds, liveness probe takes over
3. Startup probe never runs again

### Best Practices

**✅ Do:**
- Use readiness for dependency checks (DB, cache)
- Use liveness for deadlock detection
- Set appropriate timeouts (don't make them too aggressive)
- Implement lightweight health endpoints

**❌ Don't:**
- Use liveness for dependency checks (causes restart loops)
- Make health checks expensive (DB queries, external API calls)
- Set timeouts too short (causes false positives)

### Hands-On Exercise

**Deploy an App with All Three Probes:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: robust-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: robust
  template:
    metadata:
      labels:
        app: robust
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo
        args:
        - "-text=I am healthy"
        ports:
        - containerPort: 5678
        startupProbe:
          httpGet:
            path: /
            port: 5678
          failureThreshold: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 5678
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 5678
          periodSeconds: 5
          timeoutSeconds: 2
          failureThreshold: 2
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
```

**Test Failure Scenarios:**

```bash
# Deploy
kubectl apply -f robust-app.yaml

# Watch pods
kubectl get pods -w

# Simulate liveness failure (exec into pod and kill process)
kubectl exec -it deployment/robust-app -- pkill http-echo

# Watch Kubernetes restart the container
kubectl describe pod <pod-name>
```

### External Resources

**Kubernetes Health Checks:**
- Configure Probes: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
- Best Practices: https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-setting-up-health-checks-with-readiness-and-liveness-probes

**Industry Examples:**
- Google Cloud: Health Check Patterns: https://cloud.google.com/architecture/best-practices-for-building-containers
- AWS: EKS Health Checks: https://aws.amazon.com/blogs/containers/implementing-health-checks-in-amazon-eks/

---

## Summary: Kubernetes Basics Checklist

✅ **Pods:** Deployed single and multi-container pods
✅ **Services:** Created ClusterIP, NodePort, and LoadBalancer services
✅ **Health Checks:** Implemented liveness, readiness, and startup probes

---

## Next Steps

➡️ **Next:** [Part 3: Helm Deep Dive](PART_3_HELM.md)

### Additional Practice

1. **Deploy a Database:** Create a StatefulSet for PostgreSQL with persistent storage
2. **Service Mesh:** Explore Istio or Linkerd for advanced traffic management
3. **Network Policies:** Implement pod-to-pod network security
4. **Resource Quotas:** Set namespace-level resource limits

### Community Resources

- **Kubernetes Slack:** https://slack.k8s.io/
- **CNCF YouTube:** https://www.youtube.com/c/cloudnativefdn
- **KubeCon Talks:** https://www.youtube.com/playlist?list=PLj6h78yzYM2O1wlsM-Ma-RYhfT5LKq0XC
