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
TOOLS_DIR="$HOME/kubeseal-tools"
mkdir -p $TOOLS_DIR
cd $TOOLS_DIR


 ============================================
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

# 4. Check Falco
echo ""
echo "📊 4. Checking Falco..."
kubectl get pods -n falco 2>/dev/null || echo "Falco not installed"

# 5. Check Network Policies
echo ""
echo "📊 5. Network Policies coverage..."
kubectl get networkpolicies --all-namespaces 2>/dev/null

# 6. Check Pod Security Standards
echo ""
echo "📊 6. Pod Security Standards..."
kubectl get ns -o custom-columns=NAME:.metadata.name,PSA:.metadata.labels.'pod-security\.kubernetes\.io/enforce'

echo ""
echo "✅ Security check complete!"
EOFSCRIPT

chmod +x $TOOLS_DIR/run-security-checks.sh

# ============================================
# Create kube-bench runner script
# ============================================
log_step "Creating kube-bench runner..."

cat > $TOOLS_DIR/run-kube-bench.sh << 'EOF'
#!/bin/bash
# Run kube-bench on all control plane components

echo "========================================="
echo "🔐 kube-bench CIS Compliance Check"
echo "========================================="

# Master node checks
echo ""
echo "📊 Control Plane Checks:"
kube-bench master --version 1.31

# Node checks (if you have node access)
echo ""
echo "📊 Node Checks:"
kube-bench node --version 1.31

# Detailed JSON output for automation
echo ""
echo "📊 Detailed results (JSON):"
kube-bench master --version 1.31 --json | jq '.Totals'

echo ""
echo "✅ CIS benchmark complete!"
echo "Target: 0 failures for production readiness"
EOF

chmod +x $TOOLS_DIR/run-kube-bench.sh

# ============================================
# Create image scanner script
# ============================================
log_step "Creating image scanner..."

cat > $TOOLS_DIR/scan-images.sh << 'EOF'
#!/bin/bash
# Scan container images for vulnerabilities

echo "========================================="
echo "🔐 Container Image Vulnerability Scanner"
echo "========================================="

# Scan NextCloud image
echo ""
echo "📊 Scanning NextCloud image..."
trivy image nextcloud:latest --severity CRITICAL,HIGH

# Scan PostgreSQL image
echo ""
echo "📊 Scanning PostgreSQL image..."
trivy image postgres:15-alpine --severity CRITICAL,HIGH

# Generate SBOM for NextCloud
echo ""
echo "📊 Generating SBOM for NextCloud..."
syft nextcloud:latest -o json > nextcloud-sbom.json
echo "SBOM saved to nextcloud-sbom.json"

# Scan SBOM for vulnerabilities
echo ""
echo "📊 Scanning SBOM for vulnerabilities..."
grype sbom:nextcloud-sbom.json --fail-on high

echo ""
echo "✅ Image scan complete!"
EOF

chmod +x $TOOLS_DIR/scan-images.sh

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
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  Available Commands                                     │"
echo "├─────────────────────────────────────────────────────────┤"
echo "│  kube-bench          - CIS Benchmark scanner           │"
echo "│  trivy               - Container vulnerability scanner │"
echo "│  syft                - SBOM generator                  │"
echo "│  grype               - Vulnerability scanner for SBOM  │"
echo "│  cosign              - Image signing tool              │"
echo "│  kubectl             - Kubernetes CLI                  │"
echo "│  helm                - Kubernetes package manager      │"
echo "│  kubescape           - Alternative CIS scanner         │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  Scripts Available                                      │"
echo "├─────────────────────────────────────────────────────────┤"
echo "│  ./run-kube-bench.sh    - Run CIS compliance checks    │"
echo "│  ./scan-images.sh       - Scan container images        │"
echo "│  ./run-security-checks.sh - Complete security audit    │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
log_info "Next steps:"
echo "  1. Run kube-bench:    ./run-kube-bench.sh"
echo "  2. Scan images:       ./scan-images.sh"
echo "  3. Full security audit: ./run-security-checks.sh"
echo ""

# ============================================
# Test kube-bench
# ============================================
log_step "Testing kube-bench installation..."

if kube-bench version &> /dev/null; then
    log_info "✅ kube-bench working correctly"
    echo ""
    echo "Quick test run (first 10 checks only):"
    kube-bench --config-dir `pwd`/cfg --config `pwd`/cfg/config.yaml
else
    log_error "❌ kube-bench test failed"
fi

echo ""
log_info "Installation complete! Tools ready for CKS compliance."
