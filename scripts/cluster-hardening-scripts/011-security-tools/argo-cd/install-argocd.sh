#!/bin/bash
# Install Argo CD - GitOps Continuous Delivery
# Run on MASTER node after cluster hardening

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

echo ""
echo "========================================="
echo "🚀 Installing Argo CD"
echo "========================================="
echo ""

# ============================================
# Step 1: Create Namespace
# ============================================
log_step "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
log_info "✅ Namespace created"

# ============================================
# Step 2: Install Argo CD
# ============================================
log_step "Installing Argo CD..."
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

log_info "✅ Argo CD installed"

# ============================================
# Step 3: Wait for pods
# ============================================
log_step "Waiting for Argo CD pods to be ready..."
sleep 30
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=120s 2>/dev/null || true
kubectl get pods -n argocd

log_info "✅ Argo CD pods running"

# ============================================
# Step 4: Get Admin Password
# ============================================
log_step "Retrieving admin password..."
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "NOT_FOUND")

if [ "$ADMIN_PASSWORD" != "NOT_FOUND" ] && [ -n "$ADMIN_PASSWORD" ]; then
    echo "✅ Admin Password: $ADMIN_PASSWORD"
    echo "$ADMIN_PASSWORD" > argocd-admin-password.txt
    log_info "Password saved to: argocd-admin-password.txt"
else
    log_warn "Could not retrieve admin password. Check Argo CD status."
fi

# ============================================
# Step 5: Expose Argo CD (NodePort)
# ============================================
log_step "Exposing Argo CD via NodePort..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

sleep 5
NODE_PORT=$(kubectl get svc -n argocd argocd-server -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
MASTER_IP=$(hostname -I | awk '{print $1}')

echo ""
log_info "Argo CD available at: http://$MASTER_IP:$NODE_PORT"
echo "  Username: admin"
echo "  Password: $ADMIN_PASSWORD"

# ============================================
# Step 6: Install Argo CD CLI
# ============================================
log_step "Installing Argo CD CLI..."
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

if command -v argocd &> /dev/null; then
    log_info "✅ Argo CD CLI installed: $(argocd version --client 2>/dev/null | head -1)"
else
    log_warn "⚠️ Argo CD CLI installation failed"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "========================================="
log_step "ARGOCD INSTALLATION COMPLETE!"
echo "========================================="
echo ""
echo "📝 Access Information:"
echo "   URL: http://$MASTER_IP:$NODE_PORT"
echo "   Username: admin"
echo "   Password: $ADMIN_PASSWORD"
echo ""
echo "📝 CLI Commands:"
echo "   argocd login $MASTER_IP:$NODE_PORT --username admin --password $ADMIN_PASSWORD --insecure"
echo "   argocd app list"
echo "   argocd app get <app-name>"
echo ""
echo "📝 Next Steps:"
echo "   1. Add Git repo: argocd repo add <repo-url> --username <user> --password <token>"
echo "   2. Create app: argocd app create my-app --repo <repo-url> --path <path> --dest-server https://kubernetes.default.svc --dest-namespace default"
echo "   3. Sync app: argocd app sync my-app"
echo ""
echo "========================================="

echo "📝 # 1. Restart CoreDNS:"
kubectl delete pods -n kube-system -l k8s-app=kube-dns

echo "📝 # 2. Wait for CoreDNS to be ready:"
kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=60s

echo "📝 # 3. Restart Argo CD repo-server:"
kubectl delete pods -n argocd --all
sudo systemctl restart kubelet

echo "📝 # 4. Wait for restart:"
sleep 20

echo "📝 # 5. Check if it's working:"
kubectl get pods -n argocd
 
echo "📝 # 6. # Configure Argo CD CLI:"
NODE_PORT=$(kubectl get svc -n argocd argocd-server -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}') && \
MASTER_IP=$(hostname -I | awk '{print $1}') && \
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) && \
argocd login $MASTER_IP:$NODE_PORT --username admin --password $PASSWORD --insecure && \
argocd app list
