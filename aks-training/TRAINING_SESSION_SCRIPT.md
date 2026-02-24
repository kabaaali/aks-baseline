# AKS Training: Facilitator Script

> **How to use this script:**  
> Read the **bold text** aloud. The _italicised notes_ are stage directions for you — don't read them out.  
> `[PAUSE]` = stop, make eye contact, wait 3–5 seconds before continuing.  
> `[ASK]` = throw the question to the room and wait for responses.  
> `[EXEC]` = moment specifically framed for executives.  
> `[OPS]` = moment specifically framed for operations.  
> `[ENG]` = moment specifically framed for engineers.

---

## OPENING (9:00–9:15)

_Walk to the front. Wait for the room to settle. Don't start over noise._

**"Good morning everyone. Thank you for being here today.**

**My name is [YOUR NAME], and over the next [half day / full day], we're going to cover something that is fundamentally changing how software is built, deployed, and operated at scale.**

**Before I start — hands up: who here has heard the word 'Kubernetes' before?"**

_Wait for hands._

**"And who has actually run a Kubernetes command — even once?"**

_Note the ratio. This tells you how deep you can go in early sections._

**"Perfect. Here's what I want you to know: whether you're a developer, an operations engineer, or an executive — by the end of today, you will have a clear mental model of how cloud-native platform engineering works, why we're moving to it, and what it means for your day-to-day work."**

`[PAUSE]`

**"Let me tell you what we're NOT going to do today. We are not going to memorise YAML syntax. We are not going to sit through a lecture on abstract cloud concepts. What we ARE going to do is understand each layer of this platform — why it exists, what problem it solves, and how the layers work together."**

_Draw a quick 5-box stack on the whiteboard:_
```
[ Part 5: Production Patterns  ]
[ Part 4: ArgoCD / GitOps      ]
[ Part 3: Helm                 ]
[ Part 2: Kubernetes           ]
[ Part 1: Containers           ]
```

**"Think of this as a platform stack. Each layer sits on top of the previous one. We'll build this understanding from the ground up. By the time we reach the top of this stack, you'll see how a single line of code committed to Git becomes a running, monitored, auto-scaling application in production — automatically, without a human pushing a button."**

`[EXEC]` **"Executives — that last part is the headline. Deployments that happen automatically, safely, with a full audit trail, and with instant rollback. That is the business case for everything we're discussing today."**

`[PAUSE]`

**"Any questions before we start? No? Great — let's go."**

---

## PART 1: CONTAINERS (9:15–10:00)

_Open PART_1_CONTAINERS.md or display the container diagram._

### The Problem Statement

**"Let me start with a story. Imagine you have a developer who builds an application on their MacBook. It works perfectly. They hand it to the operations team to deploy. The operations team deploys it to a Linux server. It crashes."**

**"Why? Different operating system version. Different Python version. Different library installed. The developer says 'it works on my machine.' The ops engineer says 'well, it's not on your machine anymore.' Sound familiar?"**

`[ASK]` **"How many of you have experienced that exact situation?"**

_Wait for responses. Laugh if they laugh._

**"Containers solve this problem entirely. A container packages your application AND its entire environment — the runtime, the libraries, the operating system dependencies — into a single, portable unit. You ship the whole environment, not just the code."**

`[EXEC]` **"The business impact: your team stops losing days to 'environment issues' before every release. What used to take hours of debugging now never happens, because the environment that passed testing IS the environment that runs in production. Same thing. Bit-for-bit."**

---

### The Dockerfile

**"The foundation of every container is a file called a Dockerfile. Think of it as a recipe. It tells Docker: start with this base operating system, install these libraries, copy this application code, and when someone starts this container, run this command."**

_Reference the Part 1 Foundational Structure section._

**"Now here's the important design principle that we've documented in our learning materials — and I want you to remember this because it explains a lot of decisions you'll see in real Dockerfiles."**

**"Docker builds images in layers. Each instruction in a Dockerfile creates a layer. And layers are cached."**

_Write this on the whiteboard:_
```
[Layer 1] Base OS             ← almost never changes → always cached
[Layer 2] Install tools       ← rarely changes → usually cached
[Layer 3] Copy dependencies   ← changes when libraries change
[Layer 4] Install libraries   ← expensive — cached when Layer 3 unchanged
[Layer 5] Copy app code       ← changes every commit → always rebuilt
```

**"The golden rule: put what changes LEAST at the top. Put what changes MOST at the bottom. If you violate this rule, Docker will rebuild every layer from scratch on every single commit. In a team of 10 engineers committing 5 times a day, that's hours of wasted CI time every week."**

