#!/bin/bash
set -e

echo "=================================================="
echo "Azure Entra ID Setup for AKS RBAC"
echo "=================================================="

# Load environment variables
if [ -f "../config/environment.env" ]; then
    source ../config/environment.env
    echo "✓ Loaded environment configuration"
else
    echo "❌ Error: config/environment.env not found"
    echo "Please copy config/environment-template.env to config/environment.env and fill in your values"
    exit 1
fi

# Check if required variables are set
if [ -z "$AZURE_SUBSCRIPTION_ID" ] || [ -z "$NAMESPACE" ]; then
    echo "❌ Error: Required environment variables are not set"
    echo "Please configure config/environment.env with your Azure details"
    exit 1
fi

echo ""
echo "Step 1: Login to Azure"
echo "----------------------"
az login
az account set --subscription "${AZURE_SUBSCRIPTION_ID}"
echo "✓ Logged in to Azure subscription: ${AZURE_SUBSCRIPTION_ID}"

echo ""
echo "Step 2: Get Tenant Information"
echo "-------------------------------"
TENANT_ID=$(az account show --query tenantId --output tsv)
echo "✓ Tenant ID: ${TENANT_ID}"

echo ""
echo "Step 3: Create App Registration for API"
echo "----------------------------------------"
echo "This single app registration will be used for:"
echo "  - APIM managed identity authentication"
echo "  - AKS microservice token validation"
echo ""

API_APP_NAME="aks-hello-world-api"

# Check if app already exists
EXISTING_APP=$(az ad app list --display-name "${API_APP_NAME}" --query "[0].appId" --output tsv)

if [ -n "$EXISTING_APP" ]; then
    echo "⚠ App registration already exists: ${API_APP_NAME}"
    API_APP_ID="${EXISTING_APP}"
else
    API_APP_ID=$(az ad app create \
        --display-name "${API_APP_NAME}" \
        --sign-in-audience AzureADMyOrg \
        --query appId \
        --output tsv)
    
    echo "✓ Created app registration: ${API_APP_NAME}"
    
    # Create service principal
    az ad sp create --id "${API_APP_ID}" 2>/dev/null || true
    echo "✓ Created service principal"
fi

echo "  App ID: ${API_APP_ID}"

echo ""
echo "Step 4: Configure API Identifier URI"
echo "-------------------------------------"
az ad app update \
    --id "${API_APP_ID}" \
    --identifier-uris "api://${API_APP_ID}"
echo "✓ Set identifier URI: api://${API_APP_ID}"

echo ""
echo "Step 5: Create App Role for APIM"
echo "---------------------------------"
echo "⚠ Manual step required:"
echo "  1. Go to Azure Portal > Entra ID > App Registrations"
echo "  2. Select: ${API_APP_NAME}"
echo "  3. Go to 'App roles' > 'Create app role'"
echo "  4. Display name: API.Access"
echo "  5. Allowed member types: Applications"
echo "  6. Value: API.Access"
echo "  7. Description: Allow APIM to access the API"
echo "  8. Click 'Apply'"
echo ""
echo "Note: This app role will be assigned to APIM's managed identity later"
echo ""
read -p "Press Enter after completing the manual step..."

echo ""
echo "Step 6: Save Configuration"
echo "--------------------------"
cat > ../config/entra-id-config.env <<EOF
export TENANT_ID="${TENANT_ID}"
export API_APP_ID="${API_APP_ID}"
EOF

echo "✓ Configuration saved to config/entra-id-config.env"

echo ""
echo "=================================================="
echo "Azure Entra ID Setup Complete!"
echo "=================================================="
echo ""
echo "Configuration Summary:"
echo "  Tenant ID: ${TENANT_ID}"
echo "  API App ID: ${API_APP_ID}"
echo ""
echo "Authentication Flow:"
echo "  Client → APIM (subscription key)"
echo "  APIM → AKS (OAuth token using API App ID)"
echo ""
echo "Next Steps:"
echo "  1. Source the configuration: source config/entra-id-config.env"
echo "  2. Run: ./scripts/02-configure-aks-cluster.sh"
echo ""
