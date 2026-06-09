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
echo "Generated encryption key: $ENCRYPTION_KEY"

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

# Add encryption flag if missing
if ! grep -q "--encryption-provider-config" $MANIFEST; then
    echo "Adding encryption flag to API server..."
    sudo sed -i "/command:/a\    - --encryption-provider-config=$ENCRYPTION_CONFIG" $MANIFEST
fi

# Add volume mount for encryption config
if ! grep -q "path: $ENCRYPTION_DIR" $MANIFEST; then
    echo "Adding encryption volume mount..."
    sudo sed -i "/volumeMounts:/a\    - mountPath: $ENCRYPTION_DIR\n      name: enc\n      readOnly: true" $MANIFEST
fi

# Add volume
if ! grep -q "name: enc$" $MANIFEST; then
    echo "Adding encryption volume..."
    sudo sed -i "/volumes:/a\  - hostPath:\n      path: $ENCRYPTION_DIR\n      type: DirectoryOrCreate\n    name: enc" $MANIFEST
fi

echo "✅ Encryption provider configured"
echo "API server will auto-restart..."

sleep 30
kubectl get pods -n kube-system | grep apiserver

# Rewrite existing secrets
echo "Rewriting existing secrets to encrypt them..."
kubectl get secrets --all-namespaces -o json | \
  jq '.items[].metadata.name' -r | \
  while read secret; do
    ns=$(kubectl get secret $secret --all-namespaces -o json | jq -r '.metadata.namespace')
    echo "Rewriting secret: $ns/$secret"
    kubectl get secret $secret -n $ns -o json | jq 'del(.metadata.resourceVersion)' | kubectl apply -f - 2>/dev/null
  done

echo "✅ All secrets encrypted"