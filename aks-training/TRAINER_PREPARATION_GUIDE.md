# AKS Training: Facilitator Preparation Guide

> **Session:** AKS & Cloud-Native Platform Training  
> **Audience:** 25 participants — Engineers, Executives, Operations Team  
> **Prepared for:** Lead Trainer / Facilitator  
> **Estimated Prep Time:** 2–3 hours the evening before; 30 minutes on the day

---

## 1. Know Your Room Before You Walk In

### Audience Segmentation

You have three distinct groups in the room. Each has a different motivation for being there and a different definition of "value".

| Segment | What They Care About | What Will Lose Them | Your Goal With Them |
|---------|---------------------|---------------------|---------------------|
| **Engineers** (devs, platform, DevOps) | Technical depth, real commands, architecture decisions | Death by slides, no hands-on | Get them excited to build things |
| **Executives** | Business impact, cost, risk, speed to market | Too much YAML, acronym soup | Connect every concept to a business outcome |
| **Operations** | Day-to-day stability, runbooks, what breaks, how to fix it | Abstract concepts with no operational grounding | Give them the "what do I do at 2am" perspective |

### Pre-Session: Identify Who Is Who

Before the session, try to obtain the attendee list and mark each person:
- `[E]` = Engineer
- `[X]` = Executive
- `[O]` = Operations

Place yourself where you can make eye contact with all three groups. Seat executives near the front. Place engineers near power outlets (they will want laptops open).

---

## 2. Material Preparation Checklist

### Content Files (confirm all are accessible)

- [ ] [`learning-path/PART_1_CONTAINERS.md`](learning-path/PART_1_CONTAINERS.md) — Containers & Docker
- [ ] [`learning-path/PART_2_KUBERNETES_BASICS.md`](learning-path/PART_2_KUBERNETES_BASICS.md) — Kubernetes Fundamentals
- [ ] [`learning-path/PART_3_HELM.md`](learning-path/PART_3_HELM.md) — Helm Package Management
- [ ] [`learning-path/PART_4_ARGOCD.md`](learning-path/PART_4_ARGOCD.md) — GitOps with ArgoCD
- [ ] [`learning-path/PART_5_PRODUCTION_PATTERNS.md`](learning-path/PART_5_PRODUCTION_PATTERNS.md) — Production Patterns
- [ ] [`TRAINING_SESSION_SCRIPT.md`](TRAINING_SESSION_SCRIPT.md) — Your in-room script

### Slides / Visuals to Prepare

You don't need a deck for every slide, but prepare visuals for these specific moments — they land much better visually than text:

| Visual Needed | Why It Matters | Suggested Tool |
|---------------|---------------|----------------|
| Container vs VM diagram | Executives struggle with "what is a container?" without a picture | Draw.io or Keynote |
| Kubernetes resource hierarchy tree | Shows the layered structure learners will build up | Whiteboard is fine |
| Helm values → template → deployed YAML flow | Shows how one values file becomes many Kubernetes resources | Animated slide works well |
| GitOps commit → ArgoCD sync → cluster flow | The "no kubectl" moment — executives love this | Simple flowchart |
| Three pillars of production (from Part 5) | Gives executives a framework summary | Single summary slide |

### Environment Setup (Engineers)

If engineers will follow along with commands, ensure the following are ready **the night before**:

```bash
# Verify AKS cluster is reachable
kubectl get nodes

# Verify Helm is installed
helm version

# Verify ArgoCD is accessible
argocd app list

# Pre-pull key images to save demo time
docker pull nginx:1.25
docker pull mcr.microsoft.com/dotnet/aspnet:8.0
```

- Confirm all engineers can authenticate to the AKS cluster
- Have a fallback demo environment ready if cluster access fails
- Test all `kubectl port-forward` commands in advance — they often fail on corporate VPNs

---

## 3. Session Timing Plan

**Recommended format for a single all-day session or split across 2 half-days.**

### Option A: Full Day (6 hours)

| Time | Module | Key Audience Focus |
|------|--------|--------------------|
| 09:00–09:15 | Welcome, objectives, agenda | All |
| 09:15–10:00 | Part 1: Containers | All — use the VM vs Container story |
| 10:00–10:15 | ☕ Break | — |
| 10:15–11:15 | Part 2: Kubernetes Basics | Engineers + Ops — deep on labels, Services |
| 11:15–11:45 | Part 3: Helm - Overview | All — focus on "why we need packaging" |
| 11:45–12:30 | Part 3: Helm - Hands-on | Engineers + Ops |
| 12:30–13:15 | 🍽️ Lunch | — |
| 13:15–14:00 | Part 4: ArgoCD & GitOps | All — start with the "commit = deploy" story for execs |
| 14:00–14:45 | Part 5: Production Patterns | All — execs care about cost & resilience; ops care about PDB |
| 14:45–15:00 | ☕ Break | — |
| 15:00–15:45 | Q&A, Troubleshooting Scenarios | Engineers + Ops |
| 15:45–16:00 | Wrap-up, next steps, certifications | All |

### Option B: Two Half-Days

**Day 1 (Morning):** Parts 1, 2, and 3  
**Day 2 (Morning):** Parts 4, 5, Q&A, and next steps

---

## 4. Anticipated Questions by Audience — and How to Answer Them

### Executive Questions

