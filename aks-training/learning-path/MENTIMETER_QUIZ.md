# AKS Training — Mentimeter Quiz (139-char limit, Basic Level)

> ✅ = Correct answer (facilitator reference only — do not display to participants)  
> All questions and options are within the 139-character Mentimeter limit.

---

## Module 1: Containers

---

### Q1
**What file tells Docker how to build a container image?**

- A) Makefile
- B) docker-compose.yml
- ✅ C) Dockerfile
- D) values.yaml

---

### Q2
**What does a .dockerignore file do?**

- A) It lists required Docker plugins
- ✅ B) It stops unnecessary files from entering the Docker build context
- C) It defines the container startup command
- D) It sets environment variables inside the container

---

### Q3
**In Docker, each instruction in a Dockerfile creates a what?**

- A) A volume
- B) A namespace
- ✅ C) A layer
- D) A container

---

## Module 2: Kubernetes Basics

---

### Q4
**What is the smallest deployable unit in Kubernetes?**

- A) Container
- ✅ B) Pod
- C) Deployment
- D) Node

---

### Q5
**What Kubernetes resource gives a set of Pods a stable network address?**

- A) Ingress
- ✅ B) Service
- C) ConfigMap
- D) ReplicaSet

---

### Q6
**What is the purpose of a liveness probe in Kubernetes?**

- A) To expose the Pod to external traffic
- ✅ B) To detect if a container is hung and restart it
- C) To stop traffic reaching an unready Pod
- D) To set resource limits on the container

---

## Module 3: Helm

---

### Q7
**Which file in a Helm chart defines the chart name and version?**

- A) values.yaml
- ✅ B) Chart.yaml
- C) _helpers.tpl
- D) NOTES.txt

---

### Q8
**What is the purpose of values.yaml in a Helm chart?**

- ✅ A) It provides default configuration values for chart templates
- B) It stores Kubernetes secrets encrypted
- C) It defines the Kubernetes API version to use
- D) It installs chart dependencies automatically

---

### Q9
**How do you deploy the same Helm chart to Dev and Prod with different settings?**

- A) Create a separate chart for each environment
- ✅ B) Use a base values.yaml and override with values-dev.yaml or values-prod.yaml
- C) Edit the Dockerfile for each environment
- D) Use kubectl apply with different namespaces only

---

## Module 4: ArgoCD & GitOps

---

### Q10
**What is the core principle of GitOps?**

- A) Developers manually run kubectl to deploy
- B) CI pipelines rebuild containers on every commit
- ✅ C) Git is the single source of truth for what runs in the cluster
- D) All changes require approval from the operations team

---

### Q11
**What does ArgoCD do when it detects a change in Git?**

- A) It rebuilds the container image
- B) It sends an email to the operations team
- ✅ C) It syncs the cluster to match the desired state in Git
- D) It runs unit tests on the changed code

---

### Q12
**Where must an ArgoCD Application resource always be deployed?**

- A) The default namespace
- B) The production namespace
- ✅ C) The argocd namespace
- D) The kube-system namespace

---

## Module 5: Production Patterns

---

### Q13
**What does a Horizontal Pod Autoscaler (HPA) do?**

- A) Adds more nodes to the cluster when disk is full
- ✅ B) Automatically scales the number of Pod replicas based on metrics
- C) Increases memory limits on running containers
- D) Restarts failed Pods automatically

---

### Q14
**Which tool in the observability stack collects and stores metrics?**

- A) Grafana
- B) AlertManager
- ✅ C) Prometheus
- D) Fluent Bit

---

### Q15
**What does a PodDisruptionBudget (PDB) protect against?**

- A) Pods consuming too much CPU during peak traffic
- B) Unauthorised access to the Kubernetes API
- ✅ C) All replicas being evicted at once during node maintenance
- D) Container images being pulled from untrusted registries

---

## Quick Reference Table

| Q | Module | Question Topic | Answer |
|---|--------|---------------|--------|
| 1 | Containers | What file builds an image | C) Dockerfile |
| 2 | Containers | .dockerignore purpose | B) Stops unnecessary files |
| 3 | Containers | Dockerfile instructions create | C) A layer |
| 4 | Kubernetes | Smallest deployable unit | B) Pod |
| 5 | Kubernetes | Stable network address for Pods | B) Service |
| 6 | Kubernetes | Liveness probe purpose | B) Detect hung container |
| 7 | Helm | Chart name & version file | B) Chart.yaml |
| 8 | Helm | values.yaml purpose | A) Default config values |
| 9 | Helm | Multi-environment deployment | B) Override values files |
| 10 | ArgoCD | Core GitOps principle | C) Git = source of truth |
| 11 | ArgoCD | What ArgoCD does on Git change | C) Syncs cluster to Git |
| 12 | ArgoCD | Where Application resource lives | C) argocd namespace |
| 13 | Production | HPA purpose | B) Scales Pod replicas |
| 14 | Production | Collects and stores metrics | C) Prometheus |
| 15 | Production | PDB protects against | C) Mass eviction on drain |