`[ENG]` **"Engineers — when you review each other's Dockerfiles, this is your first check. Is the order optimised for caching?"**

---

### Multi-Stage Builds

**"One more foundational concept before we move on: multi-stage builds."**

**"Here's the problem: to build your application you need a compiler, a package manager, a build tool. But once the application is compiled, you don't need any of those tools to RUN it. Why ship a 750-megabyte SDK image to production when your compiled application only needs a 200-megabyte runtime?"**

**"Multi-stage builds solve this with a simple idea: use a big build image to compile your code, then copy only the compiled output into a small, clean production image. The SDK never makes it to production."**

`[EXEC]` **"The business case: smaller images mean faster deployments, less storage cost, and critically — fewer attack surfaces. Every tool you don't ship is a tool an attacker can't exploit."**

`[PAUSE]`

`[ASK]` **"Questions on containers before we move to Kubernetes?"**

---

## BREAK (10:00–10:15)

**"Let's take a 15-minute break. Back at [TIME]."**

---

## PART 2: KUBERNETES (10:15–11:15)

_Open PART_2_KUBERNETES_BASICS.md._

### Setting the Stage

**"Containers are great. But imagine you have 50 container images to run, across 20 servers, with different amounts of traffic hitting each service at different times. How do you decide which container runs on which server? What happens when a server crashes? How do you update your application without downtime?"**

**"That is the problem Kubernetes solves. Kubernetes is an orchestrator. You tell it WHAT you want — 'I want 5 copies of this container running, each with at least 256 megabytes of memory' — and Kubernetes figures out HOW to make that happen. And more importantly, it continuously monitors reality and corrects any drift from what you declared."**

`[EXEC]` **"Think of Kubernetes like a very reliable operations manager who never sleeps, never misses an alert, and immediately restores anything that breaks — 24/7, automatically."**

---

### The Resource Hierarchy

_Point to the hierarchy on the whiteboard or display from the Foundational Structure section:_

**"Kubernetes organises everything in a hierarchy. At the top: the Cluster — that's your entire AKS environment. Inside the cluster, we have Namespaces — think of these as separate rooms in a building. Dev, Staging, and Production each get their own namespace. Resources in different namespaces don't accidentally interfere with each other."**

**"Inside a namespace, the key resources are:"**

- **"A Deployment — which manages your application and ensures the right number of copies are always running"**
- **"A Pod — the actual running unit. This is your container(s) plus shared networking and storage"**
- **"A Service — a stable network address that acts as a load balancer in front of your Pods"**

**"Here's an important concept that trips up almost every newcomer to Kubernetes."**

**"Pods are disposable. They are designed to die and be replaced. Every time a Pod restarts, it gets a completely new IP address. If your application talks directly to a Pod's IP address, it will break every time that Pod restarts."**

**"A Service solves this. A Service gets a stable virtual IP that never changes. It automatically discovers all healthy Pods behind it via labels, and load-balances traffic across them. Your applications ALWAYS talk to the Service, never directly to a Pod."**

`[OPS]` **"Operations perspective: if you're ever troubleshooting 'traffic is not reaching the application', the first thing you check is: does the Service selector match the Pod labels? We'll show you exactly how to do that in the troubleshooting section."**

---

### Why Labels Are Everything

**"I want to spend two minutes on labels because they are the nervous system of Kubernetes — and a source of the most frustrating bugs you'll ever see."**

**"Labels are simple key-value pairs on any Kubernetes resource. `app: my-service`. `environment: production`. `version: v1.2.3`. They look trivial. But they are the mechanism by which everything discovers everything else."**

**"Your Service finds its Pods by matching labels. Your HPA targets a Deployment by name. Your NetworkPolicy restricts traffic by labels. If your Pod has label `app: myapp` but your Service is looking for `app: my-app` — with a hyphen — traffic fails silently. No error message. Just: nothing works."**

**"The fix is a consistent labelling standard applied to every resource. Our learning materials define this standard. Stick to it."**

`[PAUSE]`

`[ASK]` **"Has anyone seen a mystery networking failure that turned out to be a typo in a label? I'll wait — this is very common."**

_Wait for responses. This usually generates a story or two._

**"Kubernetes health checks — liveness, readiness, and startup probes — are covered in detail in the materials. The short version: always implement all three for production workloads. This is what tells Kubernetes whether your application is alive, whether it's ready to receive traffic, and whether it's finished booting. Without them, Kubernetes is flying blind."**

