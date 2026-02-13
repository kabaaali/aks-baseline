# Challenge 3: The GitOps Handshake

**Scenario**: Great, you have a Helm chart. But you are still building images locally and manually copying `helm install` commands. This is not scalable.

**Your Mission**: Create an Azure DevOps Pipeline that builds the image, packages the Helm chart, and pushes both to ACR. Then, prepare the GitOps configuration.

## Requirements (Win Conditions)
1.  **Pipeline as Code**: Create `azure-pipelines.yaml` in the root of your repo.
2.  **Versioning**: The pipeline must use the ADO Build ID (or similar) to tag the Docker image AND the Helm chart version.
3.  **Artifacts**:
    *   Docker Image pushed to `myacr.azurecr.io/legacy-app:<BuildID>`.
    *   Helm Chart pushed to `myacr.azurecr.io/helm/legacy-app:<BuildID>`.
4.  **GitOps Config**: Create a `values-prod.yaml` file that you *would* commit to the GitOps repo (simulated).

## Hints
*   Use `task: Docker@2` for building.
*   Use `task: HelmDeploy@0` for packaging.
*   Remember to log in to ACR (`az acr login`) before pushing Helm charts if using `az acr helm push`.

## Validation
This challenge is validated by running the pipeline in Azure DevOps.
*   **Pass**: Green build.
*   **Pass**: Artifacts exist in ACR.
