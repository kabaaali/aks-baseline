# AKS Ingress Network Topology & Certificate Management

## Network Topology Diagram

```mermaid
graph TB
    subgraph Internet["Internet Zone"]
        Client[Client<br/>203.0.113.50]
        CF[Cloudflare Edge<br/>104.16.0.1<br/>TLS 1.3]
    end
    
    subgraph Azure_Public["Azure Public Zone<br/>VNet: 10.100.0.0/16"]
        subgraph LB_Subnet["LB Subnet: 10.100.0.0/24"]
            PubIP[Public IP<br/>20.123.45.67]
            LB[Azure Load Balancer<br/>10.100.0.5]
        end
        
        subgraph FW_Subnet["Firewall Subnet: 10.100.1.0/24"]
            FG1[FortiGate-1<br/>10.100.1.10<br/>Primary]
            FG2[FortiGate-2<br/>10.100.1.11<br/>Secondary]
        end
        
        subgraph APIM_Subnet["APIM Subnet: 10.100.2.0/24"]
            APIM[APIM Gateway<br/>10.100.2.20<br/>TLS 1.2]
        end
    end
    
    subgraph Azure_Private["Azure Private Zone<br/>AKS VNet: 10.240.0.0/16"]
        subgraph Ingress_Subnet["Ingress Subnet: 10.240.0.0/24"]
            NGINX[NGINX Ingress LB<br/>10.240.0.10<br/>TLS 1.2]
        end
        
        subgraph Pod_Network["Pod Network: 10.244.0.0/16"]
            Pod1[App Pod 1<br/>10.244.1.15:8080]
            Pod2[App Pod 2<br/>10.244.2.23:8080]
            Pod3[App Pod 3<br/>10.244.3.41:8080]
        end
    end
    
    subgraph DNS_Services["DNS Services"]
        PubDNS[Public DNS<br/>example.com<br/>Cloudflare]
        PrivDNS[Private DNS<br/>internal.local<br/>Azure DNS]
    end
    
    Client -->|1. DNS Query| PubDNS
    PubDNS -->|2. A: 20.123.45.67| Client
    Client -->|3. HTTPS| CF
    CF -->|4. HTTPS| PubIP
    PubIP --> LB
    LB -->|5. HTTPS| FG1
    FG1 -->|6. HTTPS| APIM
    APIM -->|7. DNS Query| PrivDNS
    PrivDNS -->|8. A: 10.240.0.10| APIM
    APIM -->|9. HTTPS| NGINX
    NGINX -->|10. HTTP| Pod1
    NGINX -->|10. HTTP| Pod2
    NGINX -->|10. HTTP| Pod3
    
    FG2 -.->|HA Sync| FG1
    
    style CF fill:#ff9966,stroke:#333,stroke-width:3px
    style APIM fill:#6699ff,stroke:#333,stroke-width:3px
    style NGINX fill:#99ff66,stroke:#333,stroke-width:3px
    style Pod1 fill:#ffff99,stroke:#333,stroke-width:2px
    style Pod2 fill:#ffff99,stroke:#333,stroke-width:2px
    style Pod3 fill:#ffff99,stroke:#333,stroke-width:2px
```

## Certificate Management Architecture

