# Learning Path: Complete Guide Index

Welcome to the comprehensive AKS training learning path! This series takes you from containerization basics to production-ready Kubernetes deployments.

---

## 📚 Learning Path Overview

### [Part 1: Containers Deep Dive](PART_1_CONTAINERS.md)
**Duration:** 1-2 weeks

Learn to containerize applications with Docker:
- ✅ Write production-ready Dockerfiles
- ✅ Build and run containers locally
- ✅ Optimize images with layer caching and multi-stage builds
- ✅ Reduce image size by 80%+

**Key Outcomes:**
- Create minimal, secure container images
- Understand Docker layer caching
- Debug container issues

**External Resources:**
- [Docker Official Docs](https://docs.docker.com/)
- [Play with Docker](https://labs.play-with-docker.com/)
- [Google Distroless Images](https://github.com/GoogleContainerTools/distroless)

---

### [Part 2: Kubernetes Basics Deep Dive](PART_2_KUBERNETES_BASICS.md)
**Duration:** 2-3 weeks

Master core Kubernetes concepts:
- ✅ Deploy and manage Pods
- ✅ Create Services for networking
- ✅ Implement health checks (liveness, readiness, startup)
- ✅ Understand Kubernetes architecture

**Key Outcomes:**
- Deploy workloads to Kubernetes
- Configure service discovery
- Implement robust health checks

**External Resources:**
- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [Kubernetes Playground](https://www.katacoda.com/courses/kubernetes)
- [Play with Kubernetes](https://labs.play-with-k8s.com/)

---

### [Part 3: Helm Deep Dive](PART_3_HELM.md)
**Duration:** 2 weeks

Package and deploy applications with Helm:
- ✅ Create custom Helm charts
- ✅ Deploy to multiple environments (Dev, Staging, Prod)
- ✅ Perform upgrades and rollbacks
- ✅ Manage dependencies

**Key Outcomes:**
- Build reusable Helm charts
- Manage multi-environment deployments
- Master upgrade strategies

**External Resources:**
- [Helm Official Docs](https://helm.sh/docs/)
- [Artifact Hub](https://artifacthub.io/)
- [Bitnami Charts](https://github.com/bitnami/charts)

---

### [Part 4: ArgoCD Deep Dive](PART_4_ARGOCD.md)
**Duration:** 2 weeks

Implement GitOps with ArgoCD:
- ✅ Create ArgoCD Applications
- ✅ Deploy via Git commits (no kubectl needed!)
- ✅ Monitor sync status and health
- ✅ Implement App of Apps pattern

**Key Outcomes:**
- Automate deployments with GitOps
- Git as single source of truth
- Zero-downtime deployments

**External Resources:**
- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)
- [ArgoCD Examples](https://github.com/argoproj/argocd-example-apps)
- [OpenGitOps](https://opengitops.dev/)

---

### [Part 5: Production Patterns Deep Dive](PART_5_PRODUCTION_PATTERNS.md)
**Duration:** 2-3 weeks

Master production-ready patterns:
- ✅ Configure auto-scaling (HPA, VPA, Cluster Autoscaler)
- ✅ Set up monitoring with Prometheus & Grafana
- ✅ Implement alerting and observability
- ✅ Practice troubleshooting common issues

**Key Outcomes:**
- Build resilient, scalable applications
- Implement comprehensive monitoring
- Debug production issues

**External Resources:**
- [Prometheus Docs](https://prometheus.io/docs/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [OpenTelemetry](https://opentelemetry.io/)

---

## 🎯 Learning Path Progression

```
Week 1-2:   Part 1 - Containers
            ↓
Week 3-5:   Part 2 - Kubernetes Basics
            ↓
Week 6-7:   Part 3 - Helm
            ↓
Week 8-9:   Part 4 - ArgoCD
            ↓
Week 10-12: Part 5 - Production Patterns
```

**Total Duration:** 10-12 weeks for complete mastery

---

## 📖 How to Use This Learning Path

### 1. **Sequential Learning (Recommended)**
Follow the parts in order. Each builds on the previous:
- Start with Part 1 (Containers)
- Complete hands-on exercises
- Move to next part only after mastering current one

### 2. **Targeted Learning**
Jump to specific topics based on your needs:
- Already know Docker? Skip to Part 2
- Need only GitOps? Focus on Part 4
- Production issues? Go to Part 5

### 3. **Hands-On First**
Each part includes:
- ✅ Conceptual explanations
- ✅ Real-world examples
- ✅ Hands-on exercises
- ✅ External references

**Best Practice:** Type every command yourself. Don't copy-paste.

---

## 🛠️ Prerequisites

### Required Knowledge
- Basic Linux command line
- Basic understanding of web applications
- Git fundamentals

### Required Tools
```bash
# Install Docker
https://docs.docker.com/get-docker/

# Install kubectl
https://kubernetes.io/docs/tasks/tools/

# Install Helm
https://helm.sh/docs/intro/install/

# Install ArgoCD CLI
https://argo-cd.readthedocs.io/en/stable/cli_installation/

# Access to AKS cluster (or local Kubernetes)
# - AKS: https://learn.microsoft.com/en-us/azure/aks/
# - Minikube: https://minikube.sigs.k8s.io/
# - Kind: https://kind.sigs.k8s.io/
```

---

## 🎓 Certifications

After completing this learning path, consider these certifications:

### Kubernetes Certifications
- **CKAD** (Certified Kubernetes Application Developer)
  - Focus: Application deployment
  - Duration: 2 hours
  - Cost: $395
  - [More Info](https://www.cncf.io/certification/ckad/)

- **CKA** (Certified Kubernetes Administrator)
  - Focus: Cluster administration
  - Duration: 2 hours
  - Cost: $395
  - [More Info](https://www.cncf.io/certification/cka/)

- **CKS** (Certified Kubernetes Security Specialist)
  - Focus: Security
  - Prerequisites: CKA
  - [More Info](https://www.cncf.io/certification/cks/)

### Azure Certifications
- **AZ-104** (Azure Administrator)
- **AZ-305** (Azure Solutions Architect Expert)

---

## 🌐 Community & Support

### Join the Community
- **CNCF Slack:** https://slack.cncf.io/
  - Channels: #kubernetes-users, #helm-users, #argo-cd
- **Kubernetes Forum:** https://discuss.kubernetes.io/
- **Stack Overflow:** Tags `kubernetes`, `helm`, `argocd`
- **Reddit:** r/kubernetes

### Stay Updated
- **KubeCon:** https://www.cncf.io/kubecon-cloudnativecon-events/
- **CNCF YouTube:** https://www.youtube.com/c/cloudnativefdn
- **Kubernetes Blog:** https://kubernetes.io/blog/

---

## 📊 Track Your Progress

### Checklist

**Part 1: Containers**
- [ ] Created first Dockerfile
- [ ] Built and ran container locally
- [ ] Optimized image size
- [ ] Implemented multi-stage build

**Part 2: Kubernetes**
- [ ] Deployed first Pod
- [ ] Created ClusterIP Service
- [ ] Implemented health checks
- [ ] Debugged pod issues

**Part 3: Helm**
- [ ] Created custom Helm chart
- [ ] Deployed to Dev and Prod
- [ ] Performed upgrade
- [ ] Rolled back deployment

**Part 4: ArgoCD**
- [ ] Installed ArgoCD
- [ ] Created Application
- [ ] Deployed via Git commit
- [ ] Monitored sync status

**Part 5: Production**
- [ ] Configured HPA
- [ ] Set up Prometheus & Grafana
- [ ] Created alert rules
- [ ] Troubleshot production issue

---

## 🚀 Next Steps After Completion

1. **Build a Real Project**
   - Deploy your own microservices application
   - Implement full CI/CD pipeline
   - Add monitoring and alerting

2. **Contribute to Open Source**
   - Find projects on GitHub
   - Submit PRs to Helm charts
   - Help with documentation

3. **Advanced Topics**
   - Service Mesh (Istio, Linkerd)
   - Serverless (Knative, OpenFaaS)
   - Policy Management (OPA, Kyverno)
   - Security (Falco, Trivy)

4. **Get Certified**
   - CKAD or CKA
   - Azure certifications

---

## 📝 Additional Resources

### Books
- "Kubernetes in Action" by Marko Lukša
- "Docker Deep Dive" by Nigel Poulton
- "The DevOps Handbook" by Gene Kim

### Online Courses
- [Kubernetes for Developers (LFS259)](https://training.linuxfoundation.org/training/kubernetes-for-developers/)
- [Kubernetes Fundamentals (LFS258)](https://training.linuxfoundation.org/training/kubernetes-fundamentals/)

### Blogs & Newsletters
- [Kubernetes Blog](https://kubernetes.io/blog/)
- [CNCF Blog](https://www.cncf.io/blog/)
- [KubeWeekly Newsletter](https://www.cncf.io/kubeweekly/)

---

## 💡 Tips for Success

1. **Practice Daily:** Even 30 minutes a day builds muscle memory
2. **Break Things:** Learn by debugging your own mistakes
3. **Ask Questions:** No question is too basic
4. **Document Your Journey:** Keep notes of what you learn
5. **Teach Others:** Best way to solidify knowledge

---

**Ready to start?** → [Begin with Part 1: Containers](PART_1_CONTAINERS.md)

**Questions?** → Open an issue or reach out on Slack!
