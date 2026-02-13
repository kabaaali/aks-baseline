# Challenge 4: The Chaos Monkey Hunt

**Scenario**: It is 3:00 AM. PagerDuty just woke you up. The `legacy-app` deployment in Production is failing. The dashboard shows red.

**Your Mission**: Identify the root cause of the failure and fix it.

## The Simulated Failure
(Instructor Note: Apply the `broken-manifest.yaml` to the cluster to simulate this).

**Symptoms**:
1.  ArgoCD shows the app as `Degraded`.
2.  `kubectl get pods` shows `CrashLoopBackOff`.
3.  `kubectl get pods` shows `Restarts: 5`.

## Investigation Steps (The Hunt)
1.  **Check Logs**:
    ```bash
    kubectl logs -n legacy-app -l app=legacy-app --tail=20
    ```
    *Hint*: Does the app say something about a missing environment variable or database connection?

2.  **Describe Pod**:
    ```bash
    kubectl describe pod -n legacy-app <pod-name>
    ```
    *Hint*: Look at the `Events` section at the bottom. Is the Liveness Probe failing?

3.  **Check Config**:
    Compare the `values.yaml` in Git with the actual running configuration.
    ```bash
    kubectl get deployment -n legacy-app legacy-app -o yaml
    ```

## Likely Suspects (Common Issues)
*   **Wrong Port**: The container exposes port 5000, but the Service targets port 80.
*   **Missing Secret**: The code expects `DB_PASSWORD` but it is not set.
*   **Liveness Probe**: The probe hits `/healthz` but the app only has `/`.
*   **OOMKilled**: Memory limit is too low (e.g., 10Mi).

## Win Condition
*   The Pod status becomes `Running`.
*   The Restart count stops increasing.
*   ArgoCD shows `Healthy`.
