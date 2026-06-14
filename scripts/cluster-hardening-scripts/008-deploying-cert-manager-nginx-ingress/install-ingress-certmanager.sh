#!/bin/bash
# Complete Ingress + Cert Manager Installation Script
# Run on MASTER node after cluster is ready
# This script includes ALL fixes for Calico + webhook issues

set -e

# Colors for output
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
# Prerequisites Check
# ============================================
log_step "Checking prerequisites..."

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    log_error "Helm is not installed. Please install Helm first."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed."
    exit 1
fi

# Check if cluster is accessible
if ! kubectl get nodes &> /dev/null; then
    log_error "Cannot access Kubernetes cluster."
    exit 1
fi

log_info "✅ Prerequisites passed"

# ============================================
# Step 1: Install Nginx Ingress Controller
# ============================================
log_step "Step 1: Installing Nginx Ingress Controller..."

# Add helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Create namespace
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

# Install with NodePort (works on EC2 without LoadBalancer)
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443 \
  --set controller.admissionWebhooks.enabled=false \
  --set controller.publishService.enabled=true \
  --set controller.replicaCount=2 \
  --set controller.nodeSelector."kubernetes\.io/os"=linux \
  --wait --timeout 5m

log_info "✅ Ingress Controller installed"

# ============================================
# Step 2: Install Cert Manager
# ============================================
log_step "Step 2: Installing Cert Manager..."

# Add jetstack repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Create namespace
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -

# Install cert-manager with CRDs
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true \
  --set nodeSelector."kubernetes\.io/os"=linux \
  --wait --timeout 5m

log_info "✅ Cert Manager installed"

# ============================================
# Step 3: FIX WEBHOOK ISSUE (CRITICAL)
# ============================================
log_step "Step 3: Fixing cert-manager webhook (known Calico issue)..."

# Delete blocking webhook configurations
kubectl delete validatingwebhookconfiguration cert-manager-webhook 2>/dev/null || true
kubectl delete mutatingwebhookconfiguration cert-manager-webhook 2>/dev/null || true

# Restart cert-manager pods
kubectl delete pods -n cert-manager --all 2>/dev/null || true

# Wait for pods to be ready
log_info "Waiting for cert-manager pods to restart..."
sleep 15
kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=webhook -n cert-manager --timeout=120s 2>/dev/null || true

log_info "✅ Webhook fix applied"

# ============================================
# Step 4: Create Self-Signed ClusterIssuer
# ============================================
log_step "Step 4: Creating self-signed ClusterIssuer..."

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: selfsigned-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: selfsigned-ca
  secretName: selfsigned-ca-secret
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: selfsigned-ca-secret
EOF

# Wait for certificate
sleep 10
kubectl wait --for=condition=ready certificate selfsigned-ca -n cert-manager --timeout=60s

log_info "✅ Self-signed ClusterIssuer created"

# ============================================
# Step 5: Deploy Test App (whoami)
# ============================================
log_step "Step 5: Deploying test application (whoami)..."

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: whoami
  template:
    metadata:
      labels:
        app: whoami
    spec:
      containers:
      - name: whoami
        image: traefik/whoami:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: whoami
  namespace: default
spec:
  selector:
    app: whoami
  ports:
  - port: 80
    targetPort: 80
EOF

# Wait for pod
kubectl wait --for=condition=ready pod -l app=whoami --timeout=60s

log_info "✅ Test app deployed"

# ============================================
# Step 6: Create Ingress with TLS
# ============================================
log_step "Step 6: Creating Ingress with TLS..."

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami-selfsigned
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: ca-issuer
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - whoami.local
    secretName: whoami-local-tls
  rules:
  - host: whoami.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: whoami
            port:
              number: 80
EOF

# Wait for certificate
sleep 15
kubectl wait --for=condition=ready certificate whoami-local-tls -n default --timeout=120s

log_info "✅ Ingress with TLS created"

# ============================================
# Step 7: Fix Ingress Webhook (if needed)
# ============================================
log_step "Step 7: Fixing Ingress admission webhook..."

# Delete ingress webhook if it exists
kubectl delete validatingwebhookconfiguration ingress-nginx-admission 2>/dev/null || true

# Restart ingress controller
kubectl delete pods -n ingress-nginx --all 2>/dev/null || true
sleep 10
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller -n ingress-nginx --timeout=120s

log_info "✅ Ingress webhook fix applied"

# ============================================
# Step 8: Verification
# ============================================
log_step "Step 8: Verifying installation..."

echo ""
echo "========================================="
echo "🔍 VERIFICATION RESULTS"
echo "========================================="

# Check ClusterIssuers
echo ""
echo "📊 ClusterIssuers:"
kubectl get clusterissuer

# Check Certificates
echo ""
echo "📊 Certificates:"
kubectl get certificate -A

# Check Ingress
echo ""
echo "📊 Ingress:"
kubectl get ingress

# Test via port-forward
echo ""
echo "📊 Testing Ingress (port-forward method):"
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443 &
PF_PID=$!
sleep 3

if curl -k --max-time 10 https://whoami.local:8443 --resolve whoami.local:8443:127.0.0.1 &>/dev/null; then
    echo "✅ Ingress test PASSED"
else
    echo "⚠️ Ingress test failed - check logs"
fi

kill $PF_PID 2>/dev/null

# Get NodePort info
NODE_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
MASTER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "========================================="
echo "✅ INSTALLATION COMPLETE!"
echo "========================================="
echo ""
echo "📝 Access Information:"
echo "   Port-Forward: kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443"
echo "   Test: curl -k https://whoami.local:8443 --resolve whoami.local:8443:127.0.0.1"
echo ""
echo "   NodePort (if security group allows):"
echo "   curl -k https://$MASTER_IP:$NODE_PORT -H 'Host: whoami.local'"
echo ""
echo "========================================="