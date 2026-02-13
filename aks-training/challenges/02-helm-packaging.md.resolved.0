# Challenge 2: Helm-ification

**Scenario**: You optimized the container, but now the Ops team is yelling at you. You sent them a raw `pod.yaml` file, but they need to deploy your app to Dev, UAT, and Prod with different configurations (CPU limits, Replicas, Ingress Hostnames).

**Your Mission**: Create a generic Helm Chart for your `legacy-app`.

## The Starting Point
You have your optimized Docker image `legacy-app:optimized`. Now you need to package it.

## Requirements (Win Conditions)
1.  **Structure**: Created a valid Helm chart structure (`Chart.yaml`, `values.yaml`, templates).
2.  **Parametrization**: `values.yaml` must allow configuring:
    *   `replicaCount`
    *   `image.repository` and `image.tag`
    *   `ingress.hosts`
    *   `resources.requests` and `resources.limits`
3.  **Health Checks**: The deployment template MUST include `livenessProbe` and `readinessProbe`.
4.  **Verification**: You must be able to generate valid YAML for two different environments:
    *   **Dev**: 1 replica, minimal resources.
    *   **Prod**: 3 replicas, higher resources.

## Hints
```bash
# Start with the boilerplate
helm create my-chart
```
*   Clean up the `templates/` folder! You don't need `serviceaccount.yaml` default logic if you aren't using it.
*   Check your syntax with `helm lint my-chart`.
*   Preview the YAML with `helm template my-chart --debug`.

## Validation
Run these commands to prove your chart works:

```bash
# Verify Dev Config
helm template my-chart --set replicaCount=1 --set resources.requests.cpu=100m

# Verify Prod Config
helm template my-chart --set replicaCount=3 --set resources.requests.cpu=500m
```
