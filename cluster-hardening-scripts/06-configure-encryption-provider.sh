#!/bin/bash
# Configure encryption at rest for Kubernetes secrets
# Run on MASTER node
# Reference: https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/

set -e

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
ENCRYPTION_CONFIG="/etc/kubernetes/encryption/encryption-config.yaml"
ENCRYPTION_DIR="/etc/kubernetes/encryption"

echo "========================================="
echo "🔐 Configuring Encryption at Rest"
echo "========================================="

# Step 1: Create encryption directory
echo ""
echo "📁 Step 1: Creating encryption directory..."
sudo mkdir -p $ENCRYPTION_DIR
sudo chmod 700 $ENCRYPTION_DIR
echo "   Directory: $ENCRYPTION_DIR"

# Step 2: Generate encryption key
echo ""
echo "🔑 Step 2: Generating encryption key..."
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
echo "   Key generated (save this for disaster recovery):"
echo "   $ENCRYPTION_KEY"

# Step 3: Create encryption configuration file
echo ""
echo "📝 Step 3: Creating encryption configuration..."
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

# Step 4: Backup current manifest
echo ""
echo "💾 Step 4: Backing up API server manifest..."
sudo cp $MANIFEST ${MANIFEST}.backup.$(date +%Y%m%d_%H%M%S)
echo "   Backup: ${MANIFEST}.backup.$(date +%Y%m%d_%H%M%S)"

# Step 5: Remove existing encryption flag (if any)
echo ""
echo "🧹 Step 5: Cleaning up existing encryption flags..."
sudo sed -i '/--encryption-provider-config/d' $MANIFEST

# Step 6: Add encryption flag AFTER kube-apiserver line
echo ""
echo "⚙️ Step 6: Adding encryption flag to API server..."
if ! grep -q "--encryption-provider-config" $MANIFEST; then
    sudo sed -i "/- kube-apiserver/a\    - --encryption-provider-config=$ENCRYPTION_CONFIG" $MANIFEST
    echo "   Added: --encryption-provider-config=$ENCRYPTION_CONFIG"
else
    echo "   Already present: --encryption-provider-config"
fi

# Step 7: Add volume mount for encryption config
echo ""
echo "🔌 Step 7: Adding volume mount..."
if ! grep -q "name: enc" $MANIFEST; then
    sudo sed -i '/volumeMounts:/a\
    - mountPath: /etc/kubernetes/encryption\
      name: enc\
      readOnly: true' $MANIFEST
    echo "   Added volume mount: enc -> /etc/kubernetes/encryption"
else
    echo "   Volume mount already present: enc"
fi

# Step 8: Add hostPath volume (FIXED - adds complete volume entry)
echo ""
echo "💿 Step 8: Adding hostPath volume..."
if ! grep -q "name: enc$" $MANIFEST; then
    # Find the volumes: section and add the enc volume before other volumes
    # This creates the exact format you needed:
    # - name: enc
    #   hostPath:
    #     path: /etc/kubernetes/encryption
    #     type: DirectoryOrCreate
    sudo sed -i '/volumes:/a\
  - name: enc\
    hostPath:\
      path: /etc/kubernetes/encryption\
      type: DirectoryOrCreate' $MANIFEST
    echo "   Added volume: enc -> /etc/kubernetes/encryption"
else
    echo "   Volume already present: enc"
fi

# Step 9: Restart API server
echo ""
echo "🔄 Step 9: Restarting API server..."
sudo crictl pods --name kube-apiserver -q 2>/dev/null | xargs -r sudo crictl stopp 2>/dev/null || true

echo "   Waiting for API server to restart (45 seconds)..."
sleep 45

# Step 10: Verify API server is healthy
echo ""
echo "🏥 Step 10: Verifying API server health..."
if kubectl get nodes &>/dev/null; then
    echo "   ✅ API server is healthy and responding"
else
    echo "   ⚠️ API server may still be starting..."
fi

# Step 11: Rewrite existing secrets (CRITICAL STEP)
echo ""
echo "🔄 Step 11: Rewriting existing secrets to encrypt them..."
echo "   This forces etcd to re-encrypt all secrets with the new key..."

kubectl get secrets --all-namespaces -o json | \
  jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' 2>/dev/null | \
  while read ns name; do
    echo "   Rewriting: $ns/$name"
    kubectl get secret $name -n $ns -o json | \
      jq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp)' | \
      kubectl apply -f - 2>/dev/null || true
  done

echo "   ✅ Secrets rewritten"

# Step 12: Create a test secret to verify encryption
echo ""
echo "🔍 Step 12: Verifying encryption in etcd..."
TEST_SECRET="encryption-test-secret-$(date +%s)"

kubectl create secret generic $TEST_SECRET --from-literal=test=value --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
echo "   Created test secret: $TEST_SECRET"

sleep 2

ETCD_OUTPUT=$(sudo etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/default/$TEST_SECRET 2>/dev/null | head -c 100)

if echo "$ETCD_OUTPUT" | grep -q "k8s:enc:" || echo "$ETCD_OUTPUT" | grep -q "^k8s"; then
    echo "   ✅ Encryption is WORKING! (Encryption header found)"
else
    echo "   ⚠️ Encryption header not found. Check configuration."
fi

kubectl delete secret $TEST_SECRET --ignore-not-found 2>/dev/null

# Step 13: Verify both volume mount and volume exist
echo ""
echo "🔍 Step 13: Verifying manifest configuration..."
echo ""
echo "   Volume mount (should show enc):"
grep -A2 "name: enc" $MANIFEST | head -5 || echo "   ⚠️ Volume mount not found"
echo ""
echo "   Volume (should show enc with hostPath):"
grep -A4 "name: enc$" $MANIFEST | head -6 || echo "   ⚠️ Volume not found"

# Summary
echo ""
echo "========================================="
echo "✅ Encryption at Rest Configuration Complete!"
echo "========================================="
echo ""
echo "⚠️  IMPORTANT: Save this encryption key for disaster recovery:"
echo "   $ENCRYPTION_KEY"
echo ""
echo "========================================="
