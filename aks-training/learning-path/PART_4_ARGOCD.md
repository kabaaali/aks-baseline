# Learning Path Part 4: ArgoCD Deep Dive

> **Goal:** Master GitOps with ArgoCD for automated, Git-driven deployments

---

## 🏗️ Foundational Structure: What You Need and Why

GitOps is not just a tool — it is a **philosophy backed by a repository structure**. ArgoCD enforces this philosophy by treating your Git repository as the single source of truth for everything running in your cluster. If it's not in Git, it doesn't exist. If it's in Git, ArgoCD will make it exist in the cluster.

To make this work, you need to understand **two things**: the structure of the GitOps repository, and the structure of the ArgoCD Application resource that connects that repository to your cluster.

### The GitOps Repository Layout

```
gitops-repo/                          # One repository = one source of truth
├── apps/                             # ArgoCD Application manifests ("what to deploy where")
│   ├── root.yaml                     # The "App of Apps" — bootstraps everything else
│   ├── api-service.yaml              # ArgoCD Application for api-service
│   ├── web-frontend.yaml             # ArgoCD Application for web-frontend
│   └── monitoring.yaml              # ArgoCD Application for monitoring stack
├── charts/                           # Helm charts for each service
│   ├── api-service/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   └── web-frontend/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
└── environments/                     # Per-environment Helm value overrides
    ├── dev/
    │   ├── api-service-values.yaml
    │   └── web-frontend-values.yaml
    ├── staging/
    └── prod/
```

This structure is **not arbitrary**. Separating `apps/` (ArgoCD Application manifests) from `charts/` (Helm packages) from `environments/` (value overrides) means:

- Application engineers own `charts/` — they define what the service deploys
- Platform engineers own `apps/` — they control where and how it syncs
- Release managers own `environments/` — they control what version goes where

### The ArgoCD Application CRD: The Connective Tissue

ArgoCD introduces a new Kubernetes resource called an **Application** (`kind: Application`, `apiVersion: argoproj.io/v1alpha1`). This is the core object that wires your Git repository to a cluster namespace. Every Application has four essential sections:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: api-service          # Identity of this deployment unit in ArgoCD
  namespace: argocd          # ALWAYS in the argocd namespace
spec:
  project: default           # Which ArgoCD Project controls access (RBAC boundary)

  source:                    # WHERE is the desired state? (Git)
    repoURL: https://github.com/org/gitops-repo
    targetRevision: main     # Branch, tag, or commit SHA
    path: charts/api-service # Path within the repository

  destination:               # WHERE to deploy? (Cluster + Namespace)
    server: https://kubernetes.default.svc
    namespace: production

  syncPolicy:                # HOW to sync? (manual vs automated)
    automated:
      prune: true            # Delete resources removed from Git
      selfHeal: true         # Revert manual kubectl changes
```

| Section | Role | Why Necessary |
|---------|------|---------------|
| `metadata.namespace: argocd` | Places the Application resource in ArgoCD's own namespace | ArgoCD's controller only watches its own namespace — Applications placed elsewhere are invisible |
| `spec.project` | Assigns the app to an ArgoCD Project for RBAC and access control | Without projects, all applications share the same permissions — a breach in one app affects all |
| `spec.source` | Tells ArgoCD's Repo Server where to fetch and render manifests | Without this, ArgoCD has no desired state to reconcile against |
| `spec.destination` | Tells ArgoCD's Application Controller where to apply manifests | Without this, ArgoCD doesn't know which cluster/namespace to target |
| `syncPolicy.automated.prune: true` | Removes resources from the cluster when deleted from Git | Without it, deleted resources in Git silently persist in the cluster, creating configuration drift |
| `syncPolicy.automated.selfHeal: true` | Reverts any manual `kubectl` changes | Without it, out-of-band changes can break GitOps guarantees — Git is no longer the source of truth |

### Why the `argocd` Namespace Is a Foundational Requirement

ArgoCD's own components (API Server, Application Controller, Repo Server, Redis) all run in the `argocd` namespace. This namespace must be created **before** ArgoCD is installed. More importantly:

- All `Application` CRD resources must live in the `argocd` namespace
- ArgoCD secrets (repository credentials, cluster credentials) live here
- RBAC rules controlling which teams can deploy which applications are scoped here

**This is your control plane namespace.** Treat it with the same care as `kube-system`.

### The App of Apps: Why You Need a Bootstrap Pattern

Managing 20+ Application manifests manually doesn't scale. The **App of Apps pattern** solves this with one ArgoCD Application that watches the `apps/` directory in your GitOps repository. When you add a new `apps/new-service.yaml`, ArgoCD detects it and deploys the new Application automatically — no manual `kubectl apply` required.

```
One "root" Application (applied once, manually)
  └── Watches apps/ directory in Git
      ├── Reads api-service.yaml     → Creates Application "api-service"
      ├── Reads web-frontend.yaml    → Creates Application "web-frontend"
      └── Reads monitoring.yaml      → Creates Application "monitoring"
