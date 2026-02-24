# AKS Training — Mentimeter Quiz

> **Format:** Copy each question + options directly into Mentimeter (Multiple Choice).  
> ✅ = Correct answer — do NOT show this marker to participants; it is for your reference only.  
> Each module has: 🟢 Basic · 🟡 Intermediate · 🔴 Advanced

---

## Module 1: Containers

---

### Q1 🟢 BASIC

**What is the primary purpose of a Dockerfile?**

- A) To configure the AKS cluster networking
- B) To define a database schema for your application
- ✅ C) To provide a recipe of instructions for building a container image
- D) To manage Kubernetes namespaces and resources

---

### Q2 🟡 INTERMEDIATE

**In a Dockerfile, why should you copy the dependency manifest (e.g. `.csproj` or `requirements.txt`) BEFORE copying the full application source code?**

- A) Because Kubernetes requires dependency files to be listed first
- ✅ B) So Docker can cache the expensive dependency install step and reuse it on future builds when only source code changes
- C) Because the application cannot start without dependencies already on the filesystem
- D) It does not matter — Docker processes all COPY instructions in parallel

---

### Q3 🔴 ADVANCED

**A .NET application's Docker image built with a single-stage Dockerfile using `mcr.microsoft.com/dotnet/sdk:8.0` weighs 750MB. After switching to a multi-stage build using `mcr.microsoft.com/dotnet/aspnet:8.0-alpine` as the final stage, what is the expected approximate size?**

- A) 650MB — Alpine only saves around 15%
- B) 500MB — the SDK tools are partially removed
- ✅ C) 120–220MB — the final stage contains only the runtime and compiled output, not the SDK
- D) 50MB — Alpine removes all .NET dependencies

---

## Module 2: Kubernetes Basics

---

### Q4 🟢 BASIC

**What is the smallest deployable unit in Kubernetes?**

- A) A Container
- ✅ B) A Pod
- C) A Deployment
- D) A Node

---

### Q5 🟡 INTERMEDIATE

**A Service with the selector `app: myapp` is not routing traffic to any Pods. The Pods are Running. What is the most likely cause?**

- A) The Service type is set to ClusterIP instead of LoadBalancer
- B) The namespace does not have a NetworkPolicy
- ✅ C) The Pod labels do not match the Service selector — e.g. the Pods have `app: my-app` (with a hyphen)
- D) The Deployment does not have a readiness probe configured

---

### Q6 🔴 ADVANCED

**A Java application takes 60 seconds to start. With only a liveness probe set to `periodSeconds: 10` and `failureThreshold: 3`, what happens?**

- A) Kubernetes waits indefinitely for the probe to succeed before sending traffic
- B) The Pod starts successfully because liveness probes do not run during startup
- ✅ C) Kubernetes kills and restarts the container after 30 seconds (3 failures × 10s) — before the app finishes booting
- D) The Pod enters a Pending state until the probe succeeds

---

## Module 3: Helm

---

### Q7 🟢 BASIC

**Which file in a Helm chart defines the chart's name, version, and description?**

- A) `values.yaml`
- B) `templates/deployment.yaml`
- ✅ C) `Chart.yaml`
- D) `_helpers.tpl`

---

### Q8 🟡 INTERMEDIATE

**You need to deploy the same Helm chart to Dev (1 replica, 100m CPU) and Production (5 replicas, 500m CPU). What is the correct Helm approach?**

- A) Create two separate Helm charts — one for Dev, one for Production
- B) Edit the `values.yaml` file directly before each deployment
- ✅ C) Use a single chart with a base `values.yaml` and override with `values-dev.yaml` and `values-prod.yaml` at install time
- D) Use Helm hooks to detect the environment and adjust replicas automatically

---

### Q9 🔴 ADVANCED

**In a Helm chart, the `_helpers.tpl` file defines `myapp.selectorLabels`. This same function is referenced in both `deployment.yaml` and `service.yaml`. Why is this the correct pattern rather than hardcoding labels in each template?**

- A) Helm requires all labels to be defined in `_helpers.tpl` — it will not render templates otherwise
- B) It reduces file size by storing labels in only one location
- ✅ C) It ensures the Deployment's Pod selector and the Service's pod selector are always identical — preventing traffic routing failures caused by label drift between templates
- D) It allows Helm to automatically update labels when the chart version changes

---

## Module 4: ArgoCD & GitOps

---

### Q10 🟢 BASIC

**What is the core GitOps principle that ArgoCD enforces?**

