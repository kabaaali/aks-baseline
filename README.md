# AKS RBAC with Azure Entra ID - Proof of Concept

This project demonstrates Role-Based Access Control (RBAC) implementation with Azure Kubernetes Service (AKS) using Azure Entra ID authentication from Azure API Management (APIM) to microservices running in AKS pods.

## 🎯 Overview

This implementation showcases secure, production-ready authentication between APIM and AKS microservices using **Azure Workload Identity**:

- **APIM** uses its managed identity to obtain OAuth 2.0 tokens from Azure Entra ID
- **APIM** forwards the token to the AKS microservice in the Authorization header
- **AKS Microservice** validates the token using workload identity federation with Entra ID
- **End-to-end authentication** without storing credentials in the application

## 📁 Project Structure

```
RBAC-poc-AKS/
├── README.md                           # This file
├── AKS_RBAC_IMPLEMENTATION_GUIDE.md   # Comprehensive step-by-step guide
├── hello-world-service/                # .NET Core 8.0 microservice
│   ├── Program.cs                      # Main application entry point
│   ├── Controllers/
│   │   └── HelloController.cs          # API controller with auth
│   ├── hello-world-service.csproj      # Project file
│   ├── appsettings.json                # Configuration
│   ├── Dockerfile                      # Container image definition
│   └── .dockerignore                   # Docker build exclusions
├── k8s-manifests/                      # Kubernetes manifests
│   ├── namespace.yaml                  # Namespace definition
│   ├── rbac.yaml                       # Service account & RBAC
│   ├── deployment.yaml                 # Deployment configuration
│   ├── service.yaml                    # Service (LoadBalancer)
│   └── ingress.yaml                    # Ingress configuration
├── config/                             # Configuration files
│   ├── environment-template.env        # Environment variables template
│   ├── apim-policy.xml                 # APIM authentication policy
│   └── entra-id-config.env            # Generated during setup
└── scripts/                            # Automation scripts
    ├── 01-setup-entra-id.sh           # Azure Entra ID setup
    ├── 02-configure-aks-cluster.sh    # AKS workload identity config
    ├── 03-build-and-deploy.sh         # Build & deploy microservice
    ├── 04-setup-apim.sh               # APIM configuration
    └── test-api.sh                    # End-to-end testing
```

## 🚀 Quick Start

### Prerequisites

- Azure subscription with appropriate permissions
- Existing AKS cluster (public cluster)
- Azure CLI installed and configured
- kubectl installed
- Docker installed
- .NET 8.0 SDK (for local development)

### Installation Steps

1. **Clone and Configure**
   ```bash
   cd RBAC-poc-AKS
   cp config/environment-template.env config/environment.env
   # Edit config/environment.env with your Azure details
   ```

2. **Setup Azure Entra ID**
   ```bash
   chmod +x scripts/*.sh
   ./scripts/01-setup-entra-id.sh
   ```
   This creates app registrations and configures API permissions.

3. **Configure AKS Cluster**
   ```bash
   source config/entra-id-config.env
   ./scripts/02-configure-aks-cluster.sh
   ```
   This enables workload identity and creates federated credentials.

4. **Build and Deploy Microservice**
   ```bash
   ./scripts/03-build-and-deploy.sh
   ```
   This builds the Docker image, pushes to ACR, and deploys to AKS.

5. **Setup APIM**
   ```bash
   ./scripts/04-setup-apim.sh
   ```
   This configures APIM with managed identity authentication.

6. **Test the Implementation**
   ```bash
   ./scripts/test-api.sh
   ```
   This runs comprehensive tests to validate the authentication flow.

## 📖 Detailed Documentation

For comprehensive step-by-step instructions, see [AKS_RBAC_IMPLEMENTATION_GUIDE.md](./AKS_RBAC_IMPLEMENTATION_GUIDE.md).

The guide includes:
- Architecture diagrams
- Detailed explanations of each step
- Troubleshooting guide
- Manual configuration steps
- Best practices

## 🔐 Authentication Flow

```
Client → APIM → Entra ID → AKS Microservice
```

1. Client sends request to APIM endpoint
2. APIM uses managed identity to request token from Entra ID
3. Entra ID validates managed identity and returns JWT token
4. APIM forwards request with token to AKS microservice
5. Microservice validates token using workload identity
6. Microservice processes request and returns response

## 🧪 Testing

### Test Endpoints

After deployment, you can test these endpoints:

```bash
# Health check (no auth required)
curl -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  https://YOUR_APIM.azure-api.net/hello/health

# Public endpoint (no auth required)
curl -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  https://YOUR_APIM.azure-api.net/hello/api/hello/public

# Authenticated endpoint (APIM acquires token)
curl -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  https://YOUR_APIM.azure-api.net/hello/api/hello
```

### Automated Testing

Run the comprehensive test suite:

```bash
./scripts/test-api.sh
```

This validates:
- ✅ Health endpoint accessibility
- ✅ Public endpoint functionality
- ✅ Authenticated endpoint with token validation
- ✅ RBAC enforcement (unauthorized access blocked)
- ✅ Workload identity configuration

