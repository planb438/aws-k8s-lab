#!/bin/bash
# Configure concrete security flags on API server
# Run on MASTER node

set -e

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

echo "🔧 Configuring security flags on API server..."

# Backup manifest
sudo cp $MANIFEST ${MANIFEST}.backup.$(date +%Y%m%d_%H%M%S)

# Function to add flag after kube-apiserver line
add_flag() {
    local flag="$1"
    if ! grep -q "$flag" $MANIFEST; then
        sudo sed -i "/- kube-apiserver/a\    - $flag" $MANIFEST
        echo "  Added: $flag"
    else
        echo "  Already present: $flag"
    fi
}

# Function to update existing flag
update_flag() {
    local flag="$1"
    local value="$2"
    if grep -q "${flag%%=*}" $MANIFEST; then
        sudo sed -i "s|${flag%%=*}=.*|${flag}=${value}|" $MANIFEST
        echo "  Updated: ${flag}=${value}"
    else
        add_flag "${flag}=${value}"
    fi
}

echo "Adding security flags..."

# Update admission plugins (preserve existing, add AlwaysPullImages)
CURRENT_ADMISSION=$(grep -oP -- '--enable-admission-plugins=\K[^ ]+' $MANIFEST | head -1)
if [[ -n "$CURRENT_ADMISSION" ]]; then
    if [[ ! "$CURRENT_ADMISSION" =~ "AlwaysPullImages" ]]; then
        NEW_ADMISSION="${CURRENT_ADMISSION},AlwaysPullImages"
        update_flag "--enable-admission-plugins" "$NEW_ADMISSION"
    fi
else
    add_flag "--enable-admission-plugins=NodeRestriction,AlwaysPullImages"
fi

# Add/update other security flags
add_flag "--anonymous-auth=false"
add_flag "--profiling=false"

echo "✅ Security flags configured"
echo "API server will auto-restart. Waiting 30 seconds..."
sleep 30

if sudo kubectl get pods -n kube-system 2>/dev/null | grep -q kube-apiserver; then
    echo "✅ API server is healthy"
else
    echo "⚠️ API server may still be restarting"
fi