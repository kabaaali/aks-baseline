# Module 1: The New Paradigm - AKS Automatic & Platform Engineering

## 1. Introduction
Welcome to the Application Engineering "Golden Path" for AKS Automatic. This training is designed to get you from "code on laptop" to "production microservice" using the enterprise-approved patterns.

### What is AKS Automatic?
Azure Kubernetes Service (AKS) Automatic is a fully managed Kubernetes implementation.
*   **Old Way (Standard AKS)**: You managed node pools, scaling, upgrades, and OS patching. You were half-ops, half-dev.
*   **New Way (AKS Automatic)**: Azure manages the nodes. You provides the Pods.
    *   **No Node Access**: You cannot SSH into nodes.
    *   **API Driven**: Everything is defined via Kubernetes manifests or Helm charts.
    *   **Guardrails**: Reference architectures are enforced by Azure policies by default.

## 2. Enterprise Architecture Overview
Our environment follows a **Hub & Spoke** model.

*   **Hub**: Shared networking, firewalls, and connectivity to on-premise.
*   **Spoke (Your Cluster)**: Where your application lives.
    *   **Ingress Controller**: The entry point for traffic. We use a managed NGINX or Istio ingress.
    *   **Workload Identity**: How your app talks to Azure resources (SQL, Service Bus, Key Vault) without secrets.

### The "Product" Thinking
Stop thinking of your app as just a jar file or a binary. In Kubernetes, your "Product" is:
1.  **The Container Image**: The runtime artifact.
2.  **The Helm Chart**: The operational definition (CPU, RAM, Config).
3.  **The Pipeline**: The delivery mechanism.

## 3. Key Concepts for App Engineers
| Concept | Definition | Developer Responsibility |
| :--- | :--- | :--- |
| **Namespace** | A logical isolation boundary (e.g., `payment-service`). | **You own this.** defined in your Helm values. |
| **Pod** | The smallest deployable unit (usually one container). | **You own this.** Optimized via Dockerfile. |
| **Service** | Internal network abstraction. | **You own this.** Defined in Helm. |
| **Ingress** | External access rules (HTTP/HTTPS). | **You own this.** Defined in Helm. |
| **Workload Identity** | Identity for the pod to access Azure resources. | **Platform provides ID**, you bind it. |

## 4. Hands-on Readiness Checklist
Before proceeding to Module 2, ensure you have:
- [ ] Access to Azure DevOps.
- [ ] Access to the Enterprise Container Registry (ACR).
- [ ] `kubectl`, `helm`, and `az` CLI installed locally.
- [ ] VS Code with the Kubernetes extension.
