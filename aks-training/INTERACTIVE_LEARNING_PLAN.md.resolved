# Interactive Learning Plan: AKS Automatic

## Goal
Transform the passive "read and follow" training into an active **"Challenge-Based Learning"** experience. Engineers learn best by doing, breaking, and fixing.

## The Strategy: "The Broken Application"
Instead of building from scratch initially, we start with a broken or "legacy" application and ask the engineer to modernize and fix it.

### Phase 1: The Setup (The "Legacy" App)
*   **Concept**: We provide a repository with a "bad" Dockerfile, a hardcoded Kubernetes manifest (no Helm), and no pipeline.
*   **Activity**: Engineer pulls this repo. It runs locally but fails in the cluster (or doesn't scale).

### Phase 2: The Challenges (Gamified Modules)

#### Challenge 1: "The Container Diet"
*   **Problem**: The provided image is 1GB and runs as root. Security policy blocks it.
*   **Goal**: Refactor Dockerfile to use multi-stage builds and non-root user.
*   **Win Condition**: Image size < 200MB, scans pass.

#### Challenge 2: "Helmification"
*   **Problem**: We need to deploy to Dev, Test, and Prod with different config. The hardcoded YAMLs are unmanageable.
*   **Goal**: Create a Helm chart with `values.yaml` for environment differences.
*   **Win Condition**: `helm install` works with `--values values-dev.yaml`.

#### Challenge 3: "The GitOps Handshake"
*   **Problem**: Manual deployments are banned.
*   **Goal**: Set up the ADO Pipeline to push to ACR, and update the GitOps repo to trigger ArgoCD.
*   **Win Condition**: A code change automatically appears on the URL without human touch.

#### Challenge 4: "Chaos Monkey" (Troubleshooting)
*   **Problem**: We (the trainers) introduce a bug in the configuration (e.g., wrong secret name, liveness probe failing).
*   **Goal**: Use `kubectl` and logs to find the issue and fix it.
*   **Win Condition**: Application returns to `Healthy` state in ArgoCD.

## Technical Requirements for Interactivity
1.  **Scenario Repo**: A Git repo containing the "starting point" code (Python/NodeJS app).
2.  **Lab Scripts**: Bash scripts that simulate "Day 2" events (e.g., a script that artificially loads the CPU to trigger HPA, or a script that changes a secret to break the app).
3.  **Validation**: A checklist where they can run a script to "verify" their solution (e.g., `./verify-challenge-1.sh` checks image size and user).

## Folder Structure (New)
```text
aks-training/
  README.md                   # The Entry Point
  scenarios/
    00-legacy-app/            # The starting bad code
  challenges/
    01-container-optimization.md
    02-helm-packaging.md
    03-cicd-pipeline.md
    04-troubleshooting-hunt.md
  solutions/                  # Reference solutions for instructors
```