```

This means **onboarding a new microservice = creating one YAML file in Git**. Everything else — ArgoCD registration, syncing, monitoring — happens automatically.

### ArgoCD Projects: The Access Control Layer

An ArgoCD **Project** (not to be confused with Git projects) is an RBAC boundary that controls:

- Which Git repositories can be used as sources
- Which clusters and namespaces can be deployment targets
- Which Kubernetes resource types are allowed

Without Projects, every team can deploy to any namespace using any chart. With Projects, you can enforce that the `team-a` project can only deploy to the `team-a-prod` namespace from the `github.com/org/team-a` repository. This is **the mandatory security layer** before onboarding multiple teams onto a shared ArgoCD instance.

---

## 1. Create an Application

### Concept: What is ArgoCD?

ArgoCD is a **declarative, GitOps continuous delivery tool** for Kubernetes. It:
- Watches your Git repository
- Compares desired state (Git) with actual state (cluster)
- Automatically syncs differences
- Provides visibility into deployment status

**Core Principle:** Git is the single source of truth.

### ArgoCD Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Git Repository                                              │
│   ├── apps/                                                 │
│   │   └── myapp.yaml (ArgoCD Application)                  │
│   └── charts/                                               │
│       └── myapp/ (Helm Chart)                               │
└─────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│ ArgoCD Server                                               │
│   ├── Application Controller (reconciliation loop)         │
│   ├── Repo Server (renders manifests)                      │
│   └── API Server (UI & CLI)                                │
└─────────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│ Kubernetes Cluster                                          │
│   └── Deployed Applications                                │
└─────────────────────────────────────────────────────────────┘
```

### Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access UI: https://localhost:8080
# Username: admin
# Password: (from above command)
```

### Create Your First Application

**Method 1: Using UI**
1. Login to ArgoCD UI
2. Click "+ NEW APP"
3. Fill in details:
   - Application Name: `myapp`
   - Project: `default`
   - Sync Policy: `Manual`
   - Repository URL: `https://github.com/yourorg/yourrepo`
   - Path: `charts/myapp`
   - Cluster: `https://kubernetes.default.svc`
   - Namespace: `default`
4. Click "CREATE"

**Method 2: Using YAML (Recommended)**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  # Project (logical grouping)
  project: default
  
  # Source: Where is the desired state?
  source:
    repoURL: https://github.com/yourorg/yourrepo
    targetRevision: main
    path: charts/myapp
    
    # Helm-specific config
    helm:
      valueFiles:
      - values-prod.yaml
      parameters:
      - name: image.tag
        value: v1.2.3
  
  # Destination: Where to deploy?
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  
  # Sync Policy
  syncPolicy:
    automated:
      prune: true      # Delete resources not in Git
      selfHeal: true   # Revert manual changes
    syncOptions:
    - CreateNamespace=true
