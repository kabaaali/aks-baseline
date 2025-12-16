# Walkthrough Folder: Helm & AKS Automatic Foundations

I have successfully created an end-to-end foundation for deploying microservices to AKS Automatic using Helm, Azure DevOps, and Argo CD.

## Key Accomplishments

1.  **Repo Structure (Separation of Concerns)**
    -   Restructured into `platform-repo` and `app-repo` to simulate a real-world enterprise setup.
    -   `platform-repo` owns the "Base Library Chart".
    -   `app-repo` owns the "Application Chart" which strictly depends on the Base Chart.

2.  **Helm Strategy (Library & Wrapper)**
    -   Created `charts/base-service`: Contains all standard K8s templates (Deployment, Service, HPA, Ingress).
    -   Created `charts/backend-service`: An example app chart that purely provides `values.yaml` overrides and inherits logic from `base-service`.
    -   Created `charts/platform-infra`: An example wrapper chart for Redis.

3.  **CI/CD Pipelines (Azure DevOps)**
    -   Created `azure-pipelines-platform-charts.yaml`: Lints and publishes the Base Chart to ACR as an OCI artifact.
    -   Created `azure-pipelines-app-ci.yaml`: Builds Docker container AND packages the App Chart (binding it to the Base Chart version).

4.  **GitOps (Argo CD)**
    -   Implemented "App of Apps" pattern (`root-app.yaml`).
    -   Designed an **ApplicationSet** (`microservices.yaml`) to automatically deploy apps to Dev and Prod based on directory structure.

## Artifacts Created

### Architecture
![Architecture Diagram](file:///Users/rekhasunil/Documents/Sunil/poc-antigravity/helm-aks-poc/ARCHITECTURE.md) (See document for Mermaid diagram)

### Folder Structure
> [!NOTE]
> The `helm-aks-poc` directory contains the entire solution.

```text
helm-aks-poc/
├── platform-repo/          # Platform Engineering Domain
│   └── charts/
│       ├── base-service/   # The Reusable Contract
│       └── platform-infra/ # Redis Wrapper
├── app-repo/               # Application Dev Domain
│   ├── src/                # App Source
│   └── charts/
│       └── backend-service/# App-specific config
├── gitops/                 # Operations Domain
│   ├── applicationsets/    # Automation
│   └── env/                # Environment Overrides
└── pipelines/              # CI Definitions
```

## Next Steps

1.  **Push to Git**: Commit the `helm-aks-poc` folder to your actual Git repository.
2.  **Update URLs**: Edit `root-app.yaml` and `microservices.yaml` to point to your valid Git URL.
3.  **Setup ACR**: Ensure your Azure pipelines have access to push to your ACR.
