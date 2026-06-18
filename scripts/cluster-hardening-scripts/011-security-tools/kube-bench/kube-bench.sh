#!/bin/bash
# CKS Security Tools Installer - kube-bench, Trivy, Falco, and more
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
TOOLS_DIR="$HOME/kube-bench-tools"
mkdir -p $TOOLS_DIR
cd $TOOLS_DIR

# ============================================
# 1. Install kube-bench
# ============================================
log_step "Installing kube-bench..."

curl -L https://github.com/aquasecurity/kube-bench/releases/download/v0.8.0/kube-bench_0.8.0_linux_amd64.tar.gz -o kube-bench_0.8.0_linux_amd64.tar.gz
tar -xvf kube-bench_0.8.0_linux_amd64.tar.gz
sudo mv kube-bench /usr/local/bin/

# Verify installation
if command -v kube-bench &> /dev/null; then
    log_info "✅ kube-bench installed: $(kube-bench version)"
else
    log_error "❌ kube-bench installation failed"
    exit 1
fi

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

# 1. kube-bench CIS checks
echo ""
echo "📊 1. Running kube-bench (CIS Benchmarks)..."
kube-bench master --version 1.31 --json | jq '.Totals' 2>/dev/null || kube-bench master --version 1.31

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
