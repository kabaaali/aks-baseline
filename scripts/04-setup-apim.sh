#!/bin/bash
set -e

echo "=================================================="
echo "Azure API Management Setup"
echo "=================================================="

# Load environment variables
if [ -f "../config/environment.env" ]; then
    source ../config/environment.env
fi

if [ -f "../config/entra-id-config.env" ]; then
    source ../config/entra-id-config.env
    echo "✓ Loaded configuration"
else
    echo "❌ Error: Configuration files not found"
    exit 1
fi

echo ""
echo "Step 1: Check/Create APIM Instance"
echo "-----------------------------------"
APIM_EXISTS=$(az apim show \
    --name "${APIM_NAME}" \
    --resource-group "${APIM_RESOURCE_GROUP}" \
    --query "id" \
    --output tsv 2>/dev/null || echo "")

if [ -z "$APIM_EXISTS" ]; then
    echo "⚠ APIM instance does not exist"
    echo "Creating APIM instance (this will take 30-45 minutes)..."
    read -p "Do you want to create a new APIM instance? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        az apim create \
            --name "${APIM_NAME}" \
            --resource-group "${APIM_RESOURCE_GROUP}" \
            --publisher-name "Your Organization" \
            --publisher-email "admin@yourorg.com" \
            --sku-name Developer \
            --location "${LOCATION}"
        echo "✓ APIM instance created"
    else
        echo "❌ APIM instance required. Exiting."
        exit 1
    fi
else
    echo "✓ APIM instance exists: ${APIM_NAME}"
fi

echo ""
echo "Step 2: Enable Managed Identity on APIM"
echo "----------------------------------------"
az apim update \
    --name "${APIM_NAME}" \
    --resource-group "${APIM_RESOURCE_GROUP}" \
    --set identity.type=SystemAssigned

APIM_PRINCIPAL_ID=$(az apim show \
    --name "${APIM_NAME}" \
    --resource-group "${APIM_RESOURCE_GROUP}" \
    --query "identity.principalId" \
    --output tsv)

echo "✓ Managed identity enabled"
echo "  Principal ID: ${APIM_PRINCIPAL_ID}"

echo ""
echo "Step 3: Grant APIM Access to API"
echo "----------------------------------"
echo "⚠ Manual step required:"
echo ""
echo "1. Go to Azure Portal > Entra ID > Enterprise Applications"
echo "2. Search for 'aks-hello-world-api'"
echo "3. Go to 'Users and groups' > 'Add user/group'"
echo "4. Under 'Users', click 'None Selected'"
echo "5. Search for '${APIM_NAME}' (the APIM managed identity)"
echo "6. Select it and click 'Select'"
echo "7. Under 'Select a role', choose 'API.Access'"
echo "8. Click 'Assign'"
echo ""
echo "This grants APIM's managed identity permission to call the API"
echo ""
read -p "Press Enter after completing the manual steps..."

