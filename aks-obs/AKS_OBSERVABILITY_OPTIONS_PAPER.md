# Architecture, Design, and Engineering Options Paper
## AKS Automatic Observability: Azure Managed vs. SaaS Platforms

**Date:** January 21, 2026
**Version:** 1.0
**Target Audience:** Principle Architects, Head of Engineering, Platform Engineering Leads

---

## 1. Executive Summary

This paper evaluates two primary observability strategies for Azure Kubernetes Service (AKS) Automatic: the Azure-native **Managed Prometheus & Grafana** stack versus generic **SaaS Observability Platforms** (e.g., Dynatrace, Datadog, New Relic).

**Recommendation:** A **hybrid co-existence strategy** is often the optimal engineering choice for enterprise-scale organizations. It leverages Azure Managed services for cost-effective, deep infrastructure monitoring (Platform Engineering focus) while utilizing SaaS platforms for high-fidelity application performance monitoring (APM) and distributed tracing (Application Developer focus).

---

## 2. Architecture & Design Options

### 2.1 Option A: Azure Managed Observability (Native Stack)
This option utilizes the First-Party (1P) services integrated directly into the Azure Resource Manager (ARM) fabric.

#### **Architecture**
*   **Collection Layer**: The **Azure Monitor Agent (AMA)** runs as a daemonset on AKS nodes. Check-box enablement in AKS Automatic.
*   **Storage Layer**: **Azure Monitor Managed Service for Prometheus**. This is a managed Store compatible with Prometheus remote-write, built on a hyper-scale backend (Monitor workspace).
*   **Visualization Layer**: **Azure Managed Grafana**. A fully managed SaaS Grafana instance integrated with Azure AD for RBAC.

#### **Design Principles**
*   **Agentless-feel**: No manual agent lifecycle management; the platform manages the AMA version.
*   **Security**: Uses Managed Identity exclusively. No API keys or secrets management required.
*   **Open Standards**: Fully compatible with PromQL and Grafana dashboards.

#### **Engineering Implementation**
*   **Enablement**: 
    ```hcl
    resource "azurerm_kubernetes_cluster" "example" {
      monitor_metrics {
        annotations_allowed = null
        labels_allowed      = null
      }
    }
    ```
*   **Customization**: Custom scrape jobs are defined via straightforward K8s ConfigMaps or standard CRDs (`PodMonitor`, `ServiceMonitor`).

---

### 2.2 Option B: Generic SaaS Observability (SaaS Stack)
This option utilizes third-party enterprise platforms like Dynatrace, Datadog, or New Relic.

#### **Architecture**
*   **Collection Layer**: Proprietary **Agents/Operators** (e.g., OneAgent, Datadog Agent) deployed via Helm or proprietary Operators. Often utilizes **eBPF** for kernel-level visibility.
*   **Storage & Visualization**: All data is egressed immediately to the Vendor's Cloud. Processing, storage, and UI are fully external SaaS.

#### **Design Principles**
*   **Full-Stack Context**: Automatically correlates infrastructure metrics with application traces and logs (Spans <-> Host Metrics).
*   **AI-Driven**: Heavy reliance on "AI Ops" to detect anomalies without manual threshold configuration.
*   **Unified Agent**: Single agent often handles Logs, Metrics, Traces, and Security profiles.

#### **Engineering Implementation**
*   **Enablement**: Requires explicit installation of Operators via Helm.
*   **Maintenance**: Engineering teams must manage the lifecycle of the Operator/Agent (upgrades, compatibility matrix with K8s versions).
*   **Security**: Requires managing API Keys / Ingestion Keys as Kubernetes Secrets.

---

### 2.3 Engineering Constraints on AKS Automatic
When deploying third-party SaaS agents on AKS Automatic, specific platform constraints must be engineered around:

*   **DaemonSet Resource Limits:** AKS Automatic manages node resources strictly. Third-party agents (e.g., Datadog/Dynatrace DaemonSets) *must* have explicit Resource Requests and Limits defined. Unlike standard AKS, "burstable" QoS classes might be evicted more aggressively if they impinge on system-reserved resources.
*   **Privileged Access:** While AKS Automatic allows DaemonSets, it enforces strict security policies. Agents requiring deep eBPF access to the host kernel must be vetted against the "Azure Linux" policy baseline.
*   **Kubelet Certificate Rotation:** Some legacy SaaS agents mount the kubelet certificate (`/etc/kubernetes/certs/kubeletserver.crt`) directly. In AKS Automatic, these certificates rotate frequently. Agents must support auto-discovery or use the K8s API server proxy rather than direct kubelet scraping to avoid breakage during rotation.
*   **Operator Lifecycle:** Dynatrace and Datadog strongly recommend using their **Operators** (managed deployments) over raw DaemonSets on auto-managed clusters to better handle node scaling and lifecycle events initiated by the AKS Automatic control plane.