`[PAUSE]`

`[ASK]` **"Questions on Kubernetes basics?"**

---

## PART 3: HELM (11:15–12:30)

_Open PART_3_HELM.md._

### The Problem Helm Solves

**"You've learned to write Kubernetes YAML. Now imagine you need to deploy the same application to Dev, Staging, and Production. Dev needs 1 replica with 100 megabytes of memory. Production needs 10 replicas with 2 gigabytes and TLS certificates and autoscaling enabled."**

**"Without Helm, you maintain three separate sets of YAML files that are 95% identical but differ in those critical parameters. You change something in one, forget to update the others. They drift. Bugs appear only in production. Your operations team starts maintaining three parallel universes."**

**"Helm solves this with packaging and templating. One Helm chart contains the template — the structure — of all your Kubernetes resources. A values file contains the configuration — the numbers and settings that change per environment. Helm combines them to produce the correct YAML for each environment."**

`[EXEC]` **"The business outcome: one version of the truth for how an application deploys. Fewer human errors. Faster onboarding for new environments. Full upgrade and rollback history out of the box."**

---

### The Chart Structure

_Display or draw the chart directory structure from the Foundational Structure section._

**"A Helm chart has a specific directory structure. Let's walk through the key files."**

**"`Chart.yaml` — the identity document. Name, version, description. Helm won't even open a chart without this."**

**"`values.yaml` — this is the most important file to understand conceptually. Think of it as the public API of your chart. Every parameter that a user can configure must have a default value here. If something is in `values.yaml`, it can be overridden by an environment-specific file. If it's not, it's hardcoded."**

**"`templates/` directory — this is where your Kubernetes manifests live, but as templates with variables. Instead of `replicas: 3`, you write `replicas: {{ .Values.replicaCount }}`. Helm replaces these at install time with the actual values."**

**"`_helpers.tpl` — this is the file most beginners ignore and then come to regret. It defines shared template functions that are imported by all other templates. The most important three are: `fullname` — the resource naming function; `labels` — the full label set; `selectorLabels` — the minimal labels used for Service selectors. If these are inconsistent across your templates, your Service stops finding your Pods."**

`[ENG]` **"Engineers: when you review a new Helm chart, start with `_helpers.tpl`. If it's missing or has inconsistent label definitions, every other resource in the chart is suspect."**

---

### Deploy vs Upgrade vs Rollback

**"Helm tracks every deployment as a numbered revision. Install is Revision 1. Upgrade is Revision 2. Helm stores this history in the cluster."**

**"Rollback is one command: `helm rollback my-app 1`. You're back to Revision 1 in under a minute. This is the safety net that makes teams confident to deploy frequently."**

`[OPS]` **"Operations: if a production deployment goes wrong at 11pm on a Friday, you don't need the developer to fix code. You run `helm rollback`. In most cases, your application is back to the previous working state in 60–90 seconds."**

`[PAUSE]`

`[ASK]` **"Questions on Helm before lunch?"**

---

## LUNCH (12:30–13:15)

**"Excellent. Let's break for lunch. Back at [TIME]. After lunch we're moving into what I think is the most exciting part of this platform — GitOps with ArgoCD."**

---

## PART 4: ARGOCD & GITOPS (13:15–14:00)

_Open PART_4_ARGOCD.md. This is a high-energy section — lean into the "commit = deploy" story._

### The GitOps Pitch

**"I'm going to start Part 4 with a before-and-after scenario. Bear with me for 60 seconds, because this is the moment that usually changes how people think about deployments."**

**"BEFORE GitOps: A developer finishes a feature. They tell the operations team. The operations team logs into the server. They run `kubectl apply` or `helm upgrade`. They hope they're using the right values file. They hope no one else is deploying at the same time. There's no audit log of exactly what changed. If something breaks, they try to remember what they did and reverse it."**

**"AFTER GitOps with ArgoCD: A developer merges a pull request to the main branch on Git. That's it. ArgoCD detects the change in Git within 3 minutes, renders the Kubernetes manifests, compares them to what's running in the cluster, finds the difference, and applies the change. No SSH access. No manual `kubectl`. No human in the deployment loop at all."**

`[EXEC]` **"The audit trail that compliance teams love: Git is the audit log. Every deployment is a commit. Every commit has an author, a timestamp, a description, and a diff. You know exactly who deployed what, when, and what changed. Rollback is `git revert`."**

`[PAUSE]`