echo ""
echo "Step 4: Get Backend URL"
echo "-----------------------"
if [ -z "$SERVICE_IP" ] || [ "$SERVICE_IP" == "<pending>" ]; then
    SERVICE_IP=$(kubectl get service hello-world-service -n "${NAMESPACE}" \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
fi

if [ -z "$SERVICE_IP" ]; then
    echo "❌ Error: Service IP not available"
    echo "Please wait for the service to get an external IP:"
    echo "  kubectl get svc -n ${NAMESPACE}"
    exit 1
fi

BACKEND_URL="http://${SERVICE_IP}"
echo "✓ Backend URL: ${BACKEND_URL}"

echo ""
echo "Step 5: Create API in APIM"
echo "--------------------------"
# Check if API already exists
API_EXISTS=$(az apim api show \
    --resource-group "${APIM_RESOURCE_GROUP}" \
    --service-name "${APIM_NAME}" \
    --api-id "hello-world-api" \
    --query "id" \
    --output tsv 2>/dev/null || echo "")

if [ -n "$API_EXISTS" ]; then
    echo "⚠ API already exists, updating..."
    az apim api update \
        --resource-group "${APIM_RESOURCE_GROUP}" \
        --service-name "${APIM_NAME}" \
        --api-id "hello-world-api" \
        --service-url "${BACKEND_URL}"
else
    az apim api create \
        --resource-group "${APIM_RESOURCE_GROUP}" \
        --service-name "${APIM_NAME}" \
        --api-id "hello-world-api" \
        --path "hello" \
        --display-name "Hello World API" \
        --service-url "${BACKEND_URL}" \
        --protocols "https"
fi

echo "✓ API created/updated"

echo ""
echo "Step 6: Create API Operations"
echo "------------------------------"

# Health endpoint
az apim api operation create \
    --resource-group "${APIM_RESOURCE_GROUP}" \
    --service-name "${APIM_NAME}" \
    --api-id "hello-world-api" \
    --url-template "/health" \
    --method "GET" \
    --display-name "Health Check" 2>/dev/null || echo "  Health operation already exists"

# Hello endpoint (authenticated)
az apim api operation create \
    --resource-group "${APIM_RESOURCE_GROUP}" \
    --service-name "${APIM_NAME}" \
    --api-id "hello-world-api" \
    --url-template "/api/hello" \
    --method "GET" \
    --display-name "Get Hello (Authenticated)" 2>/dev/null || echo "  Hello operation already exists"

# Public hello endpoint
az apim api operation create \
    --resource-group "${APIM_RESOURCE_GROUP}" \
    --service-name "${APIM_NAME}" \
    --api-id "hello-world-api" \
    --url-template "/api/hello/public" \
    --method "GET" \
    --display-name "Get Hello (Public)" 2>/dev/null || echo "  Public hello operation already exists"

echo "✓ API operations created"

echo ""
echo "Step 7: Apply Authentication Policy"
echo "------------------------------------"

# Update policy file with actual app ID
cd ..
sed "s|<API_APP_ID>|${API_APP_ID}|g" \
    config/apim-policy.xml > config/apim-policy-generated.xml

# Apply policy using REST API (workaround for missing CLI command)
echo "  Applying policy via REST API..."
az rest --method put \
    --url "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${APIM_RESOURCE_GROUP}/providers/Microsoft.ApiManagement/service/${APIM_NAME}/apis/hello-world-api/policies/policy?api-version=2021-08-01" \
    --headers "Content-Type=application/vnd.ms-azure-apim.policy+xml" "If-Match=*" \
    --body "@config/apim-policy-generated.xml"

echo "✓ Authentication policy applied"

echo ""
echo "Step 8: Get APIM Gateway URL"
echo "-----------------------------"
APIM_GATEWAY_URL=$(az apim show \
    --name "${APIM_NAME}" \
    --resource-group "${APIM_RESOURCE_GROUP}" \
    --query "gatewayUrl" \
    --output tsv)

echo "✓ APIM Gateway URL: ${APIM_GATEWAY_URL}"

echo ""
echo "Step 9: Get Subscription Key"
echo "-----------------------------"
# Get subscription key using REST API (workaround for missing CLI command)
# We use the 'master' subscription which is built-in
APIM_SUBSCRIPTION_KEY=$(az rest --method post \
    --url "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${APIM_RESOURCE_GROUP}/providers/Microsoft.ApiManagement/service/${APIM_NAME}/subscriptions/master/listSecrets?api-version=2021-08-01" \
    --query "primaryKey" \
    --output tsv)

echo "✓ Subscription key retrieved"

echo ""
echo "Step 10: Save Configuration"
echo "---------------------------"
cat >> config/entra-id-config.env <<EOF
export APIM_GATEWAY_URL="${APIM_GATEWAY_URL}"
export APIM_PRINCIPAL_ID="${APIM_PRINCIPAL_ID}"
export APIM_SUBSCRIPTION_KEY="${APIM_SUBSCRIPTION_KEY}"
EOF

echo "✓ Configuration saved"

cd scripts

echo ""
echo "=================================================="
echo "APIM Setup Complete!"
echo "=================================================="
echo ""
echo "Configuration Summary:"
echo "  APIM Name: ${APIM_NAME}"
echo "  Gateway URL: ${APIM_GATEWAY_URL}"
echo "  Backend URL: ${BACKEND_URL}"
echo "  Managed Identity: ${APIM_PRINCIPAL_ID}"
echo ""
echo "Test URLs:"
echo "  Health: ${APIM_GATEWAY_URL}/hello/health"
echo "  Public: ${APIM_GATEWAY_URL}/hello/api/hello/public"
echo "  Authenticated: ${APIM_GATEWAY_URL}/hello/api/hello"
echo ""
echo "Subscription Key: ${APIM_SUBSCRIPTION_KEY}"
echo ""
echo "Next Steps:"
echo "  1. Run: ./scripts/test-api.sh"
echo ""