## 🛠️ Technology Stack

- **Azure Kubernetes Service (AKS)** - Container orchestration
- **Azure Entra ID** - Identity and access management
- **Azure Workload Identity** - Federated identity for Kubernetes
- **Azure API Management** - API gateway
- **.NET Core 8.0** - Microservice framework
- **ASP.NET Core Web API** - REST API framework
- **Microsoft.Identity.Web** - Azure AD authentication
- **Docker** - Containerization
- **Kubernetes RBAC** - Access control

## 📊 Architecture

The solution implements a secure, production-ready architecture:

- **Workload Identity Federation**: No secrets stored in pods
- **Managed Identity**: APIM authenticates without credentials
- **JWT Token Validation**: Microservice validates tokens with Entra ID
- **RBAC**: Fine-grained access control at Kubernetes level
- **Security Best Practices**: Non-root containers, read-only filesystems, resource limits

## 🔧 Configuration

### Environment Variables

Key configuration in `config/environment.env`:

```bash
AZURE_SUBSCRIPTION_ID="your-subscription-id"
RESOURCE_GROUP="your-aks-resource-group"
AKS_CLUSTER_NAME="your-aks-cluster-name"
ACR_NAME="your-acr-name"
APIM_NAME="your-apim-name"
```

### Azure Entra ID

Generated during setup in `config/entra-id-config.env`:

```bash
TENANT_ID="your-tenant-id"
MICROSERVICE_APP_ID="microservice-app-id"
APIM_APP_ID="apim-app-id"
OIDC_ISSUER_URL="aks-oidc-issuer-url"
```

## 🐛 Troubleshooting

### Common Issues

1. **Workload Identity Not Working**
   ```bash
   # Verify workload identity is enabled
   az aks show --resource-group RG --name CLUSTER \
     --query "securityProfile.workloadIdentity.enabled"
   
   # Check service account annotations
   kubectl describe sa hello-world-sa -n hello-world
   ```

2. **APIM Cannot Acquire Token**
   - Verify APIM managed identity has API.Access role
   - Check APIM policy configuration
   - Review APIM logs in Azure Portal

3. **Token Validation Fails**
   ```bash
   # Check pod logs
   kubectl logs -l app=hello-world -n hello-world --tail=50
   
   # Verify environment variables
   kubectl get deployment hello-world-deployment -n hello-world -o yaml
   ```

See the [Troubleshooting section](./AKS_RBAC_IMPLEMENTATION_GUIDE.md#troubleshooting) in the implementation guide for detailed solutions.

## 📝 Manual Steps Required

Some steps require manual configuration in Azure Portal:

1. **Expose API Scope** (Step 1, Script 1)
   - Azure Portal → Entra ID → App Registrations → Microservice App
   - Expose an API → Add a scope (API.Access)

2. **Grant API Permissions** (Step 1, Script 1)
   - Azure Portal → Entra ID → App Registrations → APIM App
   - API Permissions → Add permission → Grant admin consent

3. **Assign App Role** (Step 5, Script 4)
   - Azure Portal → Entra ID → Enterprise Applications → Microservice App
   - Users and groups → Add APIM managed identity → Assign API.Access role

## 🔄 Cleanup

To remove all resources:

```bash
# Delete Kubernetes resources
kubectl delete namespace hello-world

# Delete APIM API
az apim api delete --resource-group RG --service-name APIM --api-id hello-world-api

# Delete app registrations (optional)
az ad app delete --id $MICROSERVICE_APP_ID
az ad app delete --id $APIM_APP_ID

# Delete container image
az acr repository delete --name ACR --repository hello-world-service
```

## 📚 Additional Resources

- [Azure Workload Identity Documentation](https://azure.github.io/azure-workload-identity/)
- [AKS Workload Identity Overview](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview)
- [APIM Authentication Policies](https://learn.microsoft.com/en-us/azure/api-management/api-management-authentication-policies)
- [Microsoft.Identity.Web](https://learn.microsoft.com/en-us/azure/active-directory/develop/microsoft-identity-web)

## 🤝 Contributing

This is a proof-of-concept project. Feel free to adapt it for your needs.

## 📄 License

This project is provided as-is for educational and demonstration purposes.

## ✨ Features

- ✅ Azure Workload Identity integration
- ✅ APIM managed identity authentication
- ✅ JWT token validation
- ✅ Kubernetes RBAC
- ✅ .NET Core 8.0 microservice
- ✅ Docker containerization
- ✅ Automated deployment scripts
- ✅ Comprehensive testing
- ✅ Security best practices
- ✅ Production-ready architecture

## 📞 Support

For issues or questions:
1. Review the [Implementation Guide](./AKS_RBAC_IMPLEMENTATION_GUIDE.md)
2. Check the [Troubleshooting section](#troubleshooting)
3. Review pod logs and APIM diagnostics

---

**Version:** 1.0  
**Last Updated:** 2025-11-26  
**Author:** Antigravity AI Assistant