**"The principle is called GitOps. Git is the single source of truth. If it's in Git, it runs in the cluster. If it's not in Git, ArgoCD will delete it from the cluster. If someone manually changes something in the cluster with `kubectl`, ArgoCD detects the drift and automatically reverts it."**

`[OPS]` **"Operations: this means no more undocumented manual changes that break production mysteriously. If it's not in Git, it didn't happen. The cluster state and the Git state are always in sync."**

---

### The ArgoCD Application Resource

**"Everything in ArgoCD is configured through Kubernetes resources. The core one is called an 'Application'. Let me walk you through its four sections — and trust me, once you understand these four sections, you understand 80% of ArgoCD."**

_Display or read the Application YAML from the Foundational Structure section._

**"Section 1: `source` — where is your desired state? A Git repository URL, a branch or tag, and a path within that repository. This is where ArgoCD looks to know what should be running."**

**"Section 2: `destination` — where should it be deployed? Which cluster, and which namespace."**

**"Section 3: `syncPolicy` — how should ArgoCD sync? Automatically when Git changes, or manually when you click a button. For production, you typically set `prune: true` — which removes resources deleted from Git — and `selfHeal: true` — which reverts manual changes."**

**"Section 4: `project` — which ArgoCD project controls access? This is the RBAC layer that prevents, for example, a developer from accidentally deploying to the production namespace."**

---

### App of Apps

**"As you onboard more microservices, you'll end up with 20, 30, 50 ArgoCD Application files. Managing them manually doesn't scale."**

**"The App of Apps pattern is the solution. You create ONE root Application that watches the `apps/` directory in your GitOps repository. When you add a new Application file to that directory and push to Git, ArgoCD automatically registers and deploys it. Onboarding a new microservice becomes: create one YAML file, commit, push."**

`[EXEC]` **"What this means for time-to-production: new services go from idea to production-deployed in minutes, not weeks. The platform handles registration, deployment, monitoring, and rollback automatically."**

`[PAUSE]`

`[ASK]` **"Any questions on ArgoCD or GitOps?"**

---

## PART 5: PRODUCTION PATTERNS (14:00–14:45)

_Open PART_5_PRODUCTION_PATTERNS.md._

### The Production Mindset Shift

**"We've talked about how to build containers, how Kubernetes manages them, how Helm packages them, and how ArgoCD deploys them. Part 5 is about something different: what does it take to leave your application running safely and predictably — without you babysitting it?"**

**"Production readiness in Kubernetes is built on three pillars."**

_Write on whiteboard:_
```
1. RESILIENCE   — it survives spikes and failures automatically
2. OBSERVABILITY — you can SEE what's happening before users complain
3. RELIABILITY   — it fails gracefully and recovers fast
```

---

### Auto-Scaling

**"The Horizontal Pod Autoscaler — HPA — watches your application's CPU and memory usage. When usage gets too high, it automatically adds more Pod replicas. When load drops, it scales back down. You configure a minimum and a maximum."**

**"Here's the prerequisite that trips everyone up: the HPA cannot work unless every Pod declares its resource requests. The HPA calculates: current usage ÷ requested capacity. Without the requested capacity, it's dividing by zero. The HPA shows 'unknown' and never scales."**

`[OPS]` **"Practical note: always set `minReplicas: 2` or higher in production. A single replica means: if that one pod restarts (for any reason), you have an outage. Two replicas means: if one restarts, the other keeps serving traffic."**

---

### Observability Stack

**"The Prometheus and Grafana stack is the industry standard for Kubernetes monitoring. You install it once at the platform level, and every application benefits."**

**"Prometheus collects metrics. Grafana visualises them. AlertManager routes alerts — to Slack for warnings, to PagerDuty for criticals. The connection between your application and Prometheus is a resource called a ServiceMonitor — you define which port your app exposes metrics on, and Prometheus automatically finds and scrapes it."**

**"Alert rules are defined as Kubernetes resources called PrometheusRules — stored in Git, deployed by ArgoCD like any other manifest. Alerts are version-controlled, reviewed, and auditable."**

`[OPS]` **"For your on-call runbook: the four scenarios we'll walk through in the exercises are the four you will see most often in production. CrashLoopBackOff, ImagePullBackOff, Pending pods, and Service not routing. Commit those investigation steps to memory."**

---

### PodDisruptionBudget

**"One final concept that every production cluster must have — the PodDisruptionBudget."**

**"AKS automatically drains nodes for OS patching and cluster upgrades. Without a PodDisruptionBudget, Kubernetes can terminate ALL replicas of your application at once during a drain — causing complete downtime during routine maintenance."**