- A) All deployments must be approved by two senior engineers before syncing
- B) Container images must be built inside the Kubernetes cluster
- ✅ C) Git is the single source of truth — the cluster state is continuously reconciled to match what is declared in Git
- D) All Kubernetes resources must be written in JSON, not YAML

---

### Q11 🟡 INTERMEDIATE

**In an ArgoCD Application manifest, what does setting `syncPolicy.automated.prune: true` do?**

- A) It automatically creates new namespaces when deploying to a new environment
- B) It removes old container images from the container registry after deployment
- ✅ C) It deletes Kubernetes resources from the cluster when they are removed from the Git repository
- D) It prunes old Helm chart versions from the release history

---

### Q12 🔴 ADVANCED

**You have 40 microservices, each requiring its own ArgoCD Application manifest. What pattern removes the need to manually `kubectl apply` each Application, and how does it work?**

- A) ApplicationSet with a cluster generator — it creates Applications for each registered cluster automatically
- ✅ B) App of Apps — one root Application watches the `apps/` directory in Git; adding a new Application YAML file to that directory causes ArgoCD to automatically register and sync it
- C) ArgoCD Projects — a Project contains child Applications and deploys them all in sequence
- D) Sync Waves — each Application is assigned a wave number and ArgoCD deploys them in order

---

## Module 5: Production Patterns

---

### Q13 🟢 BASIC

**A Horizontal Pod Autoscaler (HPA) is configured but shows `<unknown>` for current CPU utilisation and never scales. What is the most likely cause?**

- A) The HPA requires a minimum of 3 replicas to begin functioning
- B) ArgoCD has not synced the HPA manifest to the cluster yet
- ✅ C) The target Deployment's Pods do not have `resources.requests.cpu` defined — the HPA cannot calculate utilisation without a baseline
- D) The Prometheus adapter is not installed in the cluster

---

### Q14 🟡 INTERMEDIATE

**What is the role of a `ServiceMonitor` resource in a cluster with the `kube-prometheus-stack` installed?**

- A) It monitors the health of Kubernetes Services and restarts them if they become unresponsive
- B) It defines Prometheus alert rules for high error rates and latency
- ✅ C) It tells the Prometheus Operator which application Pods to scrape for metrics, and on which port and path
- D) It creates a Grafana dashboard automatically when a new Service is deployed

---

### Q15 🔴 ADVANCED

**AKS is performing a routine node upgrade and begins draining nodes. Your Deployment has 3 replicas and no `PodDisruptionBudget`. What is the risk, and how does a PDB with `minAvailable: 2` address it?**

- A) Without a PDB, the node drain fails with an error. A PDB with `minAvailable: 2` allows the drain to proceed by forcing a scale-up first
- B) There is no risk — Kubernetes always respects replica count during node drains
- ✅ C) Without a PDB, Kubernetes can evict all 3 replicas simultaneously during the drain, causing complete downtime. A PDB with `minAvailable: 2` forces Kubernetes to keep at least 2 replicas running at all times, so only 1 can be evicted at a time
- D) A PDB with `minAvailable: 2` prevents the drain entirely until the engineer manually approves it

---

## Quick Reference for Mentimeter Setup

| # | Module | Level | Topic |
|---|--------|-------|-------|
| Q1 | Containers | 🟢 Basic | What is a Dockerfile |
| Q2 | Containers | 🟡 Intermediate | Layer caching order |
| Q3 | Containers | 🔴 Advanced | Multi-stage build image size |
| Q4 | Kubernetes | 🟢 Basic | Smallest deployable unit |
| Q5 | Kubernetes | 🟡 Intermediate | Service selector mismatch |
| Q6 | Kubernetes | 🔴 Advanced | Startup probe vs liveness probe |
| Q7 | Helm | 🟢 Basic | Chart.yaml purpose |
| Q8 | Helm | 🟡 Intermediate | Multi-environment values files |
| Q9 | Helm | 🔴 Advanced | _helpers.tpl selector consistency |
| Q10 | ArgoCD | 🟢 Basic | GitOps core principle |
| Q11 | ArgoCD | 🟡 Intermediate | prune: true behaviour |
| Q12 | ArgoCD | 🔴 Advanced | App of Apps pattern |
| Q13 | Production | 🟢 Basic | HPA unknown utilisation |
| Q14 | Production | 🟡 Intermediate | ServiceMonitor role |
| Q15 | Production | 🔴 Advanced | PodDisruptionBudget during drain |
