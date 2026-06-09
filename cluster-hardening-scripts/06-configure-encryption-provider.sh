#!/bin/bash
# Configure encryption at rest
# Run on MASTER node

set -e

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
ENCRYPTION_CONFIG="/etc/kubernetes/encryption/encryption-config.yaml"
ENCRYPTION_DIR="/etc/kubernetes/encryption"

echo "🔧 Configuring encryption at rest..."

# Create encryption directory
sudo mkdir -p $ENCRYPTION_DIR

# Generate encryption key (32 bytes base64)
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
echo "Generated encryption key (save this for backups):"
echo "$ENCRYPTION_KEY"

# Create encryption config file
sudo tee $ENCRYPTION_CONFIG << EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aesgcm:
          keys:
            - name: key1
              secret: $ENCRYPTION_KEY
      - identity: {}
EOF

sudo chmod 600 $ENCRYPTION_CONFIG
echo "✅ Encryption config created at $ENCRYPTION_CONFIG"

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

# Function to add volume mount
add_volume_mount() {
    local mount_path="$1"
    local name="$2"
    
    if ! grep -q "name: $name" $MANIFEST; then
        local indent="    "
        sudo sed -i "/volumeMounts:/a\\
${indent}- mountPath: $mount_path\\
${indent}  name: $name\\
${indent}  readOnly: true" $MANIFEST
        echo "  Added volume mount: $name -> $mount_path"
    fi
}

# Function to add volume
add_volume() {
    local name="$1"
    local path="$2"
    
    if ! grep -q "name: $name$" $MANIFEST; then
        sudo sed -i "/volumes:/a\\
  - hostPath:\\
      path: $path\\
      type: DirectoryOrCreate\\
    name: $name" $MANIFEST
        echo "  Added volume: $name -> $path"
    fi
}

echo "Adding encryption flag to API server..."
add_flag "--encryption-provider-config=$ENCRYPTION_CONFIG"

echo "Adding volume mount for encryption config..."
add_volume_mount "$ENCRYPTION_DIR" "enc"

echo "Adding volume for encryption config..."
add_volume "enc" "$ENCRYPTION_DIR"

echo "✅ Encryption provider configured"
echo "API server will auto-restart. Waiting 30 seconds..."
sleep 30

# Check API server status
if sudo kubectl get pods -n kube-system 2>/dev/null | grep -q kube-apiserver; then
    echo "✅ API server is healthy"
else
    echo "⚠️ API server may still be restarting"
fi

# Rewrite existing secrets to encrypt them
echo ""
echo "Rewriting existing secrets to encrypt them..."
kubectl get secrets --all-namespaces -o json | \
  jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' 2>/dev/null | \
  while read ns name; do
    echo "Rewriting secret: $ns/$name"
    kubectl get secret $name -n $ns -o json | jq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp)' | kubectl apply -f - 2>/dev/null || true
  done

echo "✅ All secrets rewritten and encrypted"