```mermaid
graph TD
    subgraph Cert_Sources["Certificate Sources"]
        CF_CA[Cloudflare<br/>Universal SSL<br/>Auto-managed]
        AKV[Azure Key Vault<br/>kv-prod-certs<br/>Manual + Auto-renewal]
        LE[Let's Encrypt<br/>ACME CA<br/>cert-manager]
    end
    
    subgraph Layer1["Layer 1: Cloudflare Edge"]
        CF_Cert["*.example.com<br/>Issuer: Cloudflare Inc ECC CA-3<br/>Valid: 365 days<br/>Auto-renew: 30 days before expiry"]
    end
    
    subgraph Layer2["Layer 2: Azure Load Balancer"]
        LB_Cert["api.example.com<br/>Issuer: DigiCert TLS RSA SHA256<br/>Valid: 365 days<br/>Storage: Azure Key Vault"]
    end
    
    subgraph Layer3["Layer 3: APIM Gateway"]
        APIM_Cert["apim-prod.azure-api.net<br/>Issuer: Microsoft Azure TLS CA<br/>Valid: 365 days<br/>Auto-managed by Azure"]
        APIM_Backend["Backend Trust<br/>Let's Encrypt CA<br/>Uploaded to APIM"]
    end
    
    subgraph Layer4["Layer 4: NGINX Ingress"]
        NGINX_Cert["*.internal.local<br/>Issuer: Let's Encrypt Authority X3<br/>Valid: 90 days<br/>Auto-renew: cert-manager"]
    end
    
    subgraph Monitoring["Certificate Monitoring"]
        CM[cert-manager<br/>Kubernetes Operator]
        AKV_Alert[Key Vault Alerts<br/>30 days before expiry]
        Script[Custom Script<br/>check-cert-expiry.sh]
    end
    
    CF_CA -->|Provisions| CF_Cert
    AKV -->|Stores| LB_Cert
    LE -->|Issues via ACME| NGINX_Cert
    
    CF_Cert -->|Used by| CF_Edge[Cloudflare Edge]
    LB_Cert -->|Used by| Azure_LB[Azure LB]
    APIM_Cert -->|Used by| APIM_GW[APIM Gateway]
    NGINX_Cert -->|Used by| NGINX_IC[NGINX Ingress]
    
    CM -->|Monitors & Renews| NGINX_Cert
    AKV_Alert -->|Notifies| DevOps[DevOps Team]
    Script -->|Checks| CF_Cert
    Script -->|Checks| LB_Cert
    Script -->|Checks| APIM_Cert
    
    style CF_Cert fill:#ff9966,stroke:#333,stroke-width:2px
    style LB_Cert fill:#6699ff,stroke:#333,stroke-width:2px
    style APIM_Cert fill:#6699ff,stroke:#333,stroke-width:2px
    style NGINX_Cert fill:#99ff66,stroke:#333,stroke-width:2px
```

## TLS Handshake Flow

```mermaid
sequenceDiagram
    autonumber
    participant C as Client
    participant CF as Cloudflare
    participant LB as Azure LB
    participant FG as FortiGate
    participant APIM as APIM
    participant NG as NGINX
    participant Pod as App Pod

    Note over C,CF: TLS Handshake #1 (TLS 1.3)
    C->>CF: ClientHello<br/>SNI: api.example.com<br/>Supported Ciphers
    CF->>C: ServerHello<br/>Selected Cipher: TLS_AES_256_GCM_SHA384
    CF->>C: Certificate: *.example.com<br/>Public Key
    C->>CF: ClientKeyExchange<br/>Encrypted with server public key
    CF->>C: Finished
    C->>CF: Finished
    Note over C,CF: ✅ Encrypted Channel Established
    
    Note over CF,LB: TLS Handshake #2 (TLS 1.2)
    CF->>LB: ClientHello<br/>SNI: api.example.com
    LB->>FG: Forward to backend
    FG->>CF: ServerHello<br/>Cipher: ECDHE-RSA-AES256-GCM-SHA384
    FG->>CF: Certificate: api.example.com<br/>(from Azure Key Vault)
    CF->>FG: Verify certificate chain
    CF->>FG: ClientKeyExchange
    FG->>CF: Finished
    CF->>FG: Finished
    Note over CF,FG: ✅ Encrypted Channel Established
    
    Note over FG,APIM: TLS Handshake #3 (TLS 1.2)
    FG->>APIM: ClientHello<br/>SNI: apim-prod.azure-api.net
    APIM->>FG: ServerHello
    APIM->>FG: Certificate: apim-prod.azure-api.net<br/>(Azure-managed)
    FG->>APIM: Verify certificate
    FG->>APIM: ClientKeyExchange
    APIM->>FG: Finished
    FG->>APIM: Finished
    Note over FG,APIM: ✅ Encrypted Channel Established
    
    Note over APIM,NG: TLS Handshake #4 (TLS 1.2)
    APIM->>NG: ClientHello<br/>SNI: app1.internal.local
    NG->>APIM: ServerHello
    NG->>APIM: Certificate: *.internal.local<br/>(Let's Encrypt)
    APIM->>NG: Verify against uploaded CA
    APIM->>NG: ClientKeyExchange
    NG->>APIM: Finished
    APIM->>NG: Finished
    Note over APIM,NG: ✅ Encrypted Channel Established
    
    Note over NG,Pod: Unencrypted Internal Traffic
    NG->>Pod: HTTP GET /api/v1/users/123
    Pod->>NG: HTTP 200 OK
```