**Q: "How does this reduce our cloud costs?"**  
> "AKS with autoscaling means we only pay for nodes when they're needed. Containers are much denser than VMs — you can run 10x more workloads on the same hardware. Our benchmarks show 40–60% infrastructure cost reduction vs traditional VM deployments."

**Q: "How long would it take our team to get productive with this?"**  
> "Following this learning path — roughly 10–12 weeks for deep mastery. For a basic productive deployment, most engineers are comfortable in 3–4 weeks. Executives don't need to be hands-on at all — they just need to understand the model."

**Q: "What's our risk if AKS or ArgoCD has an outage?"**  
> "Azure guarantees 99.9% uptime on the AKS control plane. ArgoCD runs inside the cluster, so your running applications are unaffected if ArgoCD is temporarily unavailable — they keep running. Only new deployments are paused. This is far better than traditional deployment pipelines where an outage stops everything."

**Q: "Do we need to retrain all our developers?"**  
> "Not from scratch. Developers already know how to write code. This training focuses on the deployment and operation layer. Engineers with Docker experience can be productive with Kubernetes in 2–3 weeks."

---

### Operations Questions

**Q: "How do I know when something is broken before users tell me?"**  
> "That's exactly what Part 5 covers. Prometheus + Grafana + AlertManager gives you dashboards and proactive alerts. You set thresholds — error rate, memory usage, pod restarts — and AlertManager pages you before users notice."

**Q: "If a deployment breaks on a Friday, can we roll it back instantly?"**  
> "Yes. With Helm and ArgoCD, a rollback is a single command — or a Git revert if you run anything through ArgoCD. The previous working state of your application is always stored in Helm's release history."

**Q: "Who can deploy to production — can a developer accidentally push to prod?"**  
> "ArgoCD Projects control this. You configure exactly which teams can deploy to which namespaces from which Git repositories. Engineers can deploy to dev freely but need an approved PR to merge to the production branch."

**Q: "What does our on-call runbook look like?"**  
> "We'll walk through the four most common scenarios in Part 5: CrashLoopBackOff, ImagePullBackOff, Pending pods, and Service not responding. Each has a clear investigation and fix path."

---

### Engineer Questions

**Q: "Why Helm and not Kustomize?"**  
> "Helm gives you packaging, versioning, and a release upgrade/rollback model out of the box. Kustomize is simpler but has no native rollback. In an enterprise AKS context with multiple environments, Helm's chart model integrates better with ArgoCD's release tracking. Both are valid — this training focuses on the more widely adopted path."

**Q: "Can we use our existing CI/CD (Jenkins, GitHub Actions) alongside ArgoCD?"**  
> "Yes — this is the recommended pattern. CI (Jenkins/GHA) builds and publishes the container image and bumps the image tag in the Helm values file in Git. ArgoCD detects the change in Git and syncs to the cluster. CI pushes code; ArgoCD does the deploying. They don't overlap."

**Q: "How do Secrets work — is Kubernetes Secrets secure?"**  
> "Base64 encoding in Kubernetes is obfuscation, not encryption. In AKS production we pair Kubernetes Secrets with the Secrets Store CSI Driver and Azure Key Vault. The secret value never lives in etcd or in Git — it's fetched from Key Vault at runtime."

---

## 5. Day-Of Checklist (30 Minutes Before Start)

- [ ] Display the learning-path README on the projector while people settle in
- [ ] Confirm screen sharing is working (if hybrid/virtual participants)
- [ ] Have `kubectl`, `helm`, and `argocd` CLI ready in a terminal window
- [ ] Print or share a digital copy of the Trainer Script (`TRAINING_SESSION_SCRIPT.md`)
- [ ] Set a visible countdown timer for breaks
- [ ] Have a whiteboard or digital whiteboard ready for impromptu diagrams
- [ ] Distribute attendee survey link (for post-session feedback) — send it now so it's ready
- [ ] Confirm who is taking notes / will distribute the session summary
- [ ] Have water at your station

---

## 6. Tone and Facilitation Tips

- **Don't apologise for YAML.** Acknowledge it's verbose, then show how Helm abstracts it
- **Name-drop real companies** — Netflix, Spotify, Google, Shopify use these tools in production. Executives respond to social proof
- **Pause after each module summary** — ask "What questions do you have before we move on?" This prevents questions from stacking up
- **For executives: always connect to the business.** After any technical concept, add: *"What this means for the business is..."*
- **For operations: always ground in operations.** After any concept, add: *"In your on-call shift, this means..."*
- **For engineers: invite challenges.** Ask them "What would break this?" — they engage more when invited to find the limits
- **Manage the "rabbit hole" risk.** When a question goes deep, say: *"Great question — let's put that in the parking lot and address it at the end or offline"*

---

## 7. Parking Lot Template

Track unresolved questions here during the session:

| # | Question | Raised by | Owner | Resolution |
|---|----------|-----------|-------|------------|
| 1 | | | | |
| 2 | | | | |

---

## 8. Post-Session Actions

- [ ] Share all learning-path files with participants (provide the `learning-path/` directory link)
- [ ] Record any parking lot items and assign owners
- [ ] Send a follow-up email within 24 hours with: key takeaways, links to certification paths, the hands-on exercise files
- [ ] Schedule a 30-minute follow-up check-in 2 weeks later for engineers
