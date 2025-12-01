#!/bin/bash
set -e

echo "=================================================="
echo "AKS Cluster Configuration for Workload Identity"
echo "=================================================="

# Load environment variables
if [ -f "../config/environment.env" ]; then
    source ../config/environment.env
fi

if [ -f "../config/entra-id-config.env" ]; then
    source ../config/entra-id-config.env
    echo "✓ Loaded configuration"
else
    echo "❌ Error: config/entra-id-config.env not found"
    echo "Please run ./scripts/01-setup-entra-id.sh first"
    exit 1
fi

echo ""
echo "Step 1: Connect to AKS Cluster"
echo "-------------------------------"
az aks get-credentials \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${AKS_CLUSTER_NAME}" \
    --overwrite-existing

echo "✓ Connected to AKS cluster: ${AKS_CLUSTER_NAME}"

# Verify connection
kubectl cluster-info
kubectl get nodes

echo ""
echo "Step 2: Check Workload Identity Status"
echo "---------------------------------------"
OIDC_ENABLED=$(az aks show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${AKS_CLUSTER_NAME}" \
    --query "oidcIssuerProfile.enabled" \
    --output tsv)

WORKLOAD_IDENTITY_ENABLED=$(az aks show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${AKS_CLUSTER_NAME}" \
    --query "securityProfile.workloadIdentity.enabled" \
    --output tsv 2>/dev/null || echo "false")

echo "  OIDC Issuer: ${OIDC_ENABLED}"
echo "  Workload Identity: ${WORKLOAD_IDENTITY_ENABLED}"

if [ "$OIDC_ENABLED" != "true" ]; then
    echo ""
    echo "Enabling OIDC issuer..."
    az aks update \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${AKS_CLUSTER_NAME}" \
        --enable-oidc-issuer
    echo "✓ OIDC issuer enabled"
fi

if [ "$WORKLOAD_IDENTITY_ENABLED" != "true" ]; then
    echo ""
    echo "Enabling workload identity..."
    az aks update \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${AKS_CLUSTER_NAME}" \
        --enable-workload-identity
    echo "✓ Workload identity enabled"
fi

echo ""
echo "Step 3: Get OIDC Issuer URL"
echo "---------------------------"
OIDC_ISSUER_URL=$(az aks show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${AKS_CLUSTER_NAME}" \
    --query "oidcIssuerProfile.issuerUrl" \
    --output tsv)

echo "✓ OIDC Issuer URL: ${OIDC_ISSUER_URL}"

echo ""
echo "Step 4: Verify RBAC is Enabled"
echo "-------------------------------"
RBAC_ENABLED=$(az aks show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${AKS_CLUSTER_NAME}" \
    --query "enableRbac" \
    --output tsv)

if [ "$RBAC_ENABLED" == "true" ]; then
    echo "✓ RBAC is enabled"
else
    echo "❌ RBAC is not enabled. Please enable RBAC on your cluster."
    exit 1
fi

echo ""
echo "Step 5: Setup Azure Container Registry"
echo "---------------------------------------"
ACR_EXISTS=$(az acr show --name "${ACR_NAME}" --query "id" --output tsv 2>/dev/null || echo "")

if [ -z "$ACR_EXISTS" ]; then
    echo "Creating Azure Container Registry..."
    az acr create \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${ACR_NAME}" \
        --sku Basic
    echo "✓ Created ACR: ${ACR_NAME}"
else
    echo "✓ ACR already exists: ${ACR_NAME}"
fi

echo ""
echo "Attaching ACR to AKS cluster..."
az aks update \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${AKS_CLUSTER_NAME}" \
    --attach-acr "${ACR_NAME}"
echo "✓ ACR attached to AKS cluster"

echo ""
echo "Step 6: Create Federated Identity Credential"
echo "---------------------------------------------"
CREDENTIAL_NAME="kubernetes-federated-credential"

# Check if credential already exists
EXISTING_CRED=$(az ad app federated-credential list \
    --id "${API_APP_ID}" \
    --query "[?name=='${CREDENTIAL_NAME}'].name" \
    --output tsv 2>/dev/null || echo "")

if [ -n "$EXISTING_CRED" ]; then
    echo "⚠ Federated credential already exists, deleting and recreating..."
    CRED_ID=$(az ad app federated-credential list \
        --id "${API_APP_ID}" \
        --query "[?name=='${CREDENTIAL_NAME}'].id" \
        --output tsv)
    az ad app federated-credential delete \
        --id "${API_APP_ID}" \
        --federated-credential-id "${CRED_ID}"
fi

echo "Creating federated identity credential..."
az ad app federated-credential create \
    --id "${API_APP_ID}" \
    --parameters "{
        \"name\": \"${CREDENTIAL_NAME}\",
        \"issuer\": \"${OIDC_ISSUER_URL}\",
        \"subject\": \"system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT_NAME}\",
        \"audiences\": [\"api://AzureADTokenExchange\"]
    }"

echo "✓ Federated identity credential created"

echo ""
echo "Step 7: Save Configuration"
echo "--------------------------"
cat >> ../config/entra-id-config.env <<EOF
export OIDC_ISSUER_URL="${OIDC_ISSUER_URL}"
EOF

echo "✓ Configuration updated"

echo ""
echo "=================================================="
echo "AKS Cluster Configuration Complete!"
echo "=================================================="
echo ""
echo "Configuration Summary:"
echo "  Cluster: ${AKS_CLUSTER_NAME}"
echo "  OIDC Issuer: ${OIDC_ISSUER_URL}"
echo "  Workload Identity: Enabled"
echo "  RBAC: Enabled"
echo "  ACR: ${ACR_NAME}"
echo ""
echo "Next Steps:"
echo "  1. Run: ./scripts/03-build-and-deploy.sh"
echo ""