## IP Address Allocation

### Public IP Addresses
| Resource | IP Address | DNS Name | Purpose |
|----------|------------|----------|---------|
| Azure Load Balancer | 20.123.45.67 | api.example.com | Public entry point |
| Cloudflare Edge (example) | 104.16.0.1 | - | CDN edge node |

### Private IP Addresses - Public VNet (10.100.0.0/16)
| Subnet | Resource | IP Address | Purpose |
|--------|----------|------------|---------|
| 10.100.0.0/24 | Azure LB Internal | 10.100.0.5 | Load balancer frontend |
| 10.100.1.0/24 | FortiGate-1 | 10.100.1.10 | Primary firewall |
| 10.100.1.0/24 | FortiGate-2 | 10.100.1.11 | Secondary firewall (HA) |
| 10.100.2.0/24 | APIM Gateway | 10.100.2.20 | API Management instance |

### Private IP Addresses - AKS VNet (10.240.0.0/16)
| Subnet | Resource | IP Address | Purpose |
|--------|----------|------------|---------|
| 10.240.0.0/24 | NGINX Ingress LB | 10.240.0.10 | Ingress controller service |
| 10.244.1.0/24 | App Pod 1 | 10.244.1.15 | Application pod (node 1) |
| 10.244.2.0/24 | App Pod 2 | 10.244.2.23 | Application pod (node 2) |
| 10.244.3.0/24 | App Pod 3 | 10.244.3.41 | Application pod (node 3) |

## Port Mapping

| Layer | Source Port | Destination Port | Protocol | Notes |
|-------|-------------|------------------|----------|-------|
| Client → Cloudflare | Random (>1024) | 443 | HTTPS/TLS 1.3 | Client ephemeral port |
| Cloudflare → Azure LB | Random | 443 | HTTPS/TLS 1.2 | Cloudflare source port |
| Azure LB → FortiGate | Random | 443 | HTTPS/TLS 1.2 | Load balancer NAT |
| FortiGate → APIM | Random | 443 | HTTPS/TLS 1.2 | Firewall NAT |
| APIM → NGINX | Random | 443 | HTTPS/TLS 1.2 | APIM source port |
| NGINX → Pod | Random | 8080 | HTTP | Unencrypted cluster traffic |

## FQDN to IP Resolution Matrix

| FQDN | DNS Zone | Record Type | IP Address | Resolver | Accessible From |
|------|----------|-------------|------------|----------|-----------------|
| api.example.com | example.com (Public) | A | 20.123.45.67 | Cloudflare DNS | Internet |
| www.example.com | example.com (Public) | CNAME → A | 20.123.45.67 | Cloudflare DNS | Internet |
| apim-prod.azure-api.net | azure-api.net (Azure) | A | 10.100.2.20 | Azure DNS | Azure VNets |
| app1.internal.local | internal.local (Private) | A | 10.240.0.10 | Azure Private DNS | Linked VNets only |
| *.apps.internal.local | internal.local (Private) | A | 10.240.0.10 | Azure Private DNS | Linked VNets only |
| app1-service.default.svc.cluster.local | cluster.local (K8s) | A | 10.0.150.20 | CoreDNS | AKS cluster only |

## Certificate Chain Validation

