# Engineering Deep Dive: Foundational Knowledge for AKS Automatic

> **Purpose**: This document provides nth-level technical depth for engineers who need to understand the *why* and *how* at a systems level. This is not a tutorial—it's a technical reference for production engineering.

---

## Table of Contents
1. [Container Runtime Internals](#1-container-runtime-internals)
2. [Kubernetes Scheduling & Resource Management](#2-kubernetes-scheduling--resource-management)
3. [AKS Automatic Architecture](#3-aks-automatic-architecture)
4. [Networking Deep Dive](#4-networking-deep-dive)
5. [Storage & Persistence](#5-storage--persistence)
6. [Helm: Templating & Release Management](#6-helm-templating--release-management)
7. [ArgoCD: GitOps Reconciliation](#7-argocd-gitops-reconciliation)
8. [Production Patterns & Anti-Patterns](#8-production-patterns--anti-patterns)

---

## 1. Container Runtime Internals

### 1.1 The Container Abstraction

**Fundamental Truth**: Containers don't exist as kernel objects. They are a userspace abstraction created by combining Linux kernel primitives.

#### Namespaces: Process Isolation

Namespaces provide isolated views of system resources:

| Namespace | Isolation Scope | Example |
|-----------|----------------|---------|
| **PID** | Process IDs | Container sees PID 1 as its init, host sees it as PID 12345 |
| **NET** | Network stack | Container has own `eth0`, routing table, iptables |
| **MNT** | Filesystem mounts | Container's `/` is different from host's `/` |
| **UTS** | Hostname | Container can have hostname `api-server` while host is `node-1` |
| **IPC** | Inter-process communication | Shared memory segments isolated |
| **USER** | User/Group IDs | UID 0 in container != UID 0 on host (user namespaces) |
| **CGROUP** | Cgroup root | Container sees own cgroup hierarchy |

**Deep Dive: PID Namespace**
```bash
# On host
ps aux | grep myapp
# Shows: root 12345 myapp

# Inside container
ps aux
# Shows: root 1 myapp
```

The kernel maintains a PID translation table. When container process 1 makes a syscall, the kernel translates it to the real PID 12345.

**Why This Matters**: 
- Signal handling: `kill -9 1` inside container only kills that container's init
- Process visibility: Container can't see or signal host processes
- Security boundary: Namespace escape is a critical vulnerability class

#### Cgroups: Resource Limits & Accounting

Cgroups (Control Groups) enforce resource constraints via kernel subsystems:

**CPU Subsystem (CFS - Completely Fair Scheduler)**
```
cpu.cfs_period_us = 100000  (100ms)
cpu.cfs_quota_us = 50000    (50ms)
```

This means: "In every 100ms period, this cgroup can use 50ms of CPU time" = 0.5 CPU cores.

**Kubernetes Translation**:
```yaml
resources:
  limits:
    cpu: "500m"  # 500 millicores = 0.5 cores
```

**Critical Pitfall: CPU Throttling**

When a process exceeds its quota:
1. Kernel sets `nr_throttled` counter
2. Process is **hard-stopped** until next period
3. Even if host CPU is 10% utilized, your process waits

**Real-World Impact**:
```
Scenario: Java app with cpu.limit=1 core
- JVM garbage collection needs 1.2 cores for 50ms
- Kernel throttles at 100ms mark
- GC pauses extend from 50ms to 150ms
- Application sees "stop-the-world" pauses
```

**Solution**: Set `limits` higher than `requests`, or remove limits for latency-sensitive apps.

**Memory Subsystem**
```
memory.limit_in_bytes = 536870912  (512Mi)
memory.oom_control = 0  (OOM killer enabled)
```

When memory limit is hit:
1. Kernel tries to reclaim pages (swap, drop caches)
2. If reclaim fails, OOM killer activates
3. Kernel calculates OOM score for each process
4. Kills highest-scoring process

**OOM Score Calculation**:
```
oom_score = (process_rss / total_memory) * 1000 + oom_score_adj
```

**Kubernetes QoS Classes** (determines `oom_score_adj`):

| QoS Class | Condition | oom_score_adj | Kill Priority |
|-----------|-----------|---------------|---------------|
| **Guaranteed** | requests == limits | -997 | Last |
| **Burstable** | requests < limits | min(max(2, 1000-(1000*memoryRequestBytes)/machineMemoryCapacityBytes), 999) | Middle |
| **BestEffort** | No requests/limits | 1000 | First |

**Why This Matters**: A BestEffort pod will be killed before a Guaranteed pod, even if the BestEffort pod is using less memory.

### 1.2 Container Filesystem: OverlayFS

**Layer Architecture**:
```
Container Filesystem (Union Mount)
├── Upper Layer (R/W) - Container changes
├── Lower Layer 3 (R/O) - App layer
├── Lower Layer 2 (R/O) - Dependencies
├── Lower Layer 1 (R/O) - Base OS
└── Merged View - What container sees
```

**Copy-on-Write (CoW) Mechanism**:

When container writes to `/app/config.json`:
1. Kernel checks: Is file in upper layer? No.
2. Kernel copies entire file from lower → upper layer
3. Kernel modifies file in upper layer
4. Subsequent reads/writes use upper layer copy

**Performance Implications**:
- **First write penalty**: Copying large files is expensive
- **Disk I/O amplification**: Writing 1KB to a 100MB file = 100MB copy
- **Solution**: Use volumes for high-write workloads

```yaml
# Anti-pattern: Writing logs to container filesystem
# Pattern: Use emptyDir volume
volumes:
- name: logs
  emptyDir: {}
volumeMounts:
- name: logs
  mountPath: /var/log/app
```

### 1.3 Container Image Optimization

**Multi-Stage Build Deep Dive**:

```dockerfile
# Stage 1: Builder (Large, has compilers)
FROM golang:1.21 AS builder
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o app

# Stage 2: Runtime (Minimal)
FROM gcr.io/distroless/static-debian12
COPY --from=builder /build/app /app
USER 65532:65532
ENTRYPOINT ["/app"]
```

**Why Distroless?**
- No shell (`/bin/sh` doesn't exist)
- No package manager
- Attack surface: ~20 packages vs ~200 in alpine
- Image size: ~2MB vs ~50MB alpine

**Security: Running as Non-Root**

```dockerfile
# Create user with specific UID
RUN adduser --disabled-password --gecos "" --uid 10001 appuser
USER 10001

# Or use numeric UID directly (works in distroless)
USER 65532:65532
```

**Why Numeric UID?** Distroless has no `/etc/passwd`, so username resolution fails. Numeric UIDs work universally.

---

## 2. Kubernetes Scheduling & Resource Management

### 2.1 The Scheduler Pipeline

When you create a Pod, it goes through:

```
1. API Server receives Pod spec
2. Writes to etcd (Pod status: Pending)
3. Scheduler watches for Pending pods
4. Scheduler runs filtering + scoring
5. Scheduler binds Pod to Node
6. Kubelet on Node pulls image
7. Kubelet creates container
8. Pod status: Running
```

**Filtering Phase** (Predicates):

| Filter | Purpose | Example Failure |
|--------|---------|-----------------|
| **PodFitsResources** | Node has enough CPU/RAM | Node has 2 CPU, Pod requests 4 CPU |
| **PodFitsHostPorts** | Host port not in use | Two pods want hostPort 8080 |
| **NodeAffinity** | Node matches affinity rules | Pod requires `disktype=ssd`, node has `disktype=hdd` |
| **TaintToleration** | Pod tolerates node taints | Node tainted `NoSchedule`, Pod has no toleration |

**Scoring Phase** (Priorities):

Scheduler scores each node (0-100):
- **LeastRequestedPriority**: Prefers nodes with more free resources
- **BalancedResourceAllocation**: Spreads CPU/memory usage evenly
- **ImageLocalityPriority**: Prefers nodes with image already pulled

**Final Score**: Weighted sum of all priorities.

### 2.2 Resource Requests vs Limits

**Requests**: Scheduling guarantee
**Limits**: Runtime enforcement

```yaml
resources:
  requests:
    cpu: "500m"      # Scheduler finds node with ≥500m free
    memory: "512Mi"  # Scheduler finds node with ≥512Mi free
  limits:
    cpu: "1000m"     # Cgroup quota set to 1 core
    memory: "1Gi"    # OOM kill at 1Gi
```

**CPU: Compressible Resource**
- Exceeding limit → Throttling (process slowed)
- No process killed

**Memory: Non-Compressible Resource**
- Exceeding limit → OOM Kill (process terminated)
- Pod restart

**Best Practice**:
```yaml
# Latency-sensitive (API servers)
requests:
  cpu: "1000m"
  memory: "1Gi"
limits:
  cpu: "2000m"      # Allow bursting
  memory: "1Gi"     # Hard limit to prevent OOM

# Batch jobs
requests:
  cpu: "500m"
  memory: "512Mi"
limits:
  cpu: "500m"       # No bursting needed
  memory: "2Gi"     # Allow memory growth
```

### 2.3 Horizontal Pod Autoscaler (HPA)

**Metrics Pipeline**:
```
1. Metrics Server scrapes kubelet (cAdvisor)
2. HPA controller queries Metrics API
3. HPA calculates: desiredReplicas = ceil(currentReplicas * (currentMetric / targetMetric))
4. HPA updates Deployment replicas
```

**Example**:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**Calculation**:
```
Current: 3 replicas, 90% CPU utilization
Desired: ceil(3 * (90 / 70)) = ceil(3.86) = 4 replicas
```

**Critical Pitfall: Thrashing**

If scale-up takes 2 minutes but scale-down is instant:
1. Load spike → HPA scales to 10 pods
2. Load drops → HPA scales to 2 pods immediately
3. Pods terminating, load spikes again → HPA scales to 10
4. Repeat

**Solution**: Configure stabilization window
```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300  # Wait 5min before scaling down
    policies:
    - type: Percent
      value: 50
      periodSeconds: 60  # Max 50% reduction per minute
```

---

## 3. AKS Automatic Architecture

### 3.1 Control Plane Differences

**Standard AKS**:
- You manage node pools
- You configure VM sizes
- You handle OS updates

**AKS Automatic**:
- Azure manages nodes (Karpenter-like provisioning)
- Nodes created on-demand based on pod requests
- Automatic OS patching, no node pool management

**Under the Hood: Node Provisioning**

```
1. Pod created with requests: cpu=2, memory=4Gi
2. No existing node has capacity
3. AKS Automatic calculates: Need VM with ≥2 CPU, ≥4Gi RAM
4. Azure provisions VM (e.g., Standard_D2s_v3)
5. Node joins cluster
6. Pod scheduled to new node
```

**Bin-Packing Optimization**: AKS Automatic tries to fit multiple pods on one node before creating new nodes.

### 3.2 Azure CNI Overlay Networking

**Traditional Azure CNI**:
- Each pod gets IP from VNet subnet
- Subnet exhaustion is a real problem (e.g., /24 = 256 IPs)

**Azure CNI Overlay**:
- Pods get IPs from private CIDR (e.g., 10.244.0.0/16)
- VXLAN encapsulation for pod-to-pod traffic
- Only nodes consume VNet IPs

**Packet Flow: Pod A → Pod B (Different Nodes)**

```
┌─────────────────────────────────────────────────────────────┐
│ Pod A (10.244.1.5)                                          │
│   └─> Send packet to 10.244.2.10                           │
└─────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│ Node 1 (172.16.1.10)                                        │
│   1. Packet hits veth pair                                  │
│   2. Routing table: 10.244.2.0/24 via VXLAN tunnel         │
│   3. Encapsulate: UDP packet to 172.16.1.11:4789           │
└─────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│ Azure VNet                                                  │
│   Routes UDP packet 172.16.1.10 → 172.16.1.11             │
└─────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│ Node 2 (172.16.1.11)                                        │
│   1. Receive UDP packet on port 4789                        │
│   2. Decapsulate: Extract inner packet (10.244.1.5→10.244.2.10)│
│   3. Route to Pod B's veth pair                             │
└─────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│ Pod B (10.244.2.10)                                         │
│   └─> Receives packet from 10.244.1.5                      │
└─────────────────────────────────────────────────────────────┘
```

**Performance Overhead**:
- Encapsulation/decapsulation: ~5-10% CPU overhead
- MTU reduction: 1500 → 1450 bytes (VXLAN header)

### 3.3 Workload Identity

**Traditional Approach** (Bad):
```yaml
env:
- name: AZURE_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: azure-creds
      key: client-secret
```
Problems: Secrets in etcd, rotation complexity, credential sprawl.

**Workload Identity** (Good):
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-sa
  annotations:
    azure.workload.identity/client-id: "12345678-1234-1234-1234-123456789abc"
---
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: api-sa
```

**Authentication Flow**:
```
1. Pod starts with ServiceAccount token mounted at /var/run/secrets/azure/tokens/azure-identity-token
2. Azure SDK reads token
3. SDK calls Azure AD: "Exchange this K8s token for Azure token"
4. Azure AD validates:
   - Token signature (from OIDC issuer)
   - ServiceAccount matches federated credential
5. Azure AD returns access token
6. SDK uses access token to call Azure services
```

**Why This Works**: AKS exposes an OIDC endpoint. Azure AD trusts this endpoint via federated identity credential.

---

## 4. Networking Deep Dive

### 4.1 Service Types & Load Balancing

#### ClusterIP: Internal Load Balancing

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  type: ClusterIP
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 8080
```

**What Happens**:
1. Service gets virtual IP (e.g., 10.0.100.50)
2. kube-proxy programs iptables rules on every node
3. Traffic to 10.0.100.50:80 is DNAT'd to pod IPs

**iptables Rules** (simplified):
```bash
# DNAT rule
-A KUBE-SERVICES -d 10.0.100.50/32 -p tcp --dport 80 -j KUBE-SVC-API

# Load balancing (random selection)
-A KUBE-SVC-API -m statistic --mode random --probability 0.33 -j KUBE-SEP-POD1
-A KUBE-SVC-API -m statistic --mode random --probability 0.50 -j KUBE-SEP-POD2
-A KUBE-SVC-API -j KUBE-SEP-POD3

# Endpoint rules
-A KUBE-SEP-POD1 -p tcp -j DNAT --to-destination 10.244.1.5:8080
-A KUBE-SEP-POD2 -p tcp -j DNAT --to-destination 10.244.1.6:8080
-A KUBE-SEP-POD3 -p tcp -j DNAT --to-destination 10.244.1.7:8080
```

**Load Balancing Algorithm**: Random selection with equal probability.

**Session Affinity**:
```yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800  # 3 hours
```

This adds iptables rule to hash client IP and stick to same backend.

#### LoadBalancer: External Access

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api-external
spec:
  type: LoadBalancer
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 8080
```

**What Happens**:
1. Cloud controller provisions Azure Load Balancer
2. Public IP assigned (e.g., 20.30.40.50)
3. Load balancer rules: 20.30.40.50:80 → Node IPs:NodePort
4. kube-proxy on nodes forwards NodePort → Pod IPs

**Traffic Flow**:
```
Internet → Azure LB (20.30.40.50:80) → Node (172.16.1.10:32000) → Pod (10.244.1.5:8080)
```

**Source IP Preservation**:
```yaml
spec:
  externalTrafficPolicy: Local  # Don't forward to other nodes
```

- **Cluster** (default): Traffic can hop to any node, source IP is SNAT'd
- **Local**: Traffic only goes to node with pod, source IP preserved

**Trade-off**: Local = better source IP, worse load distribution.

### 4.2 Ingress Controllers

**Ingress vs Service**:
- Service: L4 (TCP/UDP) load balancing
- Ingress: L7 (HTTP/HTTPS) routing

**NGINX Ingress Architecture**:
```
┌──────────────────────────────────────────────────────────┐
│ Azure Load Balancer (Public IP)                          │
└──────────────────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────────────────┐
│ NGINX Ingress Controller Pod                             │
│   - Watches Ingress resources                            │
│   - Generates nginx.conf                                 │
│   - Reloads NGINX                                        │
└──────────────────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────────────────┐
│ Backend Services (ClusterIP)                             │
│   api-service:80 → api pods                             │
│   web-service:80 → web pods                             │
└──────────────────────────────────────────────────────────┘
```

**Ingress Resource**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /v1
        pathType: Prefix
        backend:
          service:
            name: api-v1
            port:
              number: 80
      - path: /v2
        pathType: Prefix
        backend:
          service:
            name: api-v2
            port:
              number: 80
```

**Generated nginx.conf** (simplified):
```nginx
server {
  listen 80;
  server_name api.example.com;
  
  location /v1 {
    proxy_pass http://api-v1-upstream;
  }
  
  location /v2 {
    proxy_pass http://api-v2-upstream;
  }
}

upstream api-v1-upstream {
  server 10.244.1.5:8080;
  server 10.244.1.6:8080;
}
```

**Advanced: Rate Limiting**
```yaml
annotations:
  nginx.ingress.kubernetes.io/limit-rps: "10"  # 10 requests/sec per IP
```

Translates to:
```nginx
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req zone=api burst=20 nodelay;
```

### 4.3 DNS Resolution

**CoreDNS Architecture**:
```
Pod → /etc/resolv.conf → CoreDNS Service (10.0.0.10) → CoreDNS Pods
```

**/etc/resolv.conf** in pod:
```
nameserver 10.0.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

**DNS Query Flow**:
```
1. App queries "api"
2. Resolver tries: api.default.svc.cluster.local (ndots=5 means try search domains first)
3. CoreDNS responds with ClusterIP
4. App connects to ClusterIP
```

**ndots Pitfall**:

Query for `google.com`:
1. Try `google.com.default.svc.cluster.local` (NXDOMAIN)
2. Try `google.com.svc.cluster.local` (NXDOMAIN)
3. Try `google.com.cluster.local` (NXDOMAIN)
4. Try `google.com` (SUCCESS)

**Result**: 4 DNS queries instead of 1!

**Solution**: Use FQDN with trailing dot:
```python
# Bad
requests.get("https://google.com")

# Good
requests.get("https://google.com.")  # Trailing dot = absolute domain
```

**NodeLocal DNSCache**:

AKS Automatic runs a DNS cache on every node (169.254.20.10):
```
Pod → NodeLocal DNS (169.254.20.10) → CoreDNS (if cache miss)
```

**Benefits**:
- Reduced CoreDNS load
- Lower latency (local cache)
- Resilience (cache survives CoreDNS restart)

---

## 5. Storage & Persistence

### 5.1 Volume Types

#### emptyDir: Ephemeral Storage
```yaml
volumes:
- name: cache
  emptyDir: {}
```

**Lifecycle**: Created when pod starts, deleted when pod terminates.

**Use Cases**:
- Temporary cache
- Scratch space for processing
- Shared volume between containers in same pod

**Storage Backend**: Node's root disk (or tmpfs if `emptyDir.medium: Memory`).

#### PersistentVolumeClaim: Durable Storage

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: managed-csi
  resources:
    requests:
      storage: 10Gi
```

**Provisioning Flow**:
```
1. PVC created
2. CSI provisioner watches for PVC
3. Provisioner calls Azure API: Create Managed Disk (10Gi)
4. Disk created, PersistentVolume object created
5. PVC bound to PV
6. Pod scheduled, kubelet calls CSI driver
7. CSI driver attaches disk to node
8. CSI driver mounts disk to pod
```

**Access Modes**:
- **ReadWriteOnce (RWO)**: One node can mount read-write
- **ReadOnlyMany (ROX)**: Multiple nodes can mount read-only
- **ReadWriteMany (RWX)**: Multiple nodes can mount read-write (requires Azure Files, not Disk)

**Storage Classes**:

| Class | Backend | Performance | Use Case |
|-------|---------|-------------|----------|
| **managed-csi** | Azure Managed Disk (Standard SSD) | ~500 IOPS | General purpose |
| **managed-csi-premium** | Premium SSD | ~5000 IOPS | Databases |
| **azurefile-csi** | Azure Files (SMB) | Variable | ReadWriteMany |

### 5.2 StatefulSets: Stable Storage

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
spec:
  serviceName: database
  replicas: 3
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: db
        image: postgres:15
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 20Gi
```

**What Happens**:
1. StatefulSet creates pods: `database-0`, `database-1`, `database-2`
2. For each pod, creates PVC: `data-database-0`, `data-database-1`, `data-database-2`
3. PVCs persist even if pod is deleted
4. New pod `database-0` reattaches to `data-database-0`

**Stable Network Identity**:
- Pod `database-0` always gets DNS name `database-0.database.default.svc.cluster.local`
- Even after restart, same DNS name

**Ordered Deployment**:
- Pods created sequentially: 0, then 1, then 2
- Pod N+1 waits for Pod N to be Running and Ready

---

## 6. Helm: Templating & Release Management

### 6.1 Templating Engine

Helm uses Go templates with Sprig functions.

**Basic Templating**:
```yaml
# values.yaml
replicaCount: 3
image:
  repository: myapp
  tag: v1.2.3

# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-app
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
      - name: app
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
```

**Advanced: Conditionals**:
```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Release.Name }}-ingress
spec:
  rules:
  {{- range .Values.ingress.hosts }}
  - host: {{ .host }}
    http:
      paths:
      {{- range .paths }}
      - path: {{ .path }}
        backend:
          service:
            name: {{ $.Release.Name }}-app
            port:
              number: {{ .port }}
      {{- end }}
  {{- end }}
{{- end }}
```

**Critical: Whitespace Control**:
- `{{-`: Trim whitespace before
- `-}}`: Trim whitespace after

Without trimming, you get invalid YAML indentation.

### 6.2 Release Management

**Helm Releases** are stored as Secrets in Kubernetes:
```bash
kubectl get secrets -n default -l owner=helm
```

Each release contains:
- Manifest (rendered YAML)
- Values used
- Chart metadata
- Release status

**Upgrade Process**:
```
1. helm upgrade myapp ./chart --values prod.yaml
2. Helm renders templates with new values
3. Helm compares new manifest with previous release
4. Helm applies diff to cluster (kubectl apply)
5. Helm creates new release secret (revision 2)
```

**Rollback**:
```bash
helm rollback myapp 1  # Rollback to revision 1
```

Helm retrieves revision 1 manifest and applies it.

**Hooks**: Execute actions at specific points:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  annotations:
    "helm.sh/hook": pre-upgrade
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: myapp:v2
        command: ["./migrate"]
      restartPolicy: Never
```

**Hook Lifecycle**:
1. `pre-upgrade` hook runs
2. Wait for hook to complete
3. Upgrade proceeds
4. `post-upgrade` hook runs

---

## 7. ArgoCD: GitOps Reconciliation

### 7.1 Reconciliation Loop

ArgoCD runs a continuous loop:
```
1. Fetch desired state from Git
2. Render manifests (helm template / kustomize build)
3. Compare with live state in cluster
4. If different, sync (kubectl apply)
5. Sleep 3 minutes (default)
6. Repeat
```

**Application CRD**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo
    targetRevision: main
    path: charts/myapp
    helm:
      valueFiles:
      - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Sync Strategies**:
- **Manual**: Operator clicks "Sync" in UI
- **Automated**: ArgoCD syncs on every Git commit
- **Prune**: Delete resources not in Git
- **Self-Heal**: Revert manual kubectl changes

### 7.2 Sync Waves & Hooks

**Problem**: Database schema must exist before app starts.

**Solution**: Sync Waves
```yaml
# 1-schema.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: schema-migration
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # Run first
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: flyway
        command: ["flyway", "migrate"]
      restartPolicy: Never

# 2-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # Run after wave -1
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:v2
```

**Execution Order**:
1. Wave -1: schema-migration Job runs
2. ArgoCD waits for Job to complete
3. Wave 0: app Deployment created

**Hooks** (similar to Helm):
```yaml
annotations:
  argocd.argoproj.io/hook: PreSync
  argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

### 7.3 App of Apps Pattern

**Problem**: Managing 50 microservices = 50 Application CRDs.

**Solution**: App of Apps
```yaml
# apps/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/org/gitops
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated: {}
```

**Directory Structure**:
```
gitops/
├── apps/
│   ├── api.yaml          # Application CRD for api
│   ├── web.yaml          # Application CRD for web
│   └── database.yaml     # Application CRD for database
└── charts/
    ├── api/
    ├── web/
    └── database/
```

**Result**: One root Application manages all child Applications.

---

## 8. Production Patterns & Anti-Patterns

### 8.1 Resource Management

#### ✅ Pattern: Vertical Pod Autoscaler (VPA) for Right-Sizing

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: api-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  updatePolicy:
    updateMode: "Auto"  # Restart pods with new requests/limits
```

VPA analyzes actual usage and adjusts requests/limits.

#### ❌ Anti-Pattern: No Resource Limits

```yaml
# Bad: No limits
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
```

**Problem**: Pod can consume entire node's resources, starving other pods.

**Solution**: Set limits
```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

### 8.2 Health Checks

#### ✅ Pattern: Separate Liveness and Readiness

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 2
```

**Liveness**: "Is the app deadlocked?" (Kills pod if fails)
**Readiness**: "Can the app serve traffic?" (Removes from Service if fails)

**Implementation**:
```python
# /healthz - Liveness
@app.route('/healthz')
def healthz():
    # Simple check: Is the process alive?
    return 'OK', 200

# /ready - Readiness
@app.route('/ready')
def ready():
    # Check dependencies
    if not db.is_connected():
        return 'DB not ready', 503
    if not cache.is_connected():
        return 'Cache not ready', 503
    return 'OK', 200
```

#### ❌ Anti-Pattern: Same Endpoint for Both

```yaml
# Bad: Same probe
livenessProbe:
  httpGet:
    path: /health
readinessProbe:
  httpGet:
    path: /health
```

**Problem**: If DB is down, readiness fails (good), but liveness also fails (bad) → Pod killed → Restart loop.

### 8.3 Graceful Shutdown

#### ✅ Pattern: PreStop Hook + SIGTERM Handling

```yaml
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 15"]
```

**Shutdown Flow**:
```
1. kubectl delete pod
2. Pod marked Terminating
3. Removed from Service endpoints (no new traffic)
4. preStop hook runs (sleep 15s to drain connections)
5. SIGTERM sent to container
6. App gracefully closes connections
7. After 30s (terminationGracePeriodSeconds), SIGKILL sent
```

**Application Code**:
```python
import signal
import sys

def sigterm_handler(signum, frame):
    print("SIGTERM received, shutting down...")
    # Close DB connections
    db.close()
    # Stop accepting new requests
    server.shutdown()
    sys.exit(0)

signal.signal(signal.SIGTERM, sigterm_handler)
```

#### ❌ Anti-Pattern: Ignoring SIGTERM

**Problem**: App doesn't handle SIGTERM → Waits 30s → SIGKILL → Connections dropped mid-request.

### 8.4 Configuration Management

#### ✅ Pattern: ConfigMap + Secret + Workload Identity

```yaml
# ConfigMap for non-sensitive config
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: "info"
  API_TIMEOUT: "30s"

# Secret for sensitive config (encrypted at rest)
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
data:
  DB_PASSWORD: cGFzc3dvcmQxMjM=  # base64

# Deployment
spec:
  template:
    spec:
      serviceAccountName: app-sa  # Workload Identity
      containers:
      - name: app
        envFrom:
        - configMapRef:
            name: app-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: DB_PASSWORD
```

**Best Practice**: Use Azure Key Vault CSI driver for secrets:
```yaml
volumes:
- name: secrets
  csi:
    driver: secrets-store.csi.k8s.io
    readOnly: true
    volumeAttributes:
      secretProviderClass: "azure-keyvault"
```

#### ❌ Anti-Pattern: Hardcoded Secrets in Image

```dockerfile
# Bad: Secret in Dockerfile
ENV DB_PASSWORD=password123
```

**Problem**: Secret in image layer, visible to anyone with image access.

### 8.5 Observability

#### ✅ Pattern: Structured Logging + Distributed Tracing

```python
import logging
import json

# Structured logging
logger = logging.getLogger(__name__)
logger.info(json.dumps({
    "event": "request_processed",
    "user_id": 12345,
    "duration_ms": 45,
    "status": 200
}))
```

**Benefits**:
- Parseable by log aggregators (Azure Monitor)
- Queryable: `status:500 AND duration_ms:>1000`

**Distributed Tracing** (OpenTelemetry):
```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("process_order"):
    # Span automatically includes trace_id, span_id
    result = process_order(order_id)
```

**Trace Flow**:
```
API Gateway (trace_id: abc123)
  └─> Order Service (span_id: 001)
      └─> Payment Service (span_id: 002)
          └─> Database (span_id: 003)
```

All logs include `trace_id: abc123` → Correlate entire request flow.

---

## Summary: Key Takeaways

1. **Containers are kernel primitives**: Understand namespaces, cgroups, and OverlayFS to debug low-level issues.

2. **Resource requests are scheduling guarantees**: Set them accurately to avoid bin-packing failures.

3. **CPU is compressible, memory is not**: CPU throttling slows apps, memory limits kill them.

4. **Networking is layered**: Pod → Service (iptables) → Ingress (L7) → LoadBalancer (L4).

5. **Helm is a rendering engine**: Master Go templates and understand 3-way merge.

6. **ArgoCD is a reconciler**: Git is source of truth, cluster state converges to Git.

7. **Production requires discipline**: Health checks, graceful shutdown, structured logging, and resource limits are non-negotiable.

---

**This document is a living reference. Bookmark it, annotate it, and revisit it when debugging production issues.**