```

**Apply:**
```bash
kubectl apply -f myapp-application.yaml
```

### Application Structure Examples

**Example 1: Helm Chart**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: api-service
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/gitops
    targetRevision: HEAD
    path: charts/api-service
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

**Example 2: Plain Kubernetes Manifests**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/gitops
    targetRevision: main
    path: manifests/monitoring
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated: {}
```

**Example 3: Kustomize**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/gitops
    targetRevision: main
    path: kustomize/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: web
  syncPolicy:
    automated: {}
```

### Hands-On Exercise

**Step 1: Create Git Repository**
```bash
mkdir gitops-demo
cd gitops-demo
git init

# Create directory structure
mkdir -p apps charts/myapp/templates
```

**Step 2: Create Helm Chart**
```bash
# charts/myapp/Chart.yaml
cat > charts/myapp/Chart.yaml <<EOF
apiVersion: v2
name: myapp
version: 0.1.0
appVersion: "1.0.0"
EOF

# charts/myapp/values.yaml
cat > charts/myapp/values.yaml <<EOF
replicaCount: 2
image:
  repository: nginx
  tag: "1.25"
service:
  port: 80
EOF

# charts/myapp/templates/deployment.yaml
cat > charts/myapp/templates/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: nginx
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports:
        - containerPort: 80
EOF
```

**Step 3: Create ArgoCD Application**
```bash
cat > apps/myapp.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOURUSERNAME/gitops-demo
    targetRevision: main
    path: charts/myapp
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
```

**Step 4: Push to Git**
```bash
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/YOURUSERNAME/gitops-demo
git push -u origin main
```

**Step 5: Deploy to ArgoCD**
```bash
kubectl apply -f apps/myapp.yaml

# Watch sync status
argocd app get myapp --watch
```

### External Resources

**Official ArgoCD Docs:**
- Getting Started: https://argo-cd.readthedocs.io/en/stable/getting_started/
- Core Concepts: https://argo-cd.readthedocs.io/en/stable/core_concepts/

**ArgoCD Examples:**
- GitHub: https://github.com/argoproj/argocd-example-apps

---

## 2. Deploy via Git Commit

### The GitOps Workflow

```
Developer → Git Commit → ArgoCD Detects Change → Sync → Deployed
```

**No `kubectl` or `helm` commands needed!**

### Automated Deployment Example

**Scenario:** Update application to new version

**Step 1: Update values.yaml in Git**
```bash
cd gitops-demo

# Edit charts/myapp/values.yaml
cat > charts/myapp/values.yaml <<EOF
replicaCount: 3  # Changed from 2
image:
  repository: nginx
  tag: "1.26"    # Changed from 1.25
service:
  port: 80
EOF

# Commit and push
git add charts/myapp/values.yaml
git commit -m "Update nginx to 1.26 and scale to 3 replicas"
git push
```

**Step 2: ArgoCD Automatically Syncs**
```bash
# Watch ArgoCD detect and sync the change
argocd app get myapp --watch

# Or view in UI
# You'll see:
# - Status: Syncing
# - Health: Progressing
# - Then: Synced & Healthy
```

**Step 3: Verify Deployment**
```bash
kubectl get pods
# Should show 3 nginx pods with new image
```

### Manual Sync (When Automated is Disabled)

```yaml
# Application with manual sync
syncPolicy:
  syncOptions:
  - CreateNamespace=true
  # No automated section = manual sync required
```

**Sync via CLI:**
```bash
argocd app sync myapp
```

**Sync via UI:**
1. Navigate to application
2. Click "SYNC"
3. Select resources to sync
4. Click "SYNCHRONIZE"

### Sync Strategies

**1. Auto-Sync with Prune**
```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources not in Git
    selfHeal: true   # Revert manual kubectl changes
```

**2. Auto-Sync without Prune (Safer)**
```yaml
syncPolicy:
  automated:
    prune: false     # Keep manually created resources
    selfHeal: true
