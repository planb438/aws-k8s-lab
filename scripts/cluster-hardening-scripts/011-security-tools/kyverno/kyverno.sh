#!/bin/bash
# CKS Security Tools Installer - kube-bench, Trivy, kyverno, and more
# Run on your MASTER node after cluster is built

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

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
    ARCH="arm64"
fi

log_info "Detected OS: $OS, Architecture: $ARCH"

# Create tools directory
TOOLS_DIR="$HOME/kyverno-tools"
mkdir -p $TOOLS_DIR
cd $TOOLS_DIR

# ============================================
# 8. Install kyverno 
# ============================================
log_step "Installing kyverno..."

helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace

log_info "✅ kyverno installed"

 # ============================================
# Create validation script
# ============================================
log_step "Creating validation script..."

cat > $TOOLS_DIR/run-security-checks.sh << 'EOFSCRIPT'
#!/bin/bash
# Run all security checks on your cluster

set -e

echo "========================================="
echo "🔐 CKS Security Validation Suite"
echo "========================================="

# 4. Check kyverno
echo ""
echo "📊 4. Checking kyverno..."
kubectl get pods -n kyverno 2>/dev/null || echo "kyverno not installed"

echo ""
echo "✅ Security check complete!"
EOFSCRIPT

chmod +x $TOOLS_DIR/run-security-checks.sh

# ============================================
# Create summary
# ============================================
echo ""
echo "========================================="
log_step "INSTALLATION COMPLETE"
echo "========================================="
echo ""
log_info "Tools installed in: $TOOLS_DIR"

echo ""
log_info "Installation complete! Tools ready for CKS compliance."
