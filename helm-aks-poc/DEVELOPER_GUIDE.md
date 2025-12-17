# Application Engineer's Guide to Deployment

**Target Audience:** Application Developers who want to deploy their code to AKS without needing to be Kubernetes experts.

---

## 1. The Big Picture: How Code Gets to the Cloud

You write code. We want it running in the cloud. Here is the journey:

1.  **You Push Code**: You commit changes to your implementation (`src/`) or configuration (`charts/`).
2.  **CI Builds It**: Azure DevOps automatically builds your Docker container and packages your Helm chart.
3.  **CD Deploys It**: Argo CD (our deployment bot) sees the new version and updates the cluster.

**You don't need to run `kubectl` or manage servers.** You just manage files in your repository.

---

## 2. Your Toolkit: "What Does This File Do?"

In your repository (`app-repo`), you will see a `charts/` folder. This is your interface to the platform.

### `charts/my-app/Chart.yaml` -> "The ID Card"
Metadata about your application.
*   **Key Fields**:
    *   `name`: The name of your service (e.g., `backend-service`).
    *   `dependencies`: specificies that you use the standard `base-service` template. **Do not touch this unless upgrading the platform version.**

### `charts/my-app/values.yaml` -> "The Control Panel"
This is the **most important file**. It controls how your app runs. You don't write Kubernetes YAML; you just fill in these blanks.
*   **`replicaCount`**: How many copies of your app to run.
*   **`image.tag`**: Which version of your code to deploy (usually automated).
*   **`resources`**: How much CPU/RAM your app needs.
*   **`env`**: Environment variables your app needs.

### `src/Dockerfile` -> "The Packaging"
Standard Dockerfile. If your app runs locally in Docker, it will run on the platform.

---

## 3. Common Tasks: "How Do I...?"

### "I need to add an Environment Variable"
**Do not** hardcode it in your source code.
1.  Open `charts/my-app/values.yaml`.
2.  Find the `base-service` section (or root, depending on config).
3.  Add it under `env`:
    ```yaml
    env:
      - name: DATABASE_URL
        value: "postgres://host:5432/db"
    ```

### "I need more CPU/Memory"
1.  Open `charts/my-app/values.yaml`.
2.  Edit the `resources` section:
    ```yaml
    resources:
      limits:
        cpu: 1000m  # 1 Core
        memory: 1Gi # 1 Gigabyte
    ```

### "I need to expose my app to the internet"
1.  Open `charts/my-app/values.yaml`.
2.  Configure `ingress`:
    ```yaml
    ingress:
      enabled: true
      hosts:
        - host: my-app.example.com
    ```

### "I need a specialized CronJob (or something weird)"
The `base-service` covers 90% of use cases (Web App / API). If you need something special:
1.  Create a standard Kubernetes YAML file in `charts/my-app/templates/my-special-thing.yaml`.
2.  Helm will automatically include it in your deployment alongside the standard stuff.

---

## 4. How Debugging Works

*   **"My build failed"**: Check Azure DevOps Pipelines. Usually a Docker build error or invalid YAML indentation.
*   **"My deployment failed"**: Check Argo CD UI.
    *   *ImagePullBackOff*: You defined an image tag in `values.yaml` that doesn't exist in the registry.
    *   *CrashLoopBackOff*: Your app started but crashed. Check your logs.
