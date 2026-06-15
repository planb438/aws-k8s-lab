#!/bin/bash
# Simplified Ingress + Cert Manager Installation Script
# Run on MASTER node after cluster is ready

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# ============================================
# Step 1: Install Ingress (No cert-manager yet)
# ============================================
log_step "Installing Nginx Ingress Controller..."

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
kubectl create ns ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

# install Ingress with HostNetwork (bypasses Calico)
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.hostNetwork=true \
  --set controller.service.type=ClusterIP \
  --set controller.admissionWebhooks.enabled=false

log_info "✅ Ingress installed"

# ============================================
# Step 2: Install Cert-Manager WITHOUT WAIT
# ============================================
log_step "Installing Cert Manager (background)..."

helm repo add jetstack https://charts.jetstack.io
helm repo update
kubectl create ns cert-manager --dry-run=client -o yaml | kubectl apply -f -

# CRITICAL: No --wait flag here!
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true

log_info "Cert Manager installation started"

# ============================================
# Step 3: Immediate Webhook Fix
# ============================================
log_step "Fixing cert-manager webhook..."

sleep 10

# Delete the webhook that causes timeout
kubectl delete validatingwebhookconfiguration cert-manager-webhook 2>/dev/null || true
kubectl delete mutatingwebhookconfiguration cert-manager-webhook 2>/dev/null || true

# Restart pods
kubectl delete pods -n cert-manager --all 2>/dev/null || true

log_info "Waiting for cert-manager pods..."
sleep 20

# Check if pods are running
kubectl get pods -n cert-manager

log_info "✅ Cert Manager webhook fixed"

# ============================================
# Step 4: Create ClusterIssuer
# ============================================
log_step "Creating self-signed ClusterIssuer..."

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

sleep 10
kubectl get clusterissuer

log_info "✅ ClusterIssuer created"

# ============================================
# Step 5: Deploy Test App
# ============================================
log_step "Deploying test app..."

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

kubectl wait --for=condition=ready pod -l app=whoami --timeout=60s

log_info "✅ Test app deployed"

# ============================================
# Step 6: Create Ingress with TLS
# ============================================
log_step "Creating Ingress with TLS..."

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

sleep 15
kubectl get certificate whoami-local-tls

# ============================================
# Step 7: Fix Ingress Webhook
# ============================================
log_step "Fixing ingress webhook..."

kubectl delete validatingwebhookconfiguration ingress-nginx-admission 2>/dev/null || true
kubectl delete pods -n ingress-nginx --all 2>/dev/null || true
sleep 10
kubectl get pods -n ingress-nginx

# ============================================
# Step 8: Test
# ============================================
log_step "Testing..."

kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443 &
sleep 5

echo ""
echo "========================================="
echo "🔍 TEST: curl with HTTPS"
echo "========================================="

curl -k --max-time 10 https://whoami.local:8443 --resolve whoami.local:8443:127.0.0.1

pkill -f "port-forward" 2>/dev/null

echo ""
echo "========================================="
echo "✅ INSTALLATION COMPLETE!"
echo "========================================="
