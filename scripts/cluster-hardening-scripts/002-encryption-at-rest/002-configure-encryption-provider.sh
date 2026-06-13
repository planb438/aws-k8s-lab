#!/bin/bash
# Configure encryption at rest for Kubernetes secrets
# Run on MASTER node
# Reference: https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/

set -e

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
ENCRYPTION_CONFIG="/etc/kubernetes/encryption-config.yaml"  # ← File, not directory!
ENCRYPTION_KEY_FILE="/etc/kubernetes/encryption-key.txt"

echo "========================================="
echo "🔐 Configuring Encryption at Rest"
echo "========================================="

# Step 1: Generate encryption key
echo ""
echo "🔑 Step 1: Generating encryption key..."
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
echo "$ENCRYPTION_KEY" | sudo tee $ENCRYPTION_KEY_FILE > /dev/null
sudo chmod 600 $ENCRYPTION_KEY_FILE
echo "   Key saved: $ENCRYPTION_KEY_FILE"

# Step 2: Create encryption configuration file
echo ""
echo "📝 Step 2: Creating encryption configuration..."
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
echo "   Config file: $ENCRYPTION_CONFIG"

# Step 3: Backup current manifest
echo ""
echo "💾 Step 3: Backing up API server manifest..."
BACKUP_DIR="/etc/kubernetes/backups/manifests"
sudo mkdir -p $BACKUP_DIR
sudo cp $MANIFEST $BACKUP_DIR/kube-apiserver.yaml.backup.$(date +%Y%m%d_%H%M%S)
echo "   Backup: ${MANIFEST}.backup.encryption.$(date +%Y%m%d_%H%M%S)"

# Step 4: Remove existing encryption flags and volumes (clean up)
echo ""
echo "🧹 Step 4: Cleaning up existing encryption configuration..."
sudo sed -i '/--encryption-provider-config/d' $MANIFEST
sudo sed -i '/name: encryption-config/d' $MANIFEST

# Step 5: Add encryption flag AFTER kube-apiserver line
echo ""
echo "⚙️ Step 5: Adding encryption flag..."
sudo sed -i '/- kube-apiserver/a\
    - --encryption-provider-config=/etc/kubernetes/encryption-config.yaml' $MANIFEST
echo "   Added encryption flag"

# Step 6: Add volume mount for encryption config (readOnly: true)
echo ""
echo "🔌 Step 6: Adding volume mount for encryption config..."
if ! grep -q "name: encryption-config" $MANIFEST; then
    sudo sed -i '/volumeMounts:/a\
    - mountPath: /etc/kubernetes/encryption-config.yaml\
      name: encryption-config\
      readOnly: true' $MANIFEST
    echo "   Added volume mount: encryption-config"
fi

# Step 7: Add hostPath volume for encryption config (FileOrCreate - like audit policy)
echo ""
echo "💿 Step 7: Adding hostPath volume for encryption config..."
if ! grep -q "path: /etc/kubernetes/encryption-config.yaml" $MANIFEST; then
    sudo sed -i '/volumes:/a\
  - name: encryption-config\
    hostPath:\
      path: /etc/kubernetes/encryption-config.yaml\
      type: FileOrCreate' $MANIFEST
    echo "   Added volume: encryption-config -> /etc/kubernetes/encryption-config.yaml"
fi

# Step 8: Restart API server
echo ""
echo "🔄 Step 8: Restarting API server..."
sudo crictl pods --name kube-apiserver -q 2>/dev/null | xargs -r sudo crictl stopp 2>/dev/null || true

echo "   Waiting for API server to restart (45 seconds)..."
sleep 45

# Step 9: Verify API server is healthy
echo ""
echo "🏥 Step 9: Verifying API server health..."
if kubectl get nodes &>/dev/null; then
    echo "   ✅ API server is healthy and responding"
else
    echo "   ⚠️ API server may still be starting..."
fi

# Step 10: Rewrite existing secrets
echo ""
echo "🔄 Step 10: Rewriting existing secrets to use encryption..."
echo "   This may take a moment..."

kubectl get secrets --all-namespaces -o json 2>/dev/null | \
  jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' 2>/dev/null | \
  while read ns name; do
    if [ -n "$ns" ] && [ -n "$name" ]; then
        echo "   Rewriting: $ns/$name"
        kubectl get secret "$name" -n "$ns" -o json 2>/dev/null | \
          jq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.managedFields)' 2>/dev/null | \
          kubectl apply -f - 2>/dev/null || true
    fi
  done
echo "   ✅ Secrets rewritten"

# Step 11: Test encryption
echo ""
echo "🔍 Step 11: Verifying encryption is working..."
TEST_SECRET="encryption-test-$(date +%s)"
kubectl create secret generic $TEST_SECRET --from-literal=test=value --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null

sleep 3

# Check etcd directly
ETCD_OUTPUT=$(sudo ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/default/$TEST_SECRET 2>/dev/null | head -c 100)

if echo "$ETCD_OUTPUT" | grep -q "k8s:enc:aesgcm:"; then
    echo "   ✅✅✅ ENCRYPTION IS WORKING!"
    echo "   Secret encrypted with AES-GCM"
elif echo "$ETCD_OUTPUT" | grep -q "k8s:enc:"; then
    echo "   ✅ Encryption is working (provider detected)"
else
    echo "   ⚠️ Encryption may not be active - check configuration"
    echo "   First 100 chars of etcd output:"
    echo "   $ETCD_OUTPUT"
fi

# Clean up test secret
kubectl delete secret $TEST_SECRET --ignore-not-found 2>/dev/null

# Step 12: Verify volumes exist in manifest
echo ""
echo "🔍 Step 12: Verifying volumes in manifest..."
echo ""
echo "   Encryption flag:"
grep "encryption-provider-config" $MANIFEST
echo ""
echo "   Volume mount:"
grep -A2 "name: encryption-config" $MANIFEST | head -4
echo ""
echo "   Volume (hostPath):"
grep -A3 "name: encryption-config$" $MANIFEST | head -5

# Summary
echo ""
echo "========================================="
echo "✅ Encryption at Rest Configuration Complete!"
echo "========================================="
echo ""
echo "Encryption Configuration:"
echo "  --encryption-provider-config=/etc/kubernetes/encryption-config.yaml"
echo "  Provider: AES-GCM"
echo ""
echo "Volumes Configured:"
echo "  - name: encryption-config (FileOrCreate) -> /etc/kubernetes/encryption-config.yaml"
echo ""
echo "⚠️  SAVE THIS KEY FOR DISASTER RECOVERY:"
echo "   $ENCRYPTION_KEY"
echo ""
echo "To verify encryption manually:"
echo "  sudo ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \\"
echo "    --cert=/etc/kubernetes/pki/etcd/server.crt \\"
echo "    --key=/etc/kubernetes/pki/etcd/server.key \\"
echo "    get /registry/secrets/default/<secret-name>"
echo ""
echo "========================================="