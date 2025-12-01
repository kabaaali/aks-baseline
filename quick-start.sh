#!/bin/bash

cat << "EOF"
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║   AKS RBAC with Azure Entra ID - Quick Start                       ║
║                                                                      ║
║   This script will guide you through the setup process             ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF

echo ""
echo "Welcome! This project demonstrates RBAC implementation with AKS"
echo "using Azure Entra ID workload identity authentication."
echo ""

# Check if configuration exists
if [ ! -f "config/environment.env" ]; then
    echo "⚠️  Configuration file not found!"
    echo ""
    echo "Please complete the following steps:"
    echo ""
    echo "1. Copy the template configuration:"
    echo "   cp config/environment-template.env config/environment.env"
    echo ""
    echo "2. Edit config/environment.env with your Azure details:"
    echo "   - AZURE_SUBSCRIPTION_ID"
    echo "   - RESOURCE_GROUP"
    echo "   - AKS_CLUSTER_NAME"
    echo "   - ACR_NAME"
    echo "   - APIM_NAME"
    echo "   - APIM_RESOURCE_GROUP"
    echo "   - LOCATION"
    echo ""
    echo "3. Run this script again"
    echo ""
    exit 1
fi

echo "✓ Configuration file found"
echo ""

# Show deployment steps
cat << "EOF"
Deployment Steps:
═════════════════

Step 1: Azure Entra ID Setup (~10 minutes)
   ./scripts/01-setup-entra-id.sh
   
   This will:
   - Create app registrations for microservice and APIM
   - Configure API permissions
   - Save configuration to config/entra-id-config.env
   
   ⚠️  Manual steps required (script will prompt you)

Step 2: AKS Cluster Configuration (~5-10 minutes)
   source config/entra-id-config.env
   ./scripts/02-configure-aks-cluster.sh
   
   This will:
   - Enable workload identity on your AKS cluster
   - Create federated identity credentials
   - Configure ACR integration

Step 3: Build and Deploy Microservice (~10 minutes)
   ./scripts/03-build-and-deploy.sh
   
   This will:
   - Build .NET Core Docker image
   - Push to Azure Container Registry
   - Deploy to AKS cluster
   - Verify deployment

Step 4: Setup APIM (~5 minutes + APIM creation time if needed)
   ./scripts/04-setup-apim.sh
   
   This will:
   - Configure APIM with managed identity
   - Create API and operations
   - Apply authentication policies
   
   ⚠️  Manual step required (script will prompt you)

Step 5: Test the Implementation (~2 minutes)
   ./scripts/test-api.sh
   
   This will:
   - Test health endpoint
   - Test public endpoint
   - Test authenticated endpoint
   - Verify RBAC enforcement
   - Validate workload identity

EOF

echo ""
read -p "Do you want to start the deployment now? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "No problem! When you're ready, run:"
    echo "  ./scripts/01-setup-entra-id.sh"
    echo ""
    echo "For detailed documentation, see:"
    echo "  AKS_RBAC_IMPLEMENTATION_GUIDE.md"
    echo ""
    exit 0
fi

echo ""
echo "Starting deployment..."
echo ""

# Run first script
./scripts/01-setup-entra-id.sh

echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Step 1 complete! Next steps:"
echo ""
echo "1. Source the configuration:"
echo "   source config/entra-id-config.env"
echo ""
echo "2. Continue with AKS configuration:"
echo "   ./scripts/02-configure-aks-cluster.sh"
echo ""
echo "3. Or run all remaining steps:"
echo "   source config/entra-id-config.env && \\"
echo "   ./scripts/02-configure-aks-cluster.sh && \\"
echo "   ./scripts/03-build-and-deploy.sh && \\"
echo "   ./scripts/04-setup-apim.sh && \\"
echo "   ./scripts/test-api.sh"
echo ""
