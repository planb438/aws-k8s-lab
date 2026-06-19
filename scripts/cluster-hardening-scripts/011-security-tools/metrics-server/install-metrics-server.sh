#!/bin/bash
# Install Metrics Server for Kubernetes
# Run on MASTER node after cluster is built
# Required for: kubectl top, HPA, and autoscaling

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# ============================================
# Step 1: Install Metrics Server
# ============================================
log_step "Installing Metrics Server..."

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

log_info "✅ Metrics Server manifests applied"

# ============================================
# Step 2: Wait for deployment
# ============================================
log_step "Waiting for Metrics Server deployment..."

sleep 10
kubectl wait --for=condition=available deployment/metrics-server -n kube-system --timeout=60s 2>/dev/null || {
    log_warn "Deployment not ready yet, checking status..."
    kubectl get pods -n kube-system | grep metrics-server
}

# ============================================
# Step 3: Patch for local development (insecure TLS)
# ============================================
log_step "Patching Metrics Server for local development..."

# Check if patch is already applied
if kubectl get deployment metrics-server -n kube-system -o yaml | grep -q "kubelet-insecure-tls"; then
    log_info "✅ Metrics Server already patched"
else
    log_info "Adding --kubelet-insecure-tls and --kubelet-preferred-address-types=InternalIP"
    
    kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
        {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"},
        {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-preferred-address-types=InternalIP"}
    ]' 2>/dev/null || {
        log_warn "Patch failed, trying edit method..."
        kubectl edit deployment metrics-server -n kube-system
    }
    
    log_info "✅ Metrics Server patched"
fi

# ============================================
# Step 4: Wait for restart
# ============================================
log_step "Waiting for Metrics Server to restart..."

sleep 15
kubectl rollout status deployment/metrics-server -n kube-system --timeout=60s

# ============================================
# Step 5: Verify installation
# ============================================
log_step "Verifying Metrics Server..."

echo ""
echo "========================================="
echo "🔍 VERIFICATION RESULTS"
echo "========================================="

# Check deployment
echo ""
echo "📊 Deployment status:"
kubectl get deployment metrics-server -n kube-system

# Check pods
echo ""
echo "📊 Pods:"
kubectl get pods -n kube-system | grep metrics-server

# Check API service
echo ""
echo "📊 API Service:"
kubectl get apiservices | grep metrics || echo "  Waiting for API service to register..."

# Test kubectl top
echo ""
echo "📊 Testing kubectl top nodes (may take 30-60 seconds first time):"
sleep 5

if kubectl top nodes &>/dev/null; then
    echo "✅ kubectl top nodes: WORKING"
    kubectl top nodes
else
    echo "⚠️ kubectl top nodes: Not ready yet (may need more time)"
    echo "   Run 'kubectl top nodes' manually in 1-2 minutes"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "========================================="
log_step "INSTALLATION COMPLETE"
echo "========================================="
echo ""
echo "✅ Metrics Server installed and configured"
echo ""
echo "📝 Test Commands:"
echo ""
echo "  # Check node metrics"
echo "  kubectl top nodes"
echo ""
echo "  # Check pod metrics"
echo "  kubectl top pods -A"
echo ""
echo "  # Check HPA"
echo "  kubectl get hpa -A"
echo ""
echo "  # Check API service"
echo "  kubectl get apiservices | grep metrics"
echo ""
echo "========================================="
echo ""
log_info "⚠️ Note: First 'kubectl top' may take 1-2 minutes to show data"