```

**3. Manual Sync Only**
```yaml
syncPolicy:
  syncOptions:
  - CreateNamespace=true
  # No automated section
```

### Sync Phases & Hooks

**Problem:** Database migration must run before app deployment.

**Solution:** Sync Waves

```yaml
# 1-migration.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # Run first
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: myapp:v2
        command: ["./migrate.sh"]
      restartPolicy: Never
---
# 2-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # Run after migration
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: app
        image: myapp:v2
```

**Execution Order:**
1. Wave -1: Migration job runs
2. ArgoCD waits for job completion
3. Wave 0: Deployment created

### Hands-On Exercise: GitOps Workflow

**Scenario: Deploy a new feature**

```bash
# 1. Create feature branch
git checkout -b feature/new-ui

# 2. Update application
cat > charts/myapp/values.yaml <<EOF
replicaCount: 3
image:
  repository: myapp
  tag: "v2.0.0-beta"  # New version
service:
  port: 8080
env:
  - name: FEATURE_FLAG_NEW_UI
    value: "true"
EOF

# 3. Commit and push
git add .
git commit -m "Enable new UI feature"
git push origin feature/new-ui

# 4. Create PR and merge to main

# 5. ArgoCD automatically deploys
# (Watch in UI or CLI)
```

### External Resources

**GitOps Principles:**
- OpenGitOps: https://opengitops.dev/
- Weaveworks GitOps Guide: https://www.weave.works/technologies/gitops/

**Industry Examples:**
- Intuit's GitOps Journey: https://www.intuit.com/blog/technology/gitops-at-intuit/
- Ticketmaster's ArgoCD: https://tech.ticketmaster.com/2020/12/01/gitops-at-ticketmaster/

---

## 3. Monitor Sync Status

### Application Health States

| State | Meaning | Action |
|-------|---------|--------|
| **Healthy** | All resources running correctly | ✅ None |
| **Progressing** | Deployment in progress | ⏳ Wait |
| **Degraded** | Some resources unhealthy | 🔍 Investigate |
| **Suspended** | Application suspended | ⏸️ Resume |
| **Missing** | Resources not found | 🚨 Check Git |
| **Unknown** | Cannot determine health | ❓ Check cluster |

### Sync States

| State | Meaning |
|-------|---------|
| **Synced** | Git == Cluster |
| **OutOfSync** | Git ≠ Cluster |
| **Unknown** | Cannot determine |

### Monitor via CLI

```bash
# List all applications
argocd app list

# Get application details
argocd app get myapp

# Watch sync status
argocd app wait myapp --health

# View sync history
argocd app history myapp

# View diff (Git vs Cluster)
argocd app diff myapp

# View logs
argocd app logs myapp
```

### Monitor via UI

**Dashboard View:**
- Application tiles showing health & sync status
- Color-coded: Green (Healthy), Yellow (Progressing), Red (Degraded)

**Application Detail View:**
- Resource tree (visual representation)
- Events timeline
- Sync history
- Logs

### Notifications & Alerts

**Install ArgoCD Notifications:**
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-notifications/stable/manifests/install.yaml
```

**Configure Slack Notifications:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  
  template.app-deployed: |
    message: |
      Application {{.app.metadata.name}} is now running new version.
    slack:
      attachments: |
        [{
          "title": "{{ .app.metadata.name}}",
          "title_link":"{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
          "color": "#18be52",
          "fields": [
          {
            "title": "Sync Status",
            "value": "{{.app.status.sync.status}}",
            "short": true
          },
          {
            "title": "Repository",
            "value": "{{.app.spec.source.repoURL}}",
            "short": true
          }
          ]
        }]
  
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-deployed]
```

**Subscribe Application to Notifications:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  annotations:
    notifications.argoproj.io/subscribe.on-deployed.slack: my-channel
spec:
  # ... rest of spec
```

### Prometheus Metrics

ArgoCD exposes Prometheus metrics:

```yaml
# ServiceMonitor for Prometheus Operator
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
```

