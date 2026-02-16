# Learning Path Part 3: Helm Deep Dive

> **Goal:** Master Helm for packaging, deploying, and managing Kubernetes applications

---

## 1. Create a Helm Chart

### Concept: What is a Helm Chart?

A Helm Chart is a package of Kubernetes manifests with templating. Think of it as:
- **npm package** for Node.js
- **pip package** for Python
- **Maven artifact** for Java

But for Kubernetes applications.

### Chart Structure

```
mychart/
├── Chart.yaml          # Metadata (name, version, description)
├── values.yaml         # Default configuration values
├── charts/             # Dependent charts
├── templates/          # Kubernetes manifest templates
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── _helpers.tpl    # Template helpers
│   └── NOTES.txt       # Post-install instructions
└── .helmignore         # Files to ignore
```

### Create Your First Chart

```bash
# Create a new chart
helm create myapp

# This generates the structure above
cd myapp
```

### Chart.yaml - Metadata

```yaml
apiVersion: v2
name: myapp
description: A Helm chart for my application
type: application
version: 0.1.0        # Chart version
appVersion: "1.0.0"   # Application version

# Optional: Dependencies
dependencies:
- name: postgresql
  version: "12.1.0"
  repository: "https://charts.bitnami.com/bitnami"
  condition: postgresql.enabled

# Optional: Maintainers
maintainers:
- name: Your Name
  email: you@example.com
```

### values.yaml - Configuration

```yaml
# Default values for myapp
replicaCount: 1

image:
  repository: myapp
  pullPolicy: IfNotPresent
  tag: ""  # Overrides appVersion

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: "nginx"
  hosts:
    - host: myapp.local
      paths:
        - path: /
          pathType: Prefix

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

### templates/deployment.yaml - Template

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "myapp.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /health
            port: http
        readinessProbe:
          httpGet:
            path: /ready
            port: http
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
```

