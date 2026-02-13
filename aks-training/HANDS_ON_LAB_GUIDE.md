# Hands-on Lab: The Golden Path to Production

This guide helps you deploy your first microservice to AKS Automatic using our enterprise standards.

## Prerequisites
*   [ ] Access to Azure DevOps Project: `Ref-Architecture`.
*   [ ] Access to ACR: `myacr.azurecr.io`.
*   [ ] Installed: VS Code, Git, Docker, Helm, Kubectl.

## Step 1: Bootstrap the Repository
1.  **Clone the Template**:
    ```bash
    git clone https://dev.azure.com/myorg/myproject/_git/microservice-template my-new-service
    cd my-new-service
    rm -rf .git
    git init
    ```
2.  **Customize**:
    *   Rename `charts/template` to `charts/my-new-service`.
    *   Update `Chart.yaml` name and version `0.1.0`.

## Step 2: Configure the Pipeline
1.  **Create Pipeline in ADO**:
    *   Pipelines -> New Pipeline -> Azure Repos Git -> Select `my-new-service`.
    *   Select "Existing Azure Pipelines YAML file" -> `azure-pipelines.yaml`.
2.  **Run the Pipeline**:
    *   This will build the Docker image and push the Helm chart to ACR.
    *   **Verify**: Check ACR for `my-new-service` repository.

## Step 3: Onboard to ArgoCD
1.  **Clone the GitOps Repo**:
    ```bash
    git clone https://dev.azure.com/myorg/myproject/_git/gitops-cluster-config
    ```
2.  **Add Your Application**:
    *   Create a file `apps/my-new-service.yaml`:
    ```yaml
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: my-new-service
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: 'myacr.azurecr.io/helm/my-new-service'
        targetRevision: 0.1.0
        chart: my-new-service
      destination:
        server: 'https://kubernetes.default.svc'
        namespace: my-new-service
    ```
3.  **Commit and Push**:
    ```bash
    git add .
    git commit -m "Onboard my-new-service"
    git push
    ```

## Step 4: Verify Deployment
1.  **Check ArgoCD UI**:
    *   Login to ArgoCD.
    *   Find `my-new-service`. Status should be `Synced` and `Healthy`.
2.  **Check the App**:
    *   Get the Ingress URL:
    ```bash
    kubectl get ingress -n my-new-service
    ```
    *   Curl the endpoint.

## Step 5: Day 2 - Make a Change
1.  Change the code in `my-new-service` (e.g., update the response message).
2.  Bump the version in `Chart.yaml` to `0.1.1`.
3.  Commit and Push.
4.  Watch the CI pipeline build `0.1.1`.
5.  Update `apps/my-new-service.yaml` in the GitOps repo to version `0.1.1`.
6.  Commit and Push.
7.  Watch ArgoCD sync the new version.

**Congratulations! You have completed the Golden Path.**
