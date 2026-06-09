#!/bin/bash
# Fix 4.2.6 - protect-kernel-defaults on worker nodes
# Run on EACH WORKER node

set -e

KUBELET_CONFIG="/var/lib/kubelet/config.yaml"

echo "🔧 Setting protectKernelDefaults=true on kubelet..."

if [ -f "$KUBELET_CONFIG" ]; then
    # Backup config
    sudo cp $KUBELET_CONFIG ${KUBELET_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)
    
    # Remove existing setting if present
    sudo sed -i '/protectKernelDefaults/d' $KUBELET_CONFIG
    
    # Add the setting
    echo "protectKernelDefaults: true" | sudo tee -a $KUBELET_CONFIG
    
    echo "Updated kubelet config:"
    sudo grep protectKernelDefaults $KUBELET_CONFIG || echo "protectKernelDefaults: true"
    
    # Restart kubelet
    sudo systemctl restart kubelet
    sudo systemctl status kubelet --no-pager | head -10
    
    echo "✅ kubelet restarted with protectKernelDefaults=true"
else
    echo "❌ Kubelet config not found at $KUBELET_CONFIG"
    exit 1
fi