**Key Metrics:**
- `argocd_app_info`: Application metadata
- `argocd_app_sync_total`: Sync count
- `argocd_app_health_status`: Health status (0=Unknown, 1=Progressing, 2=Healthy, 3=Suspended, 4=Degraded, 5=Missing)

### Hands-On: Monitoring Dashboard

**Create Grafana Dashboard:**

```bash
# Install Prometheus & Grafana (if not already)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Import ArgoCD dashboard
# Dashboard ID: 14584
# https://grafana.com/grafana/dashboards/14584
```

**Monitor Application:**
```bash
# Terminal 1: Watch app status
watch -n 2 'argocd app get myapp'

# Terminal 2: Trigger a change
cd gitops-demo
echo "# Update" >> charts/myapp/values.yaml
git add .
git commit -m "Trigger sync"
git push

# Watch ArgoCD detect and sync
```

### Troubleshooting Sync Issues

**Issue 1: OutOfSync but no changes in Git**

```bash
# Check diff
argocd app diff myapp

# Likely cause: Manual kubectl changes
# Solution: Let selfHeal revert, or update Git
```

**Issue 2: Sync Fails**

```bash
# View sync result
argocd app get myapp

# View detailed error
kubectl get application myapp -n argocd -o yaml

# Common causes:
# - Invalid YAML
# - RBAC permissions
# - Resource quotas exceeded
```

**Issue 3: Application Stuck in Progressing**

```bash
# Check pod status
kubectl get pods -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Common causes:
# - Image pull errors
# - Insufficient resources
# - Failed health checks
```

### External Resources

**ArgoCD Monitoring:**
- Metrics: https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/
- Notifications: https://argocd-notifications.readthedocs.io/

**Dashboards:**
- Grafana Dashboard: https://grafana.com/grafana/dashboards/14584

---

## Advanced Topics

### 1. App of Apps Pattern

**Problem:** Managing 50 microservices = 50 Application CRDs

**Solution:** One "root" app that manages all child apps

```yaml
# apps/root.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/gitops
    targetRevision: main
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated: {}
```

**Directory Structure:**
```
gitops/
├── apps/
│   ├── api-service.yaml
│   ├── web-frontend.yaml
│   ├── database.yaml
│   └── monitoring.yaml
└── charts/
    ├── api-service/
    ├── web-frontend/
    ├── database/
    └── monitoring/
```

### 2. Multi-Cluster Management

```yaml
# Add cluster
argocd cluster add my-prod-cluster

# Deploy to multiple clusters
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-prod
spec:
  destination:
    server: https://prod-cluster-api-server
    namespace: production
```

### 3. ApplicationSet (Dynamic Applications)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: microservices
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - name: api
        namespace: api
      - name: web
        namespace: web
      - name: worker
        namespace: worker
  template:
    metadata:
      name: '{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/myorg/gitops
        targetRevision: main
        path: 'charts/{{name}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'
      syncPolicy:
        automated: {}
```

---

## Summary: ArgoCD Mastery Checklist

✅ **Created:** ArgoCD Application pointing to Git repository
✅ **Deployed:** Application via Git commit (no kubectl needed)
✅ **Monitored:** Sync status via UI, CLI, and metrics

---

## Next Steps

➡️ **Next:** [Part 5: Production Patterns](PART_5_PRODUCTION_PATTERNS.md)

### Additional Practice

1. **Multi-Environment:** Set up Dev, Staging, Prod with different branches
2. **Rollback:** Practice reverting via `git revert`
3. **Secrets:** Integrate Sealed Secrets or External Secrets Operator
4. **Progressive Delivery:** Explore Argo Rollouts for canary deployments

### Community Resources

- **ArgoCD Slack:** https://argoproj.github.io/community/join-slack
- **ArgoCD GitHub:** https://github.com/argoproj/argo-cd
- **CNCF ArgoCD:** https://www.cncf.io/projects/argo/
