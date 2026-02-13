# Module 4: Day 2 Operations - Troubleshooting & Self-Service

In this module, we learn how to debug when things go wrong.

## 1. The Troubleshooting Flow
When an alert fires or a deployment fails, follow this flow:
1.  **Check ArgoCD**: Is the application synced? Is it healthy?
2.  **Check Pod Status**: Are pods running? Restarts > 0?
3.  **Check Logs**: What is the application saying?
4.  **Check Events**: What is Kubernetes saying?

## 2. Common Scenarios & Fixes

### Scenario A: `CrashLoopBackOff`
*   **Symptom**: Pod starts, crashes, restarts repeatedly.
*   **Cause**: Application error, missing env var, config error.
*   **Action**:
    ```bash
    kubectl logs -n my-ns my-pod -f
    kubectl describe pod -n my-ns my-pod  # Look for "Last State: Terminated"
    ```

### Scenario B: `ImagePullBackOff` / `ErrImagePull`
*   **Symptom**: Pod never starts.
*   **Cause**: Wrong image name, wrong tag, or ACR authentication issue.
*   **Action**:
    *   Verify the image exists in ACR.
    *   Check if the Managed Identity has `AcrPull` permissions.

### Scenario C: `Pending`
*   **Symptom**: Pod is stuck in Pending state.
*   **Cause**: No nodes available (unlikely in AKS Automatic), or Resource Quota exceeded.
*   **Action**:
    ```bash
    kubectl describe pod -n my-ns my-pod
    # Look for "FailedScheduling" events
    ```

## 3. Tooling
### Kubectl Cheat Sheet
*   `kubectl get pods -n my-ns`: List pods.
*   `kubectl logs -n my-ns my-pod`: View logs.
*   `kubectl describe pod -n my-ns my-pod`: deep dive into pod state.
*   `kubectl port-forward -n my-ns service/my-service 8080:80`: Access app locally (Magic!).

### Azure Monitor / Container Insights
*   Use the "Live Data" view to see logs in real-time without CLI.
*   Use "Workbooks" to see CPU/Memory usage trends.

## 4. Self-Service Operations
You don't need a ticket for these:
*   **Restarting a Pod**: `kubectl delete pod -n my-ns my-pod` (Deployment will recreate it).
*   **Scaling**: Update `replicas` in `values.yaml` and commit to Git.
*   **Rolling Back**: Revert the commit in Git. ArgoCD will sync the old version.
