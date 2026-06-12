#!/bin/bash
# Fix 1.2.6 - add kubelet certificate authority
# Run on MASTER node

set -e

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
CA_FILE="/etc/kubernetes/pki/ca.crt"

echo "🔧 Adding kubelet certificate authority..."

# Verify CA file exists
if [ ! -f "$CA_FILE" ]; then
    echo "❌ CA file not found at $CA_FILE"
    exit 1
fi

# Backup manifest
sudo cp $MANIFEST ${MANIFEST}.backup.$(date +%Y%m%d_%H%M%S)

# Check if flag already exists
if grep -q "--kubelet-certificate-authority" $MANIFEST; then
    echo "Updating existing --kubelet-certificate-authority flag..."
    sudo sed -i "s|--kubelet-certificate-authority=.*|--kubelet-certificate-authority=$CA_FILE|" $MANIFEST
else
    echo "Adding --kubelet-certificate-authority flag..."
    sudo sed -i "/command:/a\    - --kubelet-certificate-authority=$CA_FILE" $MANIFEST
fi

echo "✅ Kubelet CA configured"
echo "API server will auto-restart..."
sleep 30

kubectl get pods -n kube-system | grep apiserver