# Helm & AKS Automatic Deployment Foundation

This repository demonstrates an end-to-end foundation for deploying microservices to AKS Automatic using Helm, Azure DevOps, and Argo CD.

## Architecture

The solution follows a **GitOps** approach with a separation of concerns between Platform Engineering and Application Development.

### Repository Structure (Simulated)

- **`platform-repo/`**: Owned by Platform Team.
  - `charts/base-service`: A **Library Chart** defining the standard K8s deployment contract (Deployment, Service, HPA, Ingress).
  - `charts/platform-infra`: A **Wrapper Chart** for platform tools (e.g., Redis).
- **`app-repo/`**: Owned by Application Team.
  - `src/`: Source code.
  - `charts/backend-service`: An **Application Chart** that inherits from `base-service` via OCI dependency.
- **`gitops/`**: Owned by Ops/Shared.
  - `bootstrap/`: Argo CD Root Application.
  - `applicationsets/`: Automates app creation.
  - `env/`: Environment-specific value overrides (Dev/Prod).

### Workflow

1.  **Platform Team** changes `base-service` -> CI publishes `oci://<acr>/helm/base-service:ver`.
2.  **App Team** builds app -> CI builds Docker image & Helm chart (bundling `base-service`) -> Publishes `oci://<acr>/helm/backend-service:ver`.
3.  **Argo CD** detects new version (or Git change) -> Syncs to AKS.

## Prerequisities

- AKS Automatic Cluster
- Azure Container Registry (ACR)
- Azure DevOps Project
- Argo CD installed on AKS

## Getting Started

### 1. Build & Push Charts (Manual / CI)

If you have `helm` and `az` installed:

```bash
# Login to ACR
az acr login --name <your-acr>

# 1. Publish Base Chart
cd platform-repo/charts/base-service
helm package .
helm push base-service-1.0.0.tgz oci://<your-acr>.azurecr.io/helm

# 2. Publish App Chart
cd ../../../app-repo/charts/backend-service
# Update dependency in Chart.yaml to point to your OCI repo instead of file://
helm dependency update
helm package .
helm push backend-service-0.1.0.tgz oci://<your-acr>.azurecr.io/helm
```

### 2. Bootstrap Argo CD

Apply the root application to your cluster:

```bash
kubectl apply -f gitops/bootstrap/root-app.yaml
```

*Note: You will need to update the `repoURL` in `root-app.yaml` and `microservices.yaml` to point to your actual Git repository.*

## Key Files to Review

- [ARCHITECTURE.md](ARCHITECTURE.md): Detailed design flow.
- [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md): **Start Here** if you are an App Engineer. Simpler explanation of files and workflows.
- `platform-repo/charts/base-service/templates/`: The reusable K8s manifest templates.
- `app-repo/charts/backend-service/values.yaml`: How an app consumes the base chart.
- `pipelines/`: Azure DevOps YAML definitions.