### Cloudflare Certificate Chain
```
Root CA: Baltimore CyberTrust Root
  ├─ Intermediate CA: Cloudflare Inc ECC CA-3
  │   └─ End Entity: *.example.com
  │       ├─ Subject: CN=*.example.com
  │       ├─ Issuer: CN=Cloudflare Inc ECC CA-3
  │       ├─ Serial: 0a:1b:2c:3d:4e:5f:6a:7b:8c:9d
  │       ├─ Valid: 2024-01-15 to 2025-01-14
  │       └─ Key: ECDSA P-256
```

### Azure Load Balancer Certificate Chain
```
Root CA: DigiCert Global Root CA
  ├─ Intermediate CA: DigiCert TLS RSA SHA256 2020 CA1
  │   └─ End Entity: api.example.com
  │       ├─ Subject: CN=api.example.com
  │       ├─ Issuer: CN=DigiCert TLS RSA SHA256 2020 CA1
  │       ├─ Serial: 0f:1e:2d:3c:4b:5a:69:78:87:96
  │       ├─ Valid: 2024-06-01 to 2025-06-01
  │       └─ Key: RSA 2048
```

### NGINX Ingress Certificate Chain
```
Root CA: ISRG Root X1 (Let's Encrypt)
  ├─ Intermediate CA: Let's Encrypt Authority X3
  │   └─ End Entity: *.internal.local
  │       ├─ Subject: CN=*.internal.local
  │       ├─ Issuer: CN=Let's Encrypt Authority X3
  │       ├─ Serial: 03:a1:b2:c3:d4:e5:f6:07:08:09
  │       ├─ Valid: 2024-11-01 to 2025-02-01 (90 days)
  │       └─ Key: RSA 2048
```

## Network Security Groups (NSG) Rules

### LB Subnet NSG (10.100.0.0/24)
| Priority | Name | Direction | Source | Destination | Port | Protocol | Action |
|----------|------|-----------|--------|-------------|------|----------|--------|
| 100 | Allow-Internet-HTTPS | Inbound | Internet | 20.123.45.67 | 443 | TCP | Allow |
| 110 | Allow-HealthProbe | Inbound | AzureLoadBalancer | * | * | * | Allow |
| 200 | Allow-To-Firewall | Outbound | 10.100.0.0/24 | 10.100.1.0/24 | 443 | TCP | Allow |
| 65000 | Deny-All-Inbound | Inbound | * | * | * | * | Deny |

### Firewall Subnet NSG (10.100.1.0/24)
| Priority | Name | Direction | Source | Destination | Port | Protocol | Action |
|----------|------|-----------|--------|-------------|------|----------|--------|
| 100 | Allow-From-LB | Inbound | 10.100.0.0/24 | 10.100.1.0/24 | 443 | TCP | Allow |
| 110 | Allow-HA-Sync | Inbound | 10.100.1.0/24 | 10.100.1.0/24 | * | * | Allow |
| 200 | Allow-To-APIM | Outbound | 10.100.1.0/24 | 10.100.2.0/24 | 443 | TCP | Allow |
| 65000 | Deny-All-Inbound | Inbound | * | * | * | * | Deny |

### APIM Subnet NSG (10.100.2.0/24)
| Priority | Name | Direction | Source | Destination | Port | Protocol | Action |
|----------|------|-----------|--------|-------------|------|----------|--------|
| 100 | Allow-From-Firewall | Inbound | 10.100.1.0/24 | 10.100.2.0/24 | 443 | TCP | Allow |
| 110 | Allow-APIM-Management | Inbound | ApiManagement | * | 3443 | TCP | Allow |
| 200 | Allow-To-AKS | Outbound | 10.100.2.0/24 | 10.240.0.0/24 | 443 | TCP | Allow |
| 210 | Allow-Azure-DNS | Outbound | * | 168.63.129.16 | 53 | UDP | Allow |
| 65000 | Deny-All-Inbound | Inbound | * | * | * | * | Deny |

