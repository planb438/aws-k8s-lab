[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04%2B-lightgrey)](#)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-MicroK8s%20%7C%20kubeadm-blue)](#)
[![YouTube](https://img.shields.io/badge/YouTube-TechShorts-red)](https://www.youtube.com/@adaribain)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Adari%20Bain-blue)](https://www.linkedin.com/in/adari-bain-298924152/)


Complete Security Tools Installation Script
Create install-security-tools.sh:

bash
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
TOOLS_DIR="$HOME/security-tools"
mkdir -p $TOOLS_DIR
cd $TOOLS_DIR

# ============================================
# 1. Install kube-bench
# ============================================
log_step "Installing kube-bench..."

KUBE_BENCH_VERSION="0.8.0"
KUBE_BENCH_URL="https://github.com/aquasecurity/kube-bench/releases/download/v${KUBE_BENCH_VERSION}/kube-bench_${KUBE_BENCH_VERSION}_${OS}_${ARCH}.tar.gz"

log_info "Downloading kube-bench v${KUBE_BENCH_VERSION}..."
curl -sL $KUBE_BENCH_URL -o kube-bench.tar.gz
tar -xzf kube-bench.tar.gz
sudo mv kube-bench /usr/local/bin/
rm kube-bench.tar.gz

# Verify installation
if command -v kube-bench &> /dev/null; then
    log_info "✅ kube-bench installed: $(kube-bench version)"
else
    log_error "❌ kube-bench installation failed"
    exit 1
fi

---
Ubuntu/Debian:


curl -L https://github.com/aquasecurity/kube-bench/releases/download/v0.6.2/kube-bench_0.6.2_linux_amd64.deb -o kube-bench_0.6.2_linux_amd64.deb

sudo apt install ./kube-bench_0.6.2_linux_amd64.deb -f
RHEL:


curl -L https://github.com/aquasecurity/kube-bench/releases/download/v0.6.2/kube-bench_0.6.2_linux_amd64.rpm -o kube-bench_0.6.2_linux_amd64.rpm

sudo yum install kube-bench_0.6.2_linux_amd64.rpm -y
Alternatively, you can manually download and extract the kube-bench binary:


curl -L https://github.com/aquasecurity/kube-bench/releases/download/v0.6.2/kube-bench_0.6.2_linux_amd64.tar.gz -o kube-bench_0.6.2_linux_amd64.tar.gz

tar -xvf kube-bench_0.6.2_linux_amd64.tar.gz
You can then run kube-bench directly:


kube-bench
If you manually downloaded the kube-bench binary (using curl command above), you have to specify the location of configuration directory and file. For example:


./kube-bench --config-dir `pwd`/cfg --config `pwd`/cfg/config.yaml 

---

# ============================================
# 2. Install Trivy (Vulnerability Scanner)
# ============================================
log_step "Installing Trivy..."

if [ "$OS" = "linux" ]; then
    sudo apt-get install -y wget apt-transport-https gnupg lsb-release
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
    echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
    sudo apt-get update
    sudo apt-get install -y trivy
elif [ "$OS" = "darwin" ]; then
    brew install aquasecurity/trivy/trivy
fi

if command -v trivy &> /dev/null; then
    log_info "✅ Trivy installed: $(trivy --version | head -1)"
else
    log_warn "⚠️ Trivy installation failed - install manually"
fi

# ============================================
# 3. Install Syft (SBOM Generator)
# ============================================
log_step "Installing Syft..."

curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

if command -v syft &> /dev/null; then
    log_info "✅ Syft installed: $(syft version | head -1)"
else
    log_warn "⚠️ Syft installation failed"
fi

# ============================================
# 4. Install Grype (Vulnerability Scanner for SBOM)
# ============================================
log_step "Installing Grype..."

curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

if command -v grype &> /dev/null; then
    log_info "✅ Grype installed: $(grype version | head -1)"
else
    log_warn "⚠️ Grype installation failed"
fi

# ============================================
# 5. Install Cosign (Image Signing)
# ============================================
log_step "Installing Cosign..."

COSIGN_VERSION="2.2.3"
curl -sL "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-${OS}-${ARCH}" -o cosign
chmod +x cosign
sudo mv cosign /usr/local/bin/

if command -v cosign &> /dev/null; then
    log_info "✅ Cosign installed: $(cosign version | head -1)"
else
    log_warn "⚠️ Cosign installation failed"
fi

# ============================================
# 6. Install kubectl (if not present)
# ============================================
if ! command -v kubectl &> /dev/null; then
    log_step "Installing kubectl..."
    curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    log_info "✅ kubectl installed"
else
    log_info "✅ kubectl already installed"
fi

# ============================================
# 7. Install helm (if not present)
# ============================================
if ! command -v helm &> /dev/null; then
    log_step "Installing Helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    rm get_helm.sh
    log_info "✅ Helm installed"
else
    log_info "✅ Helm already installed"
fi

# ============================================
# 8. Install kubescape (CIS scanner alternative)
# ============================================
log_step "Installing Kubescape..."

curl -sL https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash -s

if command -v kubescape &> /dev/null; then
    log_info "✅ Kubescape installed: $(kubescape version)"
else
    log_warn "⚠️ Kubescape installation failed"
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

# 2. Kubescape (additional CIS scanner)
echo ""
echo "📊 2. Running Kubescape..."
kubescape scan framework nsa --verbose

# 3. Check Kyverno policies
echo ""
echo "📊 3. Checking Kyverno policies..."
kubectl get clusterpolicy -o custom-columns=NAME:.metadata.name,STATUS:.status.ready 2>/dev/null || echo "Kyverno not installed"

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
    kube-bench master --version 1.31 --check 1.1.1,1.1.2
else
    log_error "❌ kube-bench test failed"
fi

echo ""
log_info "Installation complete! Tools ready for CKS compliance."
How to Use This Script
1. Copy the script to your master node
bash
# On your local machine
scp -i k8s-lab-key.pem install-security-tools.sh ubuntu@<master-ip>:~

# Or create it directly on the master node
ssh -i k8s-lab-key.pem ubuntu@<master-ip>
nano install-security-tools.sh
# Paste the entire script above
2. Run the installer
bash
# On the master node
chmod +x install-security-tools.sh
./install-security-tools.sh
3. Run CIS benchmark on your cluster
bash
cd ~/security-tools
./run-kube-bench.sh
Expected Output
text
=========================================
🔐 kube-bench CIS Compliance Check
=========================================

📊 Control Plane Checks:
[INFO] 1 Master Node Security Configuration
[PASS] 1.1.1 Ensure that the API server pod specification file permissions are set to 644 or more restrictive (Manual)
[PASS] 1.1.2 Ensure that the API server pod specification file ownership is set to root:root (Manual)
...
[FAIL] 1.2.7 Ensure that the --authorization-mode argument is not set to AlwaysAllow (Automated)

Totals: PASS: 85, FAIL: 3, WARN: 5
Quick One-Liner Install (Alternative)
If you just want kube-bench quickly:

bash
# Install kube-bench only
curl -sL https://github.com/aquasecurity/kube-bench/releases/download/v0.8.0/kube-bench_0.8.0_linux_amd64.tar.gz | tar -xz && sudo mv kube-bench /usr/local/bin/
Integration with Your Cluster
After installing, run these checks on your cluster:

bash
# 1. Baseline CIS check (BEFORE NextCloud)
kube-bench master --version 1.31

# 2. After hardening (AFTER applying Kyverno policies)
kube-bench node --version 1.31

# 3. Generate report for compliance
kube-bench master --json | jq '.' > cis-report.json
What This Script Gives You
Tool	Purpose	When to Run
kube-bench	CIS Benchmark	Before/after changes
Trivy	Image CVEs	Before deployment
Syft	SBOM generation	Build time
Grype	Vulnerability scan	CI/CD pipeline
Cosign	Image signing	Build time
Kubescape	Additional CIS checks	Weekly
This gives you the complete CKS security toolchain!
