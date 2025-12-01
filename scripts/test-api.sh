#!/bin/bash
set -e

echo "=================================================="
echo "API Testing Script"
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

# Check if required variables are set
if [ -z "$APIM_GATEWAY_URL" ] || [ -z "$APIM_SUBSCRIPTION_KEY" ]; then
    echo "❌ Error: APIM configuration not found"
    echo "Please run ./scripts/04-setup-apim.sh first"
    exit 1
fi

echo ""
echo "Configuration:"
echo "  APIM Gateway: ${APIM_GATEWAY_URL}"
echo "  Namespace: ${NAMESPACE}"
echo ""

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=================================================="
echo "Test 1: Health Endpoint (No Auth Required)"
echo "=================================================="
echo ""
echo "Request:"
echo "  GET ${APIM_GATEWAY_URL}/hello/health"
echo ""

HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Ocp-Apim-Subscription-Key: ${APIM_SUBSCRIPTION_KEY}" \
    "${APIM_GATEWAY_URL}/hello/health")

HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$HEALTH_RESPONSE" | sed '$d')

echo "Response:"
echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
echo ""

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ Test 1 PASSED${NC} (HTTP $HTTP_CODE)"
else
    echo -e "${RED}✗ Test 1 FAILED${NC} (HTTP $HTTP_CODE)"
fi

echo ""
echo "=================================================="
echo "Test 2: Public Endpoint (No Auth Required)"
echo "=================================================="
echo ""
echo "Request:"
echo "  GET ${APIM_GATEWAY_URL}/hello/api/hello/public"
echo ""

PUBLIC_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Ocp-Apim-Subscription-Key: ${APIM_SUBSCRIPTION_KEY}" \
    "${APIM_GATEWAY_URL}/hello/api/hello/public")

HTTP_CODE=$(echo "$PUBLIC_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$PUBLIC_RESPONSE" | sed '$d')

echo "Response:"
echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
echo ""

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ Test 2 PASSED${NC} (HTTP $HTTP_CODE)"
else
    echo -e "${RED}✗ Test 2 FAILED${NC} (HTTP $HTTP_CODE)"
fi

echo ""
echo "=================================================="
echo "Test 3: Authenticated Endpoint (Requires Token)"
echo "=================================================="
echo ""
echo "Request:"
echo "  GET ${APIM_GATEWAY_URL}/hello/api/hello"
echo "  (APIM will acquire token using managed identity)"
echo ""

AUTH_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Ocp-Apim-Subscription-Key: ${APIM_SUBSCRIPTION_KEY}" \
    "${APIM_GATEWAY_URL}/hello/api/hello")

HTTP_CODE=$(echo "$AUTH_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$AUTH_RESPONSE" | sed '$d')

echo "Response:"
echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
echo ""

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ Test 3 PASSED${NC} (HTTP $HTTP_CODE)"
    echo ""
    echo "Authentication Details:"
    echo "$RESPONSE_BODY" | jq '.user, .authorization' 2>/dev/null || echo "Could not parse user details"
else
    echo -e "${RED}✗ Test 3 FAILED${NC} (HTTP $HTTP_CODE)"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  1. Verify APIM managed identity has API.Access role"
    echo "  2. Check APIM policy is correctly configured"
    echo "  3. Verify federated credential is set up correctly"
    echo "  4. Check pod logs: kubectl logs -l app=hello-world -n ${NAMESPACE}"
fi

echo ""
echo "=================================================="
echo "Test 4: Direct Service Access (Should Fail)"
echo "=================================================="
echo ""

if [ -n "$SERVICE_IP" ] && [ "$SERVICE_IP" != "<pending>" ]; then
    echo "Request:"
    echo "  GET http://${SERVICE_IP}/api/hello (without token)"
    echo ""
    
    DIRECT_RESPONSE=$(curl -s -w "\n%{http_code}" \
        "http://${SERVICE_IP}/api/hello" 2>/dev/null || echo "Connection failed\n000")
    
    HTTP_CODE=$(echo "$DIRECT_RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$DIRECT_RESPONSE" | sed '$d')
    
    echo "Response:"
    echo "$RESPONSE_BODY"
    echo ""
    
    if [ "$HTTP_CODE" == "401" ]; then
        echo -e "${GREEN}✓ Test 4 PASSED${NC} (HTTP $HTTP_CODE - Unauthorized as expected)"
    else
        echo -e "${YELLOW}⚠ Test 4 WARNING${NC} (HTTP $HTTP_CODE - Expected 401)"
    fi
else
    echo -e "${YELLOW}⚠ Test 4 SKIPPED${NC} (Service IP not available)"
fi

echo ""
echo "=================================================="
echo "Test 5: Workload Identity Verification"
echo "=================================================="
echo ""

POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app=hello-world \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$POD_NAME" ]; then
    echo "Checking pod: ${POD_NAME}"
    echo ""
    
    echo "Service Account:"
    kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" \
        -o jsonpath='{.spec.serviceAccountName}'
    echo ""
    echo ""
    
    echo "Workload Identity Labels:"
    kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" \
        -o jsonpath='{.metadata.labels.azure\.workload\.identity/use}'
    echo ""
    echo ""
    
    echo "Environment Variables:"
    kubectl exec "${POD_NAME}" -n "${NAMESPACE}" -- env | grep -E "AZURE|AzureAd" || echo "No Azure env vars found"
    echo ""
    
    echo -e "${GREEN}✓ Test 5 COMPLETED${NC}"
else
    echo -e "${RED}✗ Test 5 FAILED${NC} (No pods found)"
fi

echo ""
echo "=================================================="
echo "Test Summary"
echo "=================================================="
echo ""
echo "All tests completed. Review the results above."
echo ""
echo "For detailed logs, run:"
echo "  kubectl logs -l app=hello-world -n ${NAMESPACE} --tail=50"
echo ""
echo "To view APIM logs:"
echo "  Go to Azure Portal > APIM > APIs > Hello World API > Test"
echo ""
