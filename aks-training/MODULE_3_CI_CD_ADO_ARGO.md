# Module 3: The Supply Chain - GitFlow & CI (Azure DevOps)

In this module, we automate the build and delivery process.

## 1. The Git Workflow
We recommend a **Trunk-Based Development** or a simplified **GitFlow**:
*   `main`: Production-ready code.
*   `feature/*`: Feature branches.

### The Pull Request (PR)
Every PR triggers a build validation pipeline:
1.  **Lint**: Check code style.
2.  **Test**: Run unit tests.
3.  **Build (Draft)**: Ensure the Docker build passes (but don't push artifact).

## 2. CI Pipeline in Azure DevOps
We use `azure-pipelines.yaml`.

### Build & Publish Stage
The goal is to produce two artifacts:
1.  **Docker Image**: Pushed to ACR with a unique tag (e.g., `buildId`).
2.  **Helm Chart**: Packaged and pushed to ACR (OCI Artifact).

```yaml
# Simplified Azure Pipeline
trigger:
- main

pool:
  vmImage: ubuntu-latest

steps:
- task: Docker@2
  displayName: Build and Push Image
  inputs:
    containerRegistry: 'MyACRConnection'
    repository: 'my-app'
    command: 'buildAndPush'
    tags: |
      $(Build.BuildId)
      latest

- task: HelmDeploy@0
  displayName: Package and Push Chart
  inputs:
    command: package
    chartPath: charts/my-app
    destination: $(Build.ArtifactStagingDirectory)

- script: |
    az acr helm push -n myacr $(Build.ArtifactStagingDirectory)/*.tgz
  displayName: Push Chart to ACR
```

## 3. Continuous Delivery: GitOps with ArgoCD
### Why GitOps?
*   **Version Control**: Your infrastructure state is versioned in Git.
*   **Audit Trail**: Who changed the replica count? Check the Git commit.
*   **Drift Detection**: ArgoCD ensures the cluster matches the Git state.

### The GitOps Repository
We separate **App Code** from **Config Code**.
*   `my-app-repo`: Source code + Dockerfile + Helm Chart generic template.
*   `gitops-repo` (or `cluster-config-repo`): The specific values for each environment.

### Deployment Workflow
1.  **CI Pipeline finishes**: New image `my-app:123` is pushed.
2.  **Update GitOps Repo**: The CI pipeline (or a separate tailored pipeline) updates the `values.yaml` in the GitOps repo:
    ```yaml
    image:
      tag: "123"
    ```
3.  **ArgoCD Sync**: ArgoCD detects the change in Git and syncs the cluster.

### Lab: Setting up the Pipeline
1.  Create a new ADO Pipeline using the provided template.
2.  Configure the Service Connection to ACR.
3.  Run the pipeline and verify the image and chart are in ACR.
4.  (Advanced) Set up automatic PR decoration.
