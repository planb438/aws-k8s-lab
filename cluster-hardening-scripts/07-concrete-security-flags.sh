#!/bin/bash
# Configure concrete security flags on API server
# Run on MASTER node

set -e

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

echo "🔧 Configuring security flags on API server..."

# Backup manifest
sudo cp $MANIFEST ${MANIFEST}.backup.$(date +%Y%m%d_%H%M%S)

# Function to add or update flag
add_flag() {
    local flag="$1"
    if grep -q "${flag%%=*}" $MANIFEST; then
        echo "  Updating: $flag"
        sudo sed -i "s|${flag%%=*}=.*|$flag|" $MANIFEST
    else
        echo "  Adding: $flag"
        sudo sed -i "/command:/a\    - $flag" $MANIFEST
    fi
}

# Add/update security flags
echo "Adding security flags..."

add_flag "--anonymous-auth=false"
add_flag "--profiling=false"
add_flag "--enable-admission-plugins=NodeRestriction,AlwaysPullImages"

echo "✅ Security flags configured"
echo "API server will auto-restart..."

sleep 30
kubectl get pods -n kube-system | grep apiserver