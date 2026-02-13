# Module 2: The Unit of Deployment - Containers & Helm

In this module, we focus on packaging your application correctly for AKS Automatic.

## 1. Container Basics: Pragmatic Dockerfiles
Your Dockerfile is the blueprint for your application runtime.

### Best Practices for Enterprise
1.  **Multi-Stage Builds**: Keep your final image small.
    *   *Bad*: Including build tools (gcc, maven) in production.
    *   *Good*: Build in stage 1, copy artifact to stage 2 (distroless/alpine/chiseled).
2.  **Run as Non-Root**:
    *   **Mandatory**: AKS Automatic enforces non-root containers by default for security.
    *   Use `USER 1000` or similar in your Dockerfile.
3.  **Specific Base Tags**:
    *   *Bad*: `FROM python:latest`
    *   *Good*: `FROM python:3.11-slim-bullseye`

### Example: Secure Python Dockerfile
```dockerfile
# Stage 1: Build
FROM python:3.11-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Stage 2: Run
FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY . .
ENV PATH=/root/.local/bin:$PATH

# Run as non-root user
RUN adduser --disabled-password --gecos "" appuser
USER appuser

EXPOSE 8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

## 2. Helm Charts: The Packaging Standard
Helm is the package manager for Kubernetes. We use it to template our YAMLs.

### Anatomy of an Enterprise Chart
A standard chart structure:
```text
my-chart/
  Chart.yaml          # Metadata (name, version)
  values.yaml         # Default configuration
  templates/          # The logic
    deployment.yaml   # How to run it
    service.yaml      # How to reach it
    ingress.yaml      # How the world reaches it
    _helpers.tpl      # Reusable template logic
```

### Values Hierarchy
1.  **Chart Defaults (`values.yaml`)**: The baseline.
2.  **Environment Overrides (`values-dev.yaml`, `values-prod.yaml`)**:
    *   Replay count (1 vs 3).
    *   Resources (CPU/RAM).
    *   Ingress Hostnames.

### Lab: Create Your First Chart
1.  Run `helm create my-app`.
2.  Clean up the boilerplate (remove unused generated files like `serviceaccount.yaml` if not needed).
3.  Update `values.yaml` to point to your image repository.
4.  Adding liveness and readiness probes is **mandatory** for zero-downtime deployments.

## 3. Checklist for Success
- [ ] Dockerfile uses multi-stage builds.
- [ ] Dockerfile runs as non-root.
- [ ] Helm chart includes `readinessProbe` and `livenessProbe`.
- [ ] Resources (requests/limits) are set in `values.yaml`.
- [ ] Secrets are **NOT** in `values.yaml` (Use Workload Identity or CSI Secret Store).