### templates/_helpers.tpl - Reusable Functions

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "myapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "myapp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "myapp.labels" -}}
helm.sh/chart: {{ include "myapp.chart" . }}
{{ include "myapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

### Hands-On: Build a Real Chart

**Step 1: Create Chart**
```bash
helm create api-service
cd api-service
```

**Step 2: Customize values.yaml**
```yaml
replicaCount: 3

image:
  repository: myregistry.azurecr.io/api-service
  tag: "v1.2.3"

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: api.example.com
      paths:
        - path: /
          pathType: Prefix

resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

**Step 3: Validate**
```bash
# Lint the chart
helm lint .

# Dry-run (see generated YAML)
helm install api-service . --dry-run --debug

# Template (generate YAML without installing)
helm template api-service .
```

### External Resources

**Official Helm Docs:**
- Chart Template Guide: https://helm.sh/docs/chart_template_guide/
- Best Practices: https://helm.sh/docs/chart_best_practices/

**Helm Hub (Chart Repository):**
- Artifact Hub: https://artifacthub.io/

**Industry Examples:**
- Bitnami Charts: https://github.com/bitnami/charts
- Prometheus Community: https://github.com/prometheus-community/helm-charts

---

## 2. Deploy to Dev and Prod with Different Values

### The Problem: Environment-Specific Configuration

| Config | Dev | Prod |
|--------|-----|------|
| Replicas | 1 | 5 |
| CPU | 100m | 500m |
| Memory | 128Mi | 1Gi |
| Ingress Host | dev.example.com | api.example.com |
| Database | dev-db | prod-db |

### Solution: Multiple Values Files

**values-dev.yaml:**
```yaml
replicaCount: 1

image:
  tag: "latest"

ingress:
  enabled: true
  hosts:
    - host: dev.example.com
      paths:
        - path: /
          pathType: Prefix

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi

env:
  - name: ENVIRONMENT
    value: "development"
  - name: DB_HOST
    value: "dev-postgres.database.svc.cluster.local"
```

**values-prod.yaml:**
```yaml
replicaCount: 5

image:
  tag: "v1.2.3"  # Specific version, not latest

ingress:
  enabled: true
  hosts:
    - host: api.example.com
      paths:
        - path: /
          pathType: Prefix
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  tls:
    - secretName: api-tls
      hosts:
        - api.example.com

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi

autoscaling:
  enabled: true
  minReplicas: 5
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70

env:
  - name: ENVIRONMENT
    value: "production"
  - name: DB_HOST
    value: "prod-postgres.database.svc.cluster.local"
```

### Deploy to Different Environments

```bash
# Deploy to Dev
helm install api-service-dev ./api-service \
  --namespace dev \
  --create-namespace \
  --values ./api-service/values-dev.yaml

# Deploy to Prod
helm install api-service-prod ./api-service \
  --namespace prod \
  --create-namespace \
  --values ./api-service/values-prod.yaml
```

### Override Values via CLI

```bash
# Override specific values
helm install api-service ./api-service \
  --set replicaCount=3 \
  --set image.tag=v1.2.4

# Override nested values
helm install api-service ./api-service \
  --set ingress.hosts[0].host=custom.example.com

# Multiple values files (later files override earlier)
helm install api-service ./api-service \
  --values values.yaml \
  --values values-prod.yaml \
  --values values-prod-override.yaml
```

### Advanced: Templating Environment Variables

**templates/deployment.yaml:**
```yaml
spec:
  template:
    spec:
      containers:
      - name: {{ .Chart.Name }}
        env:
        {{- range .Values.env }}
        - name: {{ .name }}
          value: {{ .value | quote }}
        {{- end }}
        {{- if .Values.secrets }}
        {{- range .Values.secrets }}
        - name: {{ .name }}
          valueFrom:
            secretKeyRef:
              name: {{ .secretName }}
              key: {{ .key }}
        {{- end }}
        {{- end }}
```

**values-prod.yaml:**
```yaml
env:
  - name: ENVIRONMENT
    value: "production"
  - name: LOG_LEVEL
    value: "info"

secrets:
  - name: DB_PASSWORD
    secretName: postgres-credentials
    key: password
  - name: API_KEY
    secretName: external-api
    key: api-key
```

### Hands-On Exercise

**Deploy Multi-Environment Setup:**

```bash
# Create namespaces
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace prod

# Deploy to all environments
helm install myapp-dev ./myapp -n dev -f values-dev.yaml
helm install myapp-staging ./myapp -n staging -f values-staging.yaml
helm install myapp-prod ./myapp -n prod -f values-prod.yaml

# Verify
kubectl get pods -n dev
kubectl get pods -n staging
kubectl get pods -n prod
```

---

## 3. Perform an Upgrade and Rollback

### Upgrade Workflow

**Scenario:** New version of your app is ready.

```bash
# Current state
helm list -n prod
# NAME         REVISION  STATUS    CHART        APP VERSION
# api-service  1         deployed  api-0.1.0    1.0.0

# Upgrade to new version
helm upgrade api-service ./api-service \
  -n prod \
  -f values-prod.yaml \
  --set image.tag=v1.2.4

# Check status
helm list -n prod
# NAME         REVISION  STATUS    CHART        APP VERSION
# api-service  2         deployed  api-0.1.0    1.2.4
```

### Upgrade Strategies

**1. Rolling Update (Default):**
```yaml
# In deployment template
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Max pods above desired count
      maxUnavailable: 0  # Max pods unavailable during update
```

**2. Recreate (Downtime):**
```yaml
spec:
  strategy:
    type: Recreate  # Kill all old pods, then create new ones
```

**3. Blue-Green (Manual):**
```bash
# Deploy new version alongside old
helm install api-service-v2 ./api-service \
  -n prod \
  -f values-prod.yaml \
  --set image.tag=v1.2.4

# Switch traffic (update Service selector)
kubectl patch service api-service -n prod \
  -p '{"spec":{"selector":{"version":"v2"}}}'

# Delete old version
helm uninstall api-service-v1 -n prod
```

### Rollback

**View History:**
```bash
helm history api-service -n prod
# REVISION  STATUS      CHART        APP VERSION  DESCRIPTION
# 1         superseded  api-0.1.0    1.0.0        Install complete
# 2         superseded  api-0.1.0    1.2.3        Upgrade complete
# 3         deployed    api-0.1.0    1.2.4        Upgrade complete
```

**Rollback to Previous Version:**
```bash
# Rollback to revision 2
helm rollback api-service 2 -n prod

# Rollback to previous revision (shorthand)
helm rollback api-service -n prod
```

**Verify Rollback:**
```bash
helm history api-service -n prod
# REVISION  STATUS      CHART        APP VERSION  DESCRIPTION
# 1         superseded  api-0.1.0    1.0.0        Install complete
# 2         superseded  api-0.1.0    1.2.3        Upgrade complete
# 3         superseded  api-0.1.0    1.2.4        Upgrade complete
# 4         deployed    api-0.1.0    1.2.3        Rollback to 2
```

### Atomic Upgrades

**Problem:** Upgrade fails mid-way, leaving cluster in broken state.

**Solution:** Atomic flag
```bash
helm upgrade api-service ./api-service \
  -n prod \
  -f values-prod.yaml \
  --atomic \
  --timeout 5m
```

**Behavior:**
- If upgrade fails, automatically rollback
- Wait up to 5 minutes for pods to be ready
- All-or-nothing deployment

### Hands-On Exercise: Upgrade & Rollback

```bash
# Install v1.0.0
helm install myapp ./myapp -n dev \
  --set image.tag=v1.0.0

# Verify
kubectl get pods -n dev

# Upgrade to v1.1.0
helm upgrade myapp ./myapp -n dev \
  --set image.tag=v1.1.0

# Check history
helm history myapp -n dev

# Simulate failure: Upgrade to bad image
helm upgrade myapp ./myapp -n dev \
  --set image.tag=bad-tag

# Pods will crash (ImagePullBackOff)
kubectl get pods -n dev

# Rollback
helm rollback myapp -n dev

# Verify recovery
kubectl get pods -n dev
```

### External Resources

**Helm Upgrade & Rollback:**
- Helm Upgrade Docs: https://helm.sh/docs/helm/helm_upgrade/
- Helm Rollback Docs: https://helm.sh/docs/helm/helm_rollback/

**Industry Practices:**
- GitOps with Helm: https://www.weave.works/blog/gitops-helm-and-operators
- Spotify's Helm Workflow: https://engineering.atspotify.com/2020/02/kubernetes-at-spotify/

---

## Advanced Topics

### 1. Chart Dependencies

**Chart.yaml:**
```yaml
dependencies:
- name: postgresql
  version: "12.1.0"
  repository: "https://charts.bitnami.com/bitnami"
  condition: postgresql.enabled
- name: redis
  version: "17.0.0"
  repository: "https://charts.bitnami.com/bitnami"
  condition: redis.enabled
```

**Update dependencies:**
```bash
helm dependency update
```

**values.yaml (configure sub-charts):**
```yaml
postgresql:
  enabled: true
  auth:
    username: myapp
    password: changeme
    database: myapp_db

redis:
  enabled: true
  auth:
    enabled: false
```

### 2. Helm Hooks

Execute jobs at specific lifecycle points:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "myapp.fullname" . }}-migration
  annotations:
    "helm.sh/hook": pre-upgrade,pre-install
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  template:
    spec:
      containers:
      - name: migration
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        command: ["./migrate.sh"]
      restartPolicy: Never
```

**Hook Types:**
- `pre-install`: Before install
- `post-install`: After install
- `pre-upgrade`: Before upgrade
- `post-upgrade`: After upgrade
- `pre-delete`: Before delete
- `post-delete`: After delete

### 3. Chart Testing

```bash
# Install chart test plugin
helm plugin install https://github.com/helm-unittest/helm-unittest

# Create test
cat > tests/deployment_test.yaml <<EOF
suite: test deployment
templates:
  - deployment.yaml
tests:
  - it: should create deployment
    asserts:
      - isKind:
          of: Deployment
      - equal:
          path: spec.replicas
          value: 1
EOF

# Run tests
helm unittest .
```

---

## Summary: Helm Mastery Checklist

✅ **Created:** Custom Helm chart with templates
✅ **Deployed:** Multi-environment (Dev/Prod) with different values
✅ **Upgraded:** Application to new version
✅ **Rolled Back:** Failed deployment

---

## Next Steps

➡️ **Next:** [Part 4: ArgoCD Deep Dive](PART_4_ARGOCD.md)

### Additional Practice

1. **Package & Publish:** Create a Helm repository (GitHub Pages or ChartMuseum)
2. **Complex Charts:** Add StatefulSets, Jobs, CronJobs
3. **Secrets Management:** Integrate with Sealed Secrets or External Secrets Operator
4. **Chart Testing:** Write comprehensive unit tests

### Community Resources

- **Helm Slack:** https://slack.k8s.io/ (#helm-users)
- **Helm GitHub:** https://github.com/helm/helm
- **Awesome Helm:** https://github.com/cdwv/awesome-helm