### AKS Ingress Subnet NSG (10.240.0.0/24)
| Priority | Name | Direction | Source | Destination | Port | Protocol | Action |
|----------|------|-----------|--------|-------------|------|----------|--------|
| 100 | Allow-From-APIM | Inbound | 10.100.2.0/24 | 10.240.0.0/24 | 443 | TCP | Allow |
| 200 | Allow-To-Pods | Outbound | 10.240.0.0/24 | 10.244.0.0/16 | * | TCP | Allow |
| 65000 | Deny-All-Inbound | Inbound | * | * | * | * | Deny |

## VNet Peering Configuration

```mermaid
graph LR
    subgraph Public_VNet["Public VNet<br/>10.100.0.0/16"]
        PubSub[Subnets:<br/>LB, Firewall, APIM]
    end
    
    subgraph AKS_VNet["AKS VNet<br/>10.240.0.0/16"]
        AKSSub[Subnets:<br/>Ingress, Pods]
    end
    
    Public_VNet <-->|VNet Peering<br/>Allow Gateway Transit<br/>Use Remote Gateways| AKS_VNet
    
    style Public_VNet fill:#6699ff,stroke:#333,stroke-width:2px
    style AKS_VNet fill:#99ff66,stroke:#333,stroke-width:2px
```

**Peering Configuration:**
```bash
# Create VNet peering from Public to AKS
az network vnet peering create \
  --name public-to-aks \
  --resource-group rg-aks-prod \
  --vnet-name vnet-public \
  --remote-vnet vnet-aks \
  --allow-vnet-access \
  --allow-forwarded-traffic

# Create VNet peering from AKS to Public
az network vnet peering create \
  --name aks-to-public \
  --resource-group rg-aks-prod \
  --vnet-name vnet-aks \
  --remote-vnet vnet-public \
  --allow-vnet-access \
  --allow-forwarded-traffic
```

## Request Headers at Each Layer

### Layer 1: Client → Cloudflare
```http
GET /users/123 HTTP/2
Host: api.example.com
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)
Accept: application/json
Accept-Encoding: gzip, deflate, br
Connection: keep-alive
```

### Layer 2: Cloudflare → Azure LB
```http
GET /users/123 HTTP/1.1
Host: api.example.com
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)
Accept: application/json
X-Forwarded-For: 203.0.113.50
X-Forwarded-Proto: https
CF-Connecting-IP: 203.0.113.50
CF-Ray: 8a1b2c3d4e5f6g7h
CF-Visitor: {"scheme":"https"}
```

### Layer 3: FortiGate → APIM
```http
GET /users/123 HTTP/1.1
Host: api.example.com
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)
Accept: application/json
X-Forwarded-For: 203.0.113.50
X-Forwarded-Proto: https
CF-Connecting-IP: 203.0.113.50
CF-Ray: 8a1b2c3d4e5f6g7h
X-Fortigate-Client-IP: 203.0.113.50
```

### Layer 4: APIM → NGINX
```http
GET /api/v1/users/123 HTTP/1.1
Host: app1.internal.local
User-Agent: APIM/1.0
Accept: application/json
X-Forwarded-For: 203.0.113.50
X-Forwarded-Proto: https
Ocp-Apim-Subscription-Key: a1b2c3d4e5f6g7h8i9j0
X-APIM-Request-Id: 12345678-1234-1234-1234-123456789abc
X-Original-Host: api.example.com
```

### Layer 5: NGINX → Pod
```http
GET /api/v1/users/123 HTTP/1.1
Host: app1-service:8080
User-Agent: APIM/1.0
Accept: application/json
X-Real-IP: 10.100.2.20
X-Forwarded-For: 203.0.113.50
X-Forwarded-Proto: https
X-Scheme: https
X-Original-URI: /users/123
Ocp-Apim-Subscription-Key: a1b2c3d4e5f6g7h8i9j0
X-APIM-Request-Id: 12345678-1234-1234-1234-123456789abc
X-Request-ID: nginx-req-11223
```

