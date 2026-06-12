#!/bin/bash
# Fix 1.2.19 - disable insecure port on API server
# Run on MASTER node

set -e

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

echo "🔧 Disabling insecure port on API server..."

# Backup manifest
sudo cp $MANIFEST ${MANIFEST}.backup.$(date +%Y%m%d_%H%M%S)

# Check if --insecure-port already exists
if grep -q "--insecure-port" $MANIFEST; then
    echo "Updating existing --insecure-port flag..."
    sudo sed -i 's/--insecure-port=[0-9]*/--insecure-port=0/' $MANIFEST
else
    echo "Adding --insecure-port=0 flag..."
    sudo sed -i '/command:/a\    - --insecure-port=0' $MANIFEST
fi

echo "✅ Insecure port disabled"
echo "API server will auto-restart in 30 seconds..."
sleep 30

# Verify API server is healthy
if kubectl get pods -n kube-system | grep -q kube-apiserver; then
    echo "✅ API server is healthy"
else
    echo "⚠️ API server may still be restarting. Check with: kubectl get pods -n kube-system"
fi