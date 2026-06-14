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
TOOLS_DIR="$HOME/cosign-tools"
mkdir -p $TOOLS_DIR
cd $TOOLS_DIR

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