---

## 3. Comparative Analysis

| Feature | Azure Managed (Prometheus/Grafana) | SaaS (Dynatrace/Datadog) |
| :--- | :--- | :--- |
| **Primary Capability** | **Infrastructure Centric.** Best for Cluster, Node, Pod metrics. Strong Prometheus compatibility. | **Application Centric.** Best for APM, Distributed Tracing, Code Profiling, Real User Monitoring (RUM). |
| **Complexity of Implementaton** | **Low.** Native integration. "Turn on" via Terraform. No keys to manage. | **Medium.** Requires Helm Chart management, Secret management (API Keys), and Operator lifecycle updates. |
| **Ease of Use** | **Medium.** Requires knowledge of PromQL and Grafana dashboard building. "DIY" feel. | **High.** "Out of the box" magical dashboards. Auto-instrumentation requires zero code changes for many languages. |
| **Cost Model** | **consumption-based (Metric Samples).** Very cheap for infrastructure. Can spike with high-cardinality custom metrics. | **License-based (Per Node/Host) + Ingestion.** High baseline cost per node. generally 3x-5x more expensive for pure infra monitoring. |
| **Data Sovereignty** | Data stays within Azure tenant boundaries. | Data leaves Azure to Vendor Cloud (Compliance consideration). |
| **Lock-in** | Locked to Azure Platform. | Locked to Vendor (proprietary agents), but portable across clouds. |

---

## 4. Co-existence Strategy: The "Why, What, How"

**Can they co-exist?**
**Yes.** Not only can they co-exist, but for large enterprises, this is often the standard pattern.

### 4.1 WHY? (The Rationale)
1.  **Cost Optimization (The "Tax" Argument)**: 
    *   SaaS vendors charge a premium per "Host" or "Node". For large AKS Automatic clusters with hundreds of nodes, paying ~$20-$40/node/month just for CPU/Memory metrics to a SaaS vendor is wasteful.
    *   Azure Managed Prometheus captures these standard infra metrics at a fraction of the cost.
2.  **Audience Separation**:
    *   **Platform Engineers** care about utilization, quotas, scaling events, and node health. They prefer flexible, queryable data (PromQL/Grafana).
    *   **Application Developers** care about transaction latency, stack traces, and database calls. They prefer curated, clickable flows (Dynatrace PurePath / Datadog APM).
3.  **Redundancy**:
    *   If the SaaS agent fails (or the vendor is down), Azure Metrics provide a "Last Line of Defense" for cluster health status.

### 4.2 WHAT? (The Separation of Concerns)
*   **In Azure (Managed Stack):**
    *   Cluster State Metrics (Kube-state-metrics).
    *   Node Resources (CPU, Memory, Disk I/O).
    *   Control Plane Logs (API Server auditing).
    *   Basic Pod Health (Restarts, OOMKills).
*   **In SaaS (Vendor Stack):**
    *   Application Traces (OpenTelemetry / Proprietary Tracing).
    *   Custom Application Metrics (Business Logic counter).
    *   Real User Monitoring (RUM).
    *   Log Analytics (if richer query capabilities are needed than Azure Log Analytics).

### 4.3 HOW? (Engineering Implementation)

#### **Step 1: Deploy Azure Managed Stack for Base Layer**
Enable Managed Prometheus and Grafana on the AKS Cluster. This becomes the "Cluster Dial Tone".
*   *Action:* Terraform enablement of `monitor_metrics`.

#### **Step 2: Deploy SaaS Agent with Scoped Configuration**
Deploy the SaaS Agent (e.g., Datadog/Dynatrace) but **disable** redundant infrastructure scraping if the vendor pricing allows it, or simply use it for APM.
*   *Crucial Engineering Detail:* If using Datadog, you might disable the "Infrastructure" monitoring or reduce the retention if you rely on Azure Monitor for historical trending.
*   *Configuration:* Filter metrics in the SaaS agent `values.yaml` to drop high-volume, low-value generic k8s metrics that are already in Azure Monitor, sending only custom App Metrics to the SaaS backend to save ingestion costs.

#### **Step 3: Correlation (The "Glue")**
Use **Dashboard Links**.
*   In Grafana (Azure): Create a dynamic link on a Pod panel that constructs a URL to the SaaS APM view for that specific pod.
    *   *Example:* `https://app.datadoghq.com/apm/service/${pod_service_name}`
*   This grants Platform Engineers a "Drill-down to Code" button without migrating all data to one store.

## 5. Summary Conclusion

*   **Small/Startup**: Choose **one** stack. 
    *   If budget is tight: Azure Managed.
    *   If velocity/APM is #1: SaaS.
*   **Enterprise/Scale**: Choose **Hybrid**. 
    *   Use Azure Managed for the heavy lifting of infrastructure metrics and long-term retention.
    *   Use SaaS strictly for high-value APM and Troubleshooting workflows.
