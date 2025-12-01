#!/bin/bash
set -e

echo "=================================================="
echo "Build and Deploy Microservice to AKS"
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
echo "Step 1: Update Kubernetes Manifests"
echo "------------------------------------"
cd ..

# Create temporary manifests with replaced values
mkdir -p k8s-manifests/generated

for file in k8s-manifests/*.yaml; do
    filename=$(basename "$file")
    sed -e "s|<ACR_NAME>|${ACR_NAME}|g" \
        -e "s|<TENANT_ID>|${TENANT_ID}|g" \
        -e "s|<API_APP_ID>|${API_APP_ID}|g" \
        -e "s|<NAMESPACE>|${NAMESPACE}|g" \
        -e "s|<SERVICE_ACCOUNT_NAME>|${SERVICE_ACCOUNT_NAME}|g" \
        "$file" > "k8s-manifests/generated/$filename"
done

echo "✓ Updated manifests with configuration values"

echo ""
echo "Step 2: Update appsettings.json"
echo "--------------------------------"
sed -e "s|<TENANT_ID>|${TENANT_ID}|g" \
    -e "s|<API_APP_ID>|${API_APP_ID}|g" \
    hello-world-service/appsettings.json > hello-world-service/appsettings.json.tmp
mv hello-world-service/appsettings.json.tmp hello-world-service/appsettings.json

echo "✓ Updated appsettings.json"

echo ""
echo "Step 3: Build Docker Image"
echo "--------------------------"
cd hello-world-service

IMAGE_TAG="${ACR_NAME}.azurecr.io/${APP_NAME}:v1"
echo "Building image: ${IMAGE_TAG}"

docker build -t "${IMAGE_TAG}" .
echo "✓ Docker image built successfully"

echo ""
echo "Step 4: Login to ACR"
echo "--------------------"
az acr login --name "${ACR_NAME}"
echo "✓ Logged in to ACR"

echo ""
echo "Step 5: Push Image to ACR"
echo "-------------------------"
docker push "${IMAGE_TAG}"
echo "✓ Image pushed to ACR"

# Verify image
az acr repository show \
    --name "${ACR_NAME}" \
    --repository "${APP_NAME}" \
    --output table

cd ..

echo ""
echo "Step 6: Apply Kubernetes Manifests"
echo "-----------------------------------"

# Apply namespace first
kubectl apply -f k8s-manifests/generated/namespace.yaml
echo "✓ Namespace created/updated"

# Apply RBAC
kubectl apply -f k8s-manifests/generated/rbac.yaml
echo "✓ RBAC configured"

# Apply deployment
kubectl apply -f k8s-manifests/generated/deployment.yaml
echo "✓ Deployment created/updated"

# Apply service
kubectl apply -f k8s-manifests/generated/service.yaml
echo "✓ Service created/updated"

# Apply ingress (optional)
kubectl apply -f k8s-manifests/generated/ingress.yaml 2>/dev/null || echo "⚠ Ingress not applied (may require ingress controller)"

echo ""
echo "Step 7: Wait for Deployment"
echo "---------------------------"
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/hello-world-deployment -n "${NAMESPACE}" --timeout=5m

echo ""
echo "Step 8: Verify Deployment"
echo "-------------------------"
echo ""
echo "Pods:"
kubectl get pods -n "${NAMESPACE}"

echo ""
echo "Services:"
kubectl get svc -n "${NAMESPACE}"

echo ""
echo "Service Account:"
kubectl describe serviceaccount "${SERVICE_ACCOUNT_NAME}" -n "${NAMESPACE}"

echo ""
echo "Step 9: Get Service Endpoint"
echo "-----------------------------"
echo "Waiting for external IP (this may take a few minutes)..."

for i in {1..30}; do
    SERVICE_IP=$(kubectl get service hello-world-service -n "${NAMESPACE}" \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "$SERVICE_IP" ]; then
        echo "✓ Service external IP: ${SERVICE_IP}"
        break
    fi
    
    echo "  Waiting... ($i/30)"
    sleep 10
done

if [ -z "$SERVICE_IP" ]; then
    echo "⚠ External IP not assigned yet. Check with: kubectl get svc -n ${NAMESPACE}"
    SERVICE_IP="<pending>"
fi

echo ""
echo "Step 10: Test Service Directly"
echo "-------------------------------"
if [ "$SERVICE_IP" != "<pending>" ]; then
    echo "Testing health endpoint..."
    curl -s "http://${SERVICE_IP}/health" || echo "⚠ Service not ready yet"
    
    echo ""
    echo "Testing public endpoint..."
    curl -s "http://${SERVICE_IP}/api/hello/public" || echo "⚠ Service not ready yet"
else
    echo "⚠ Skipping direct test - external IP not ready"
fi

echo ""
echo "Step 11: Check Pod Logs"
echo "-----------------------"
POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app=hello-world \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$POD_NAME" ]; then
    echo "Latest logs from ${POD_NAME}:"
    kubectl logs "${POD_NAME}" -n "${NAMESPACE}" --tail=20
fi

echo ""
echo "Step 12: Save Service Configuration"
echo "------------------------------------"
cat >> config/entra-id-config.env <<EOF
export SERVICE_IP="${SERVICE_IP}"
export BACKEND_URL="http://${SERVICE_IP}"
EOF

echo "✓ Configuration updated"

echo ""
echo "=================================================="
echo "Deployment Complete!"
echo "=================================================="
echo ""
echo "Deployment Summary:"
echo "  Image: ${IMAGE_TAG}"
echo "  Namespace: ${NAMESPACE}"
echo "  Service IP: ${SERVICE_IP}"
echo "  Health URL: http://${SERVICE_IP}/health"
echo "  Public API: http://${SERVICE_IP}/api/hello/public"
echo "  Protected API: http://${SERVICE_IP}/api/hello (requires auth)"
echo ""
echo "Next Steps:"
echo "  1. Test the service: curl http://${SERVICE_IP}/health"
echo "  2. Run: ./scripts/04-setup-apim.sh"
echo ""
