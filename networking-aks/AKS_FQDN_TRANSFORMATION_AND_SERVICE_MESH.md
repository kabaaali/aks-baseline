# AKS FQDN Transformation & Service Mesh Architecture

## Overview

This document explains how FQDNs change throughout the request flow in an **AKS automatic private cluster with NGINX Ingress Controller** (default ingress), how microservices handle these transformations, pod-to-pod communication using internal FQDNs, optional service mesh integration (Istio), and multi-namespace architecture with different FQDN endpoints.

**Key Architecture Points:**
- **NGINX Ingress Controller**: Default ingress in AKS automatic private cluster (not Istio Gateway)
- **Service Mesh (Istio)**: Optional layer for mTLS, advanced traffic management, and observability
- **Pod-to-Pod Communication**: Uses internal FQDNs (service.namespace.svc.cluster.local) for service discovery
- **API Backend Services**: Microservices that handle business logic (not frontend applications)

---

## Table of Contents
1. [FQDN Transformation Flow](#fqdn-transformation-flow)
2. [Microservice Behavior with FQDN Changes](#microservice-behavior-with-fqdn-changes)
3. [Pod-to-Pod Communication](#pod-to-pod-communication)
4. [Service Mesh Integration](#service-mesh-integration)
5. [Multi-Namespace Architecture](#multi-namespace-architecture)
6. [Complete Implementation Example](#complete-implementation-example)

---

## FQDN Transformation Flow

### End-to-End FQDN Changes

```mermaid
sequenceDiagram
    autonumber
    participant Client
    participant CF as Cloudflare
    participant APIM
    participant NGINX as NGINX Ingress<br/>(AKS Default)
    participant UserAPI as User API Backend
    participant OrderAPI as Order API Backend
    participant DB as Database Service

    Note over Client: FQDN #1: Public
    Client->>CF: https://api.example.com/users/123
    Note over Client,CF: Host: api.example.com

    Note over CF: FQDN #2: APIM
    CF->>APIM: https://apim-prod.azure-api.net/users/123
    Note over CF,APIM: Host: api.example.com<br/>X-Forwarded-Host: api.example.com

    Note over APIM: FQDN #3: Private DNS
    APIM->>NGINX: https://users-api.apps.internal.local/api/v1/users/123
    Note over APIM,NGINX: Host: users-api.apps.internal.local<br/>X-Original-Host: api.example.com

    Note over NGINX: FQDN #4: K8s Service
    NGINX->>UserAPI: http://users-api-service.users-ns.svc.cluster.local:8080/api/v1/users/123
    Note over NGINX,UserAPI: Host: users-api-service.users-ns.svc.cluster.local<br/>X-Forwarded-Host: api.example.com

    Note over UserAPI: FQDN #5: Pod-to-Pod (Internal FQDN)
    UserAPI->>OrderAPI: http://orders-api-service.orders-ns.svc.cluster.local:8080/api/orders?userId=123
    Note over UserAPI,OrderAPI: Host: orders-api-service.orders-ns.svc.cluster.local<br/>X-Request-ID: correlation-id

    Note over OrderAPI: FQDN #6: Pod-to-Pod (Internal FQDN)
    OrderAPI->>DB: postgresql://database-service.data-ns.svc.cluster.local:5432/ordersdb
    Note over OrderAPI,DB: Host: database-service.data-ns.svc.cluster.local
```

### FQDN Transformation Table

| Hop | FQDN | DNS Zone | Resolved IP | Protocol | Purpose |
|-----|------|----------|-------------|----------|---------|
| 1 | api.example.com | Public DNS (Cloudflare) | 20.123.45.67 | HTTPS | Client-facing endpoint |
| 2 | apim-prod.azure-api.net | Azure DNS | 10.100.2.20 | HTTPS | APIM gateway endpoint |
| 3 | users-api.apps.internal.local | Azure Private DNS | 10.240.0.10 | HTTPS | NGINX Ingress endpoint (AKS default) |
| 4 | users-api-service.users-ns.svc.cluster.local | CoreDNS (K8s) | 10.0.150.20 | HTTP | User API Kubernetes Service |
| 5 | orders-api-service.orders-ns.svc.cluster.local | CoreDNS (K8s) | 10.0.151.30 | HTTP | Order API service (pod-to-pod via internal FQDN) |
| 6 | database-service.data-ns.svc.cluster.local | CoreDNS (K8s) | 10.0.152.40 | TCP | Database service (pod-to-pod via internal FQDN) |

**Note**: All pod-to-pod communication uses full Kubernetes Service FQDNs for proper service discovery across namespaces.

---

## Microservice Behavior with FQDN Changes

### Understanding the Host Header Transformation

**Key Principle**: Microservices should be **FQDN-agnostic** for their own endpoint but **FQDN-aware** for generating links and calling other services.

### 1. Extracting Original FQDN

```csharp
public class FqdnAwareController : ControllerBase
{
    private readonly ILogger<FqdnAwareController> _logger;

    [HttpGet("users/{id}")]
    public async Task<IActionResult> GetUser(int id)
    {
        // Extract all FQDN-related headers
        var currentHost = HttpContext.Request.Host.ToString(); // users-api-service.users-ns.svc.cluster.local:8080
        var originalHost = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault(); // api.example.com
        var forwardedProto = HttpContext.Request.Headers["X-Forwarded-Proto"].FirstOrDefault(); // https
        var originalUri = HttpContext.Request.Headers["X-Original-URI"].FirstOrDefault(); // /users/123
        
        _logger.LogInformation(
            "Request received - Current Host: {CurrentHost}, Original Host: {OriginalHost}, " +
            "Original URI: {OriginalUri}, Proto: {Proto}",
            currentHost, originalHost, originalUri, forwardedProto);

        // Build the original URL if needed (e.g., for HATEOAS links)
        var originalUrl = $"{forwardedProto}://{originalHost}{originalUri}";
        
        var user = await _userService.GetUserByIdAsync(id);
        
        // Return response with HATEOAS links using original FQDN
        return Ok(new
        {
            id = user.Id,
            name = user.Name,
            _links = new
            {
                self = $"{forwardedProto}://{originalHost}/users/{user.Id}",
                orders = $"{forwardedProto}://{originalHost}/users/{user.Id}/orders",
                profile = $"{forwardedProto}://{originalHost}/users/{user.Id}/profile"
            }
        });
    }
}
```

### 2. FQDN Context Service

```csharp
public interface IRequestContext
{
    string OriginalHost { get; }
    string OriginalScheme { get; }
    string CurrentHost { get; }
    string BuildOriginalUrl(string path);
}

public class RequestContext : IRequestContext
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public RequestContext(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public string OriginalHost => 
        _httpContextAccessor.HttpContext?.Request.Headers["X-Forwarded-Host"].FirstOrDefault() 
        ?? _httpContextAccessor.HttpContext?.Request.Host.ToString();

    public string OriginalScheme => 
        _httpContextAccessor.HttpContext?.Request.Headers["X-Forwarded-Proto"].FirstOrDefault() 
        ?? "https";

    public string CurrentHost => 
        _httpContextAccessor.HttpContext?.Request.Host.ToString();

    public string BuildOriginalUrl(string path)
    {
        if (!path.StartsWith("/"))
            path = "/" + path;
        
        return $"{OriginalScheme}://{OriginalHost}{path}";
    }
}

// Usage in service
public class UserService
{
    private readonly IRequestContext _requestContext;

    public UserDto GetUser(int id)
    {
        var user = _repository.GetById(id);
        
        return new UserDto
        {
            Id = user.Id,
            Name = user.Name,
            ProfileUrl = _requestContext.BuildOriginalUrl($"/users/{user.Id}/profile")
        };
    }
}
```

### 3. Header Tracking Middleware

```csharp
public class FqdnTrackingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<FqdnTrackingMiddleware> _logger;

    public FqdnTrackingMiddleware(RequestDelegate next, ILogger<FqdnTrackingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Log all FQDN transformations
        var fqdnContext = new
        {
            CurrentHost = context.Request.Host.ToString(),
            OriginalHost = context.Request.Headers["X-Forwarded-Host"].FirstOrDefault(),
            ForwardedProto = context.Request.Headers["X-Forwarded-Proto"].FirstOrDefault(),
            OriginalUri = context.Request.Headers["X-Original-URI"].FirstOrDefault(),
            RealIp = context.Request.Headers["X-Real-IP"].FirstOrDefault(),
            ForwardedFor = context.Request.Headers["X-Forwarded-For"].FirstOrDefault(),
            RequestPath = context.Request.Path.ToString(),
            RequestId = context.Request.Headers["X-Request-ID"].FirstOrDefault()
        };

        _logger.LogDebug("FQDN Context: {@FqdnContext}", fqdnContext);

        // Store in HttpContext for easy access
        context.Items["FqdnContext"] = fqdnContext;

        await _next(context);
    }
}
```

---

## Pod-to-Pod Communication

### Kubernetes DNS Resolution

```mermaid
graph TD
    subgraph Namespace_Users["Namespace: users-ns"]
        UserPod[User API Pod<br/>10.244.1.15]
        UserSvc[Service: users-api-service<br/>ClusterIP: 10.0.150.20<br/>FQDN: users-api-service.users-ns.svc.cluster.local]
    end
    
    subgraph Namespace_Orders["Namespace: orders-ns"]
        OrderPod1[Order API Pod 1<br/>10.244.2.23]
        OrderPod2[Order API Pod 2<br/>10.244.2.24]
        OrderSvc[Service: orders-api-service<br/>ClusterIP: 10.0.151.30<br/>FQDN: orders-api-service.orders-ns.svc.cluster.local]
    end
    
    subgraph Namespace_Data["Namespace: data-ns"]
        DBPod[Database Pod<br/>10.244.3.41]
        DBSvc[Service: database-service<br/>ClusterIP: 10.0.152.40<br/>FQDN: database-service.data-ns.svc.cluster.local]
    end
    
    subgraph CoreDNS["CoreDNS (Kubernetes DNS)"]
        DNS[DNS Server<br/>10.0.0.10]
    end
    
    UserPod -->|1. DNS Query:<br/>orders-api-service.orders-ns.svc.cluster.local| DNS
    DNS -->|2. A Record: 10.0.151.30| UserPod
    UserPod -->|3. HTTP Request with internal FQDN| OrderSvc
    OrderSvc -->|4. Load Balance| OrderPod1
    OrderSvc -->|4. Load Balance| OrderPod2
    
    OrderPod1 -->|5. DNS Query:<br/>database-service.data-ns.svc.cluster.local| DNS
    DNS -->|6. A Record: 10.0.152.40| OrderPod1
    OrderPod1 -->|7. TCP Connection with internal FQDN| DBSvc
    DBSvc -->|8. Route| DBPod
    
    style UserPod fill:#ffcccc,stroke:#333,stroke-width:2px
    style OrderPod1 fill:#ccffcc,stroke:#333,stroke-width:2px
    style OrderPod2 fill:#ccffcc,stroke:#333,stroke-width:2px
    style DBPod fill:#ccccff,stroke:#333,stroke-width:2px
```

### Kubernetes Service DNS Naming Convention

**Format**: `<service-name>.<namespace>.svc.cluster.local`

**Best Practice**: Always use full FQDN for pod-to-pod communication, even within the same namespace, for clarity and consistency.

**Examples**:
- **Recommended (Full FQDN)**: `orders-api-service.orders-ns.svc.cluster.local`
- **Cross-namespace (Required)**: `users-api-service.users-ns.svc.cluster.local`
- **Same namespace (Short form)**: `orders-api-service` (works but not recommended)
- **With port**: `orders-api-service.orders-ns.svc.cluster.local:8080`

### Pod-to-Pod Communication Implementation

**User API Service calling Order API Service (using internal FQDNs):**

```csharp
// appsettings.json - User API Service configuration
{
  "Services": {
    "OrdersAPI": {
      "BaseUrl": "http://orders-api-service.orders-ns.svc.cluster.local:8080",
      "Timeout": 30
    },
    "ProductsAPI": {
      "BaseUrl": "http://products-api-service.products-ns.svc.cluster.local:8080",
      "Timeout": 30
    },
    "PaymentsAPI": {
      "BaseUrl": "http://payments-api-service.payments-ns.svc.cluster.local:8080",
      "Timeout": 30
    }
  }
}

// Note: All URLs use full Kubernetes Service FQDNs for cross-namespace communication
```

```csharp
// Service configuration
public class ServiceSettings
{
    public Dictionary<string, ServiceEndpoint> Services { get; set; }
}

public class ServiceEndpoint
{
    public string BaseUrl { get; set; }
    public int Timeout { get; set; }
}

// Program.cs
builder.Services.Configure<ServiceSettings>(builder.Configuration);

builder.Services.AddHttpClient("OrdersAPIClient", (serviceProvider, client) =>
{
    var settings = serviceProvider.GetRequiredService<IOptions<ServiceSettings>>().Value;
    var ordersConfig = settings.Services["OrdersAPI"];
    
    // Use full internal FQDN for service discovery
    client.BaseAddress = new Uri(ordersConfig.BaseUrl);
    client.Timeout = TimeSpan.FromSeconds(ordersConfig.Timeout);
    
    // Add default headers for pod-to-pod communication
    client.DefaultRequestHeaders.Add("X-Service-Name", "users-api-service");
    client.DefaultRequestHeaders.Add("X-Service-Namespace", "users-ns");
    client.DefaultRequestHeaders.Add("X-Service-Version", "1.2.3");
})
.AddPolicyHandler(GetRetryPolicy())
.AddPolicyHandler(GetCircuitBreakerPolicy());

// User API service calling Orders API service (pod-to-pod with internal FQDN)
public class UserApiService
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<UserApiService> _logger;
    private readonly IRequestContext _requestContext;

    public UserApiService(
        IHttpClientFactory httpClientFactory, 
        ILogger<UserApiService> logger,
        IRequestContext requestContext)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
        _requestContext = requestContext;
    }

    public async Task<List<OrderDto>> GetUserOrdersAsync(int userId)
    {
        // Client is configured with internal FQDN: orders-api-service.orders-ns.svc.cluster.local:8080
        var client = _httpClientFactory.CreateClient("OrdersAPIClient");
        
        // Propagate correlation headers for distributed tracing
        var request = new HttpRequestMessage(HttpMethod.Get, $"/api/orders?userId={userId}");
        request.Headers.Add("X-Request-ID", Activity.Current?.Id ?? Guid.NewGuid().ToString());
        request.Headers.Add("X-Correlation-ID", Activity.Current?.RootId);
        
        // Propagate original host information for HATEOAS links
        request.Headers.Add("X-Original-Host", _requestContext.OriginalHost);
        request.Headers.Add("X-Original-Scheme", _requestContext.OriginalScheme);

        _logger.LogInformation(
            "Pod-to-pod call: User API -> Orders API at {OrdersApiUrl} for user {UserId}",
            client.BaseAddress, userId);

        var response = await client.SendAsync(request);
        
        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError(
                "Orders API service returned {StatusCode} for user {UserId}",
                response.StatusCode, userId);
            throw new HttpRequestException($"Orders API error: {response.StatusCode}");
        }

        var content = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<List<OrderDto>>(content);
    }
}
```

### ConfigMap for Service Discovery

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: users-api-config
  namespace: users-ns
data:
  appsettings.json: |
    {
      "Services": {
        "OrdersAPI": {
          "BaseUrl": "http://orders-api-service.orders-ns.svc.cluster.local:8080",
          "Timeout": 30
        },
        "ProductsAPI": {
          "BaseUrl": "http://products-api-service.products-ns.svc.cluster.local:8080",
          "Timeout": 30
        },
        "PaymentsAPI": {
          "BaseUrl": "http://payments-api-service.payments-ns.svc.cluster.local:8080",
          "Timeout": 30
        }
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: users-api-service
  namespace: users-ns
spec:
  template:
    spec:
      containers:
      - name: users-api
        volumeMounts:
        - name: config
          mountPath: /app/config
      volumes:
      - name: config
        configMap:
          name: users-api-config
```

---

## Service Mesh Integration (Optional Enhancement)

> **Important**: This section describes **optional** service mesh integration with Istio. The AKS automatic private cluster uses **NGINX Ingress Controller as the default ingress**, which handles external traffic routing and TLS termination. Istio service mesh is an additional layer that can be added for enhanced pod-to-pod security (mTLS), advanced traffic management, and observability.

### Architecture: NGINX Ingress (Default) + Istio Service Mesh (Optional)

**Two Deployment Options:**

#### Option 1: NGINX Ingress Only (Default AKS Automatic)
- **Ingress**: NGINX Ingress Controller (default in AKS automatic)
- **Pod-to-Pod**: Plain HTTP using internal FQDNs
- **Security**: Application-level authentication, network policies
- **Simplicity**: Lower complexity, easier to manage

#### Option 2: NGINX Ingress + Istio Service Mesh (Enhanced)
- **Ingress**: NGINX Ingress Controller (handles external traffic)
- **Service Mesh**: Istio (handles pod-to-pod communication)
- **Pod-to-Pod**: Automatic mTLS via Envoy sidecars
- **Advanced Features**: Traffic splitting, circuit breaking, distributed tracing

### Why Add Service Mesh (Istio)?

**Problems Service Mesh Solves:**
1. **mTLS**: Automatic encryption for pod-to-pod communication (without code changes)
2. **Traffic Management**: Advanced routing, retries, timeouts, canary deployments
3. **Observability**: Automatic distributed tracing, metrics collection
4. **Security**: Fine-grained access control between services (AuthorizationPolicy)
5. **Resilience**: Circuit breaking, fault injection for chaos testing

**When to Use Service Mesh:**
- ✅ Multiple microservices with complex inter-service communication
- ✅ Need for zero-trust security (mTLS between all services)
- ✅ Advanced deployment strategies (canary, blue-green)
- ✅ Compliance requirements for encryption in transit
- ❌ Simple applications with few services
- ❌ Team lacks service mesh expertise

### Architecture with NGINX + Istio

```mermaid
graph TB
    subgraph Internet
        Client[Client]
    end
    
    subgraph Azure_Ingress["Azure Ingress Layer"]
        CF[Cloudflare]
        APIM[APIM]
    end
    
    subgraph AKS_Cluster["AKS Automatic Private Cluster"]
        subgraph NGINX_Ingress["NGINX Ingress (Default)"]
            NGINX[NGINX Ingress Controller<br/>10.240.0.10<br/>Handles External Traffic]
        end
        
        subgraph Users_NS["Namespace: users-ns"]
            UserPod[User API Pod]
            UserEnvoy[Envoy Sidecar<br/>Istio Proxy]
            UserPod -.->|localhost:15001| UserEnvoy
        end
        
        subgraph Orders_NS["Namespace: orders-ns"]
            OrderPod[Order API Pod]
            OrderEnvoy[Envoy Sidecar<br/>Istio Proxy]
            OrderPod -.->|localhost:15001| OrderEnvoy
        end
        
        subgraph Istio_Control["Istio Control Plane (Optional)"]
            Istiod[Istiod<br/>Config, Certs, Telemetry]
        end
    end
    
    Client -->|HTTPS| CF
    CF -->|HTTPS| APIM
    APIM -->|HTTPS| NGINX
    
    NGINX -->|HTTP| UserEnvoy
    UserEnvoy -->|HTTP| UserPod
    
    UserEnvoy -->|mTLS<br/>Pod-to-Pod| OrderEnvoy
    OrderEnvoy -->|HTTP| OrderPod
    
    Istiod -.->|Config & Certs| UserEnvoy
    Istiod -.->|Config & Certs| OrderEnvoy
    
    style NGINX fill:#99ff66,stroke:#333,stroke-width:3px
    style UserEnvoy fill:#99ccff,stroke:#333,stroke-width:2px
    style OrderEnvoy fill:#99ccff,stroke:#333,stroke-width:2px
    style Istiod fill:#ff99cc,stroke:#333,stroke-width:2px
```

**Key Points:**
- **NGINX Ingress**: Remains the entry point for external traffic (from APIM)
- **Istio Sidecars**: Only intercept pod-to-pod communication within the cluster
- **No Istio Gateway**: We use NGINX Ingress, not Istio Ingress Gateway
- **mTLS**: Automatic between pods with Istio sidecars

### Istio Installation and Configuration

**1. Install Istio:**
```bash
# Install Istio CLI
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.20.0
export PATH=$PWD/bin:$PATH

# Install Istio on AKS with custom profile
istioctl install --set profile=production \
  --set values.gateways.istio-ingressgateway.type=LoadBalancer \
  --set values.global.proxy.resources.requests.cpu=100m \
  --set values.global.proxy.resources.requests.memory=128Mi

# Verify installation
kubectl get pods -n istio-system
```

**2. Enable Automatic Sidecar Injection:**
```bash
# Label namespaces for automatic sidecar injection
kubectl label namespace frontend-ns istio-injection=enabled
kubectl label namespace backend-ns istio-injection=enabled
kubectl label namespace users-ns istio-injection=enabled
kubectl label namespace orders-ns istio-injection=enabled

# Verify labels
kubectl get namespace -L istio-injection
```

**3. Istio Gateway Configuration:**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: aks-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  # Frontend application
  - port:
      number: 443
      name: https-frontend
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: frontend-tls-cert  # Kubernetes secret with cert
    hosts:
    - "frontend.apps.internal.local"
  
  # Backend API
  - port:
      number: 443
      name: https-backend
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: backend-tls-cert
    hosts:
    - "backend.apps.internal.local"
  
  # User Service
  - port:
      number: 443
      name: https-users
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: users-tls-cert
    hosts:
    - "users.apps.internal.local"
```

**4. Virtual Service for Routing:**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: frontend-vs
  namespace: frontend-ns
spec:
  hosts:
  - "frontend.apps.internal.local"
  gateways:
  - istio-system/aks-gateway
  http:
  - match:
    - uri:
        prefix: "/api/v1"
    route:
    - destination:
        host: frontend-service.frontend-ns.svc.cluster.local
        port:
          number: 8080
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s
      retryOn: 5xx,reset,connect-failure,refused-stream
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-vs
  namespace: backend-ns
spec:
  hosts:
  - "backend.apps.internal.local"
  gateways:
  - istio-system/aks-gateway
  http:
  - match:
    - uri:
        prefix: "/api"
    route:
    - destination:
        host: backend-service.backend-ns.svc.cluster.local
        port:
          number: 8080
        subset: v1
      weight: 90
    - destination:
        host: backend-service.backend-ns.svc.cluster.local
        port:
          number: 8080
        subset: v2
      weight: 10  # Canary deployment: 10% traffic to v2
```

**5. Destination Rules (Traffic Policies):**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: backend-dr
  namespace: backend-ns
spec:
  host: backend-service.backend-ns.svc.cluster.local
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
        maxRequestsPerConnection: 2
    loadBalancer:
      simple: LEAST_REQUEST
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

**6. Peer Authentication (mTLS):**
```yaml
# Enforce mTLS for entire mesh
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT  # Enforce mTLS for all pod-to-pod communication
---
# Namespace-specific mTLS policy
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: backend-mtls
  namespace: backend-ns
spec:
  mtls:
    mode: STRICT
```

**7. Authorization Policies:**
```yaml
# Allow frontend to call backend
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: backend-authz
  namespace: backend-ns
spec:
  selector:
    matchLabels:
      app: backend-service
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces: ["frontend-ns"]
        principals: ["cluster.local/ns/frontend-ns/sa/frontend-sa"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
---
# Deny all by default, then allow specific services
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: backend-ns
spec:
  {}  # Empty spec = deny all
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend
  namespace: backend-ns
spec:
  selector:
    matchLabels:
      app: backend-service
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces: ["frontend-ns"]
```

### Microservice Behavior with Service Mesh

**Key Changes:**
1. **No code changes required** - Envoy sidecar handles mTLS, retries, timeouts
2. **Use standard Kubernetes Service FQDNs** - Istio intercepts and manages traffic
3. **Automatic distributed tracing** - Propagate trace headers

```csharp
// With Istio, your code stays simple - no retry logic needed!
public class FrontendService
{
    private readonly IHttpClientFactory _httpClientFactory;

    public async Task<UserDto> GetUserAsync(int userId)
    {
        var client = _httpClientFactory.CreateClient("BackendService");
        
        // Propagate trace headers (Istio uses these for distributed tracing)
        var request = new HttpRequestMessage(HttpMethod.Get, $"/api/users/{userId}");
        
        // Istio automatically adds these if not present, but explicit is better
        request.Headers.Add("x-request-id", Activity.Current?.Id ?? Guid.NewGuid().ToString());
        request.Headers.Add("x-b3-traceid", Activity.Current?.TraceId.ToString());
        request.Headers.Add("x-b3-spanid", Activity.Current?.SpanId.ToString());
        
        // Istio handles:
        // - mTLS encryption
        // - Retries (configured in VirtualService)
        // - Circuit breaking (configured in DestinationRule)
        // - Load balancing
        // - Timeout enforcement
        var response = await client.SendAsync(request);
        response.EnsureSuccessStatusCode();
        
        return await response.Content.ReadFromJsonAsync<UserDto>();
    }
}
```

---

## Multi-Namespace Architecture

### Namespace Strategy

```mermaid
graph TB
    subgraph Ingress_NS["Namespace: istio-system"]
        Gateway[Istio Gateway<br/>frontend.apps.internal.local<br/>backend.apps.internal.local<br/>users.apps.internal.local]
    end
    
    subgraph Frontend_NS["Namespace: frontend-ns"]
        FrontendSvc[frontend-service<br/>FQDN: frontend.apps.internal.local]
    end
    
    subgraph Backend_NS["Namespace: backend-ns"]
        BackendSvc[backend-service<br/>FQDN: backend.apps.internal.local]
    end
    
    subgraph Users_NS["Namespace: users-ns"]
        UsersSvc[users-service<br/>FQDN: users.apps.internal.local]
    end
    
    subgraph Orders_NS["Namespace: orders-ns"]
        OrdersSvc[orders-service<br/>FQDN: orders.apps.internal.local]
    end
    
    subgraph Data_NS["Namespace: data-ns"]
        DBSvc[database-service<br/>Internal only]
    end
    
    Gateway -->|Route /api/v1/*| FrontendSvc
    Gateway -->|Route /api/backend/*| BackendSvc
    Gateway -->|Route /api/users/*| UsersSvc
    
    FrontendSvc -->|Pod-to-Pod| BackendSvc
    FrontendSvc -->|Pod-to-Pod| UsersSvc
    BackendSvc -->|Pod-to-Pod| OrdersSvc
    UsersSvc -->|Pod-to-Pod| DBSvc
    OrdersSvc -->|Pod-to-Pod| DBSvc
    
    style Gateway fill:#ff99cc,stroke:#333,stroke-width:3px
    style FrontendSvc fill:#ffcccc,stroke:#333,stroke-width:2px
    style BackendSvc fill:#ccffcc,stroke:#333,stroke-width:2px
    style UsersSvc fill:#ccccff,stroke:#333,stroke-width:2px
    style OrdersSvc fill:#ffffcc,stroke:#333,stroke-width:2px
    style DBSvc fill:#ffccff,stroke:#333,stroke-width:2px
```

### Complete Multi-Namespace Implementation

**1. Namespace Creation:**
```bash
# Create namespaces
kubectl create namespace frontend-ns
kubectl create namespace backend-ns
kubectl create namespace users-ns
kubectl create namespace orders-ns
kubectl create namespace data-ns

# Enable Istio injection
kubectl label namespace frontend-ns istio-injection=enabled
kubectl label namespace backend-ns istio-injection=enabled
kubectl label namespace users-ns istio-injection=enabled
kubectl label namespace orders-ns istio-injection=enabled
kubectl label namespace data-ns istio-injection=enabled
```

**2. Gateway with Multiple FQDNs:**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: multi-fqdn-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https-frontend
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: wildcard-apps-internal-tls
    hosts:
    - "frontend.apps.internal.local"
    - "www.apps.internal.local"
  
  - port:
      number: 443
      name: https-api
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: wildcard-apps-internal-tls
    hosts:
    - "api.apps.internal.local"
    - "backend.apps.internal.local"
    - "users.apps.internal.local"
    - "orders.apps.internal.local"
```

**3. Virtual Services for Each Namespace:**
```yaml
# Frontend Virtual Service
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: frontend-vs
  namespace: frontend-ns
spec:
  hosts:
  - "frontend.apps.internal.local"
  - "www.apps.internal.local"
  gateways:
  - istio-system/multi-fqdn-gateway
  http:
  - match:
    - uri:
        prefix: "/"
    route:
    - destination:
        host: frontend-service.frontend-ns.svc.cluster.local
        port:
          number: 8080
---
# Backend Virtual Service
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-vs
  namespace: backend-ns
spec:
  hosts:
  - "backend.apps.internal.local"
  - "api.apps.internal.local"
  gateways:
  - istio-system/multi-fqdn-gateway
  http:
  - match:
    - uri:
        prefix: "/api/backend"
    rewrite:
      uri: "/api"
    route:
    - destination:
        host: backend-service.backend-ns.svc.cluster.local
        port:
          number: 8080
---
# Users Virtual Service
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: users-vs
  namespace: users-ns
spec:
  hosts:
  - "users.apps.internal.local"
  - "api.apps.internal.local"
  gateways:
  - istio-system/multi-fqdn-gateway
  http:
  - match:
    - uri:
        prefix: "/api/users"
    route:
    - destination:
        host: users-service.users-ns.svc.cluster.local
        port:
          number: 8080
---
# Orders Virtual Service
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: orders-vs
  namespace: orders-ns
spec:
  hosts:
  - "orders.apps.internal.local"
  - "api.apps.internal.local"
  gateways:
  - istio-system/multi-fqdn-gateway
  http:
  - match:
    - uri:
        prefix: "/api/orders"
    route:
    - destination:
        host: orders-service.orders-ns.svc.cluster.local
        port:
          number: 8080
```

**4. APIM Backend Configuration for Multiple FQDNs:**
```xml
<!-- APIM Policy for routing to different FQDNs based on path -->
<policies>
    <inbound>
        <base />
        <choose>
            <!-- Route /users/* to users service -->
            <when condition="@(context.Request.Url.Path.StartsWith("/users"))">
                <set-backend-service base-url="https://users.apps.internal.local" />
                <rewrite-uri template="@("/api" + context.Request.Url.Path)" />
            </when>
            
            <!-- Route /orders/* to orders service -->
            <when condition="@(context.Request.Url.Path.StartsWith("/orders"))">
                <set-backend-service base-url="https://orders.apps.internal.local" />
                <rewrite-uri template="@("/api" + context.Request.Url.Path)" />
            </when>
            
            <!-- Route /backend/* to backend service -->
            <when condition="@(context.Request.Url.Path.StartsWith("/backend"))">
                <set-backend-service base-url="https://backend.apps.internal.local" />
                <rewrite-uri template="@("/api/backend" + context.Request.Url.Path.Substring(8))" />
            </when>
            
            <!-- Default to frontend -->
            <otherwise>
                <set-backend-service base-url="https://frontend.apps.internal.local" />
            </otherwise>
        </choose>
        
        <!-- Preserve original host information -->
        <set-header name="X-Original-Host" exists-action="override">
            <value>@(context.Request.OriginalUrl.Host)</value>
        </set-header>
        <set-header name="X-Original-Path" exists-action="override">
            <value>@(context.Request.Url.Path)</value>
        </set-header>
    </inbound>
</policies>
```

**5. Private DNS Zone Configuration:**
```bash
# Create A records for each FQDN pointing to Istio Gateway IP
az network private-dns record-set a add-record \
  --resource-group rg-aks-prod \
  --zone-name internal.local \
  --record-set-name "frontend.apps" \
  --ipv4-address 10.240.0.10

az network private-dns record-set a add-record \
  --resource-group rg-aks-prod \
  --zone-name internal.local \
  --record-set-name "backend.apps" \
  --ipv4-address 10.240.0.10

az network private-dns record-set a add-record \
  --resource-group rg-aks-prod \
  --zone-name internal.local \
  --record-set-name "users.apps" \
  --ipv4-address 10.240.0.10

az network private-dns record-set a add-record \
  --resource-group rg-aks-prod \
  --zone-name internal.local \
  --record-set-name "orders.apps" \
  --ipv4-address 10.240.0.10

# Or use wildcard
az network private-dns record-set a add-record \
  --resource-group rg-aks-prod \
  --zone-name internal.local \
  --record-set-name "*.apps" \
  --ipv4-address 10.240.0.10
```

---

## Complete Implementation Example

### Scenario: E-Commerce Platform

**Architecture:**
- **Frontend**: React SPA (frontend-ns) → `frontend.apps.internal.local`
- **API Gateway**: BFF pattern (api-ns) → `api.apps.internal.local`
- **Users Service**: User management (users-ns) → `users.apps.internal.local`
- **Orders Service**: Order processing (orders-ns) → `orders.apps.internal.local`
- **Products Service**: Product catalog (products-ns) → `products.apps.internal.local`
- **Payments Service**: Payment processing (payments-ns) → `payments.apps.internal.local`

### Request Flow Example

```
Client Request: https://api.example.com/orders/123

1. Cloudflare → APIM
   FQDN: api.example.com
   
2. APIM → Istio Gateway
   FQDN: api.apps.internal.local
   Path: /orders/123
   
3. Istio Gateway → API Gateway Service (BFF)
   FQDN: api-gateway-service.api-ns.svc.cluster.local
   Headers: X-Original-Host: api.example.com
   
4. API Gateway → Orders Service (pod-to-pod)
   FQDN: orders-service.orders-ns.svc.cluster.local
   Path: /api/orders/123
   mTLS: Enabled by Istio
   
5. Orders Service → Users Service (pod-to-pod)
   FQDN: users-service.users-ns.svc.cluster.local
   Path: /api/users/456
   mTLS: Enabled by Istio
   
6. Orders Service → Payments Service (pod-to-pod)
   FQDN: payments-service.payments-ns.svc.cluster.local
   Path: /api/payments/validate
   mTLS: Enabled by Istio
```

### Complete Deployment

```yaml
# API Gateway Service (BFF Pattern)
apiVersion: v1
kind: Namespace
metadata:
  name: api-ns
  labels:
    istio-injection: enabled
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-gateway-sa
  namespace: api-ns
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: api-ns
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
        version: v1
    spec:
      serviceAccountName: api-gateway-sa
      containers:
      - name: api-gateway
        image: myregistry.azurecr.io/api-gateway:1.0.0
        ports:
        - containerPort: 8080
        env:
        - name: ASPNETCORE_URLS
          value: "http://+:8080"
        - name: Services__Users__BaseUrl
          value: "http://users-service.users-ns.svc.cluster.local:8080"
        - name: Services__Orders__BaseUrl
          value: "http://orders-service.orders-ns.svc.cluster.local:8080"
        - name: Services__Products__BaseUrl
          value: "http://products-service.products-ns.svc.cluster.local:8080"
        - name: Services__Payments__BaseUrl
          value: "http://payments-service.payments-ns.svc.cluster.local:8080"
---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway-service
  namespace: api-ns
spec:
  selector:
    app: api-gateway
  ports:
  - port: 8080
    targetPort: 8080
---
# Istio Virtual Service
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-gateway-vs
  namespace: api-ns
spec:
  hosts:
  - "api.apps.internal.local"
  gateways:
  - istio-system/multi-fqdn-gateway
  http:
  - match:
    - uri:
        prefix: "/"
    route:
    - destination:
        host: api-gateway-service.api-ns.svc.cluster.local
        port:
          number: 8080
    timeout: 60s
    retries:
      attempts: 3
      perTryTimeout: 20s
---
# Authorization Policy - Allow APIM to call API Gateway
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-apim
  namespace: api-ns
spec:
  selector:
    matchLabels:
      app: api-gateway
  action: ALLOW
  rules:
  - from:
    - source:
        # APIM IP range
        ipBlocks: ["10.100.2.0/24"]
```

### Summary

**Key Takeaways:**

1. **FQDN Transformations**: Microservices receive multiple FQDNs through headers; use `X-Forwarded-Host` to track original FQDN

2. **Pod-to-Pod Communication**: Use Kubernetes Service FQDNs (`service.namespace.svc.cluster.local`)

3. **Service Mesh Benefits**:
   - Automatic mTLS for pod-to-pod
   - Traffic management (retries, timeouts, circuit breaking)
   - Observability (tracing, metrics)
   - Fine-grained authorization

4. **Multi-Namespace Strategy**:
   - One namespace per microservice/domain
   - Istio Gateway handles multiple FQDNs
   - Virtual Services route based on host/path
   - Authorization Policies control cross-namespace access

5. **Microservice Behavior**:
   - Extract original FQDN from headers for HATEOAS links
   - Use Kubernetes Service DNS for pod-to-pod calls
   - Propagate correlation/trace headers
   - Let service mesh handle resilience patterns

