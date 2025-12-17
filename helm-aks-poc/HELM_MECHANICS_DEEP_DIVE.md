# Helm Mechanics: "Nth Level" Deep Dive

**Target Audience:** DevOps Engineers, Architects, and curious Developers who want to understand the *exact* mechanics of OCI dependency resolution and template rendering.

---

## 1. The "Base Chart" as an OCI Artifact

When the Platform Team pushes the `base-service` chart, they aren't just uploading files. They are creating an **OCI Artifact**.

### The Transfer Protocol
Helm uses the OCI (Open Container Initiative) Distribution Specification, which is the same standard Docker uses.
*   **Command**: `helm push base-service-1.0.0.tgz oci://myregistry.azurecr.io/helm`
*   **What happens on the wire**:
    1.  **Config Blob**: Helm generates a JSON config blob describing the artifact type (`application/vnd.cncf.helm.config.v1+json`).
    2.  **Layer Blob**: The `.tgz` chart archive is uploaded as a single layer (`application/vnd.cncf.helm.chart.content.v1.tar+gzip`).
    3.  **Manifest**: A JSON manifest links the Config and Layer by their SHA-256 digests.

### Immutability
Once pushed, that specific version (e.g., `1.0.0`) is **content-addressable**.
*   **Digest**: `sha256:a1b2c3d4...`
*   If the Platform Team changes one byte of a template and pushes it, it *must* have a new version or digest. A "locked" chart truly cannot change without the consumer knowing.

---

## 2. The Dependency Resolution ("Fetch")

When you run `helm dependency update` (or when CI does it), Helm resolves the abstract requirement into a concrete file.

### Input: `Chart.yaml`
```yaml
dependencies:
  - name: base-service
    version: "^1.0.0"  # SemVer constraint
    repository: oci://myregistry.azurecr.io/helm
```

### Process
1.  **Registry Handshake**: Helm contacts the OCI registry.
2.  **SemVer Calculation**: It requests the list of tags. It finds the highest version matching `^1.0.0` (e.g., `1.0.5`).
3.  **Download**: It downloads the `.tgz` layer blob for `1.0.5`.
4.  **Verification**: It calculates the SHA-256 of the downloaded blob and compares it to the OCI Manifest digest.
5.  **Extraction**: The `.tgz` is unpacked into `charts/base-service/` inside your archive (or cached).

### Output: `Chart.lock`
Helm generates a `Chart.lock` file. This is critical.
```yaml
dependencies:
- name: base-service
  repository: oci://myregistry.azurecr.io/helm
  version: 1.0.5
  digest: sha256:8f9a2b... # The EXACT content hash
```
**Key Takeaway**: Even if the Platform Team overwrites the `1.0.5` tag in the registry (bad practice, but possible), your build will **fail** or refuse to use it because the digest in `Chart.lock` won't match. This guarantees reproducibility.

---

## 3. The "Merge" (Values Coalescing) Algorithm

Helm does not use a text-based merge (like Git). It uses a struct-based composition called **Coalescing**.

### The Hierarchy of Values
Values are processed in a specific order of precedence (Lowest to Highest):

1.  **Base Chart Defaults** (`base-service/values.yaml`)
    ```yaml
    replicaCount: 1
    image: { tag: "latest" }
    ```
2.  **Parent Chart Overrides** (`backend-service/values.yaml`)
    *   *Note*: In your app's `values.yaml`, you nest overrides under the dependency name.
    ```yaml
    base-service:
      replicaCount: 3
    ```
3.  **Release-Specific Overrides** (Flags passed to `helm install`)
    ```bash
    helm install ... --set base-service.replicaCount=5
    ```

### The Algorithm
Helm creates a single consolidated map (dictionary) for the rendering engine.
*   It starts with Map #1.
*   It walks Map #2.
    *   If a key exists in both and both are maps, it **merges** them (recurses).
    *   If a key exists in both and they are primitives (strings/ints), #2 **overwrites** #1.
    *   If a key is a List (Array), #2 **replaces** #1 entirely (it does *not* merge lists).

**Example Trace:**
*   Start: `{ replicaCount: 1, image: { tag: "latest" } }`
*   Apply Parent: `{ base-service: { replicaCount: 3 } }`
*   *Correction*: The Dependency mechanism namespaces the values.
    *   Actual Context passed to `base-service` templates:
        *   It sees its own `values.yaml` combined with the `base-service` key from the parent.
    *   Result View for Base Chart Templates:
        *   `replicaCount`: 3 (Overwritten)
        *   `image.tag`: "latest" (Preserved from Base default)

---

## 4. The Render Phase (Go Templates)

Once the Values Map is final, Helm starts the Template Engine.

1.  **Loading**: It loads all files in `templates/` from the Base Chart AND the App Chart.
2.  **Execution**: It executes the Go Template language (`{{ .Values.replicaCount }}`) against the Coalesced Values Map.
3.  **Context Switching**:
    *   When the Parent Chart renders, `.` is the root.
    *   When the Base Chart (Dependency) renders, Helm invokes it essentially as a sub-process. The scope is scoped down (mostly).
4.  **Output Buffer**: The result of all templates is concatenated into a huge string of YAML.
5.  **YAML Parsing**: Helm parses this string to ensure it is valid YAML.
6.  **Kubernetes Validation**: It compares the resources against the Kubernetes API schema (optional client-side validation).

---

## Summary of the Flow

1.  **OCI Pull**: Download `base-service-1.0.5.tgz` (Verified by Digest).
2.  **Unpack**: Place into build context.
3.  **Load Values**: `Base Values` + `App Values[base-service]` = `Final Context`.
4.  **Execute Templates**: `deployment.yaml` reads `Final Context`.
5.  **Result**: A generated standard Kubernetes Manifest.