**"A PodDisruptionBudget is a single YAML file that says: 'when draining nodes, always keep at least 2 replicas of my application alive'. Kubernetes will comply. This is non-negotiable for production workloads."**

`[EXEC]` **"Business translation: your application stays available during Azure maintenance windows. Users experience no downtime. Your SLA is protected."**

`[PAUSE]`

`[ASK]` **"Questions on production patterns before our final break?"**

---

## BREAK (14:45–15:00)

**"Last break. Back in 15 minutes — we'll close with Q&A, troubleshooting scenarios, and next steps."**

---

## Q&A & TROUBLESHOOTING SCENARIOS (15:00–15:45)

_Use the four troubleshooting scenarios from PART_5_PRODUCTION_PATTERNS.md. Walk through them as a group._

**"Rather than just take open questions, let's work through the four most common production scenarios together. I'll give you the symptom. You tell me the investigation steps."**

### Scenario 1: CrashLoopBackOff

**"You get paged at 2am. `kubectl get pods` shows status `CrashLoopBackOff`. What do you do?"**

_Wait for responses from the room. Guide them to:_
1. `kubectl logs <pod-name> --previous` — check the last crash logs
2. `kubectl describe pod <pod-name>` — check events, exit codes
3. Common causes: application error, missing env var, memory limit too low

### Scenario 2: ImagePullBackOff

**"Deployment fails. Pods show `ImagePullBackOff`. Investigation?"**

_Guide to:_
1. `kubectl describe pod` — read the specific error in Events
2. Check if the image tag exists in the registry
3. Verify the imagePullSecret is attached to the deployment

### Scenario 3: Service Not Routing

**"Application pods are running and healthy. But `curl http://my-service` gets no response. What's broken?"**

_Guide to:_
1. `kubectl get endpoints my-service` — are there any endpoints listed?
2. `kubectl get pods --show-labels` — do Pod labels match the Service selector?
3. Check readiness probe — pods may be running but not ready

### Scenario 4: Pending Pods

**"New deployment. Pods are stuck in `Pending`. No errors. No restarts. Why?"**

_Guide to:_
1. `kubectl describe pod` — look at Events: "Insufficient cpu" or "Insufficient memory"
2. `kubectl top nodes` — check available node capacity
3. AKS Automatic will add a node — but check if resource requests are unrealistically high

---

## WRAP-UP (15:45–16:00)

**"Let's bring it all together."**

_Write on whiteboard or point to the five-layer stack:_

**"We started with Containers — the portable, self-contained application unit. We layered on Kubernetes — the orchestration system that manages containers at scale. We added Helm — the packaging and templating system that eliminates environmental drift. We added ArgoCD — the GitOps engine that makes Git the single source of truth, with zero-manual deployments and instant rollback. And we topped it with Production Patterns — autoscaling, observability, and resilience."**

**"Each layer solved a specific problem. Each layer depends on the one below it. Together, they form a platform that can deploy, scale, monitor, and recover applications — automatically, safely, and with a complete audit trail."**

`[EXEC]` **"The executive summary: this platform reduces deployment risk, accelerates time-to-market, improves system reliability, and reduces operational overhead. The companies running this in production — Netflix, Spotify, Microsoft, Google — have moved their entire estate onto this model."**

`[OPS]` **"The operations summary: your on-call experience improves. Fewer mystery incidents. Better observability. Faster rollback. Automated recovery."**

`[ENG]` **"The engineer summary: your code goes from commit to production in minutes, automatically. You own the deployment config in Git. You roll back with one command. Infrastructure stops being your blocker."**

`[PAUSE]`

**"The learning path materials are yours to keep. They're structured in five parts matching exactly what we covered today. Each part has conceptual explanations, real-world examples, hands-on exercises, and external references. Take them, work through them at your own pace, and reach out if you hit walls."**

**"Certifications: if you're an engineer and you want to formalise your Kubernetes knowledge, the CKAD and CKA certifications from the CNCF are the industry standard. Links are in the learning path README."**

`[PAUSE]`

**"Final question I'll leave with you: which part of today is most relevant to what you're working on RIGHT NOW?"**

_Take 2–3 responses from different audience segments._

**"Thank you all. This was a great group. The materials are in your inbox / shared drive. I'll be around for the next 20 minutes for individual questions."**

---

## CLOSING ADMIN

- Share learning-path folder / link
- Confirm follow-up check-in date (2 weeks)
- Collect feedback (survey link)
- Answer individual questions

---

_End of script._
