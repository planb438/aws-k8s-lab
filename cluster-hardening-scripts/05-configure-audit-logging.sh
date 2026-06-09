#!/bin/bash
# Fix audit logging - Complete solution
# Run on MASTER node

set -e

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
AUDIT_POLICY="/etc/kubernetes/audit-policy.yaml"
AUDIT_LOG_DIR="/var/log/kubernetes/audit"
AUDIT_LOG_FILE="$AUDIT_LOG_DIR/audit.log"

echo "🔧 Fixing audit logging configuration..."

# Step 1: Create directory with proper permissions
echo "Step 1: Creating audit log directory..."
sudo mkdir -p $AUDIT_LOG_DIR
sudo chmod 755 $AUDIT_LOG_DIR
sudo chown root:root $AUDIT_LOG_DIR

# Step 2: Create audit policy file (corrected YAML syntax)
echo "Step 2: Creating audit policy file..."
sudo tee $AUDIT_POLICY << 'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
- level: RequestResponse
  resources:
  - group: ""
    resources: ["pods"]
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets"]
- level: Metadata
  omitStages:
  - RequestReceived
EOF

sudo chmod 644 $AUDIT_POLICY
echo "✅ Audit policy created at $AUDIT_POLICY"

# Step 3: Backup current manifest
echo "Step 3: Backing up API server manifest..."
sudo cp $MANIFEST ${MANIFEST}.backup.$(date +%Y%m%d_%H%M%S)

# Step 4: Remove any existing audit flags (to clean up duplicates)
echo "Step 4: Cleaning up existing audit flags..."
sudo sed -i '/--audit-/d' $MANIFEST

# Step 5: Add audit flags in correct order (after - kube-apiserver)
echo "Step 5: Adding audit flags..."
sudo sed -i '/- kube-apiserver/a\
    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml\
    - --audit-log-path=/var/log/kubernetes/audit/audit.log\
    - --audit-log-maxage=30\
    - --audit-log-maxbackup=10\
    - --audit-log-maxsize=100' $MANIFEST

# Step 6: Ensure volume mounts exist
echo "Step 6: Adding volume mounts..."
if ! grep -q "name: audit-log" $MANIFEST; then
    sudo sed -i '/volumeMounts:/a\
    - mountPath: /var/log/kubernetes/audit\
      name: audit-log' $MANIFEST
fi

if ! grep -q "name: audit" $MANIFEST; then
    sudo sed -i '/volumeMounts:/a\
    - mountPath: /etc/kubernetes/audit-policy.yaml\
      name: audit\
      readOnly: true' $MANIFEST
fi

# Step 7: Ensure volumes exist
echo "Step 7: Adding volumes..."
if ! grep -q "name: audit-log$" $MANIFEST; then
    sudo sed -i '/volumes:/a\
  - hostPath:\
      path: /var/log/kubernetes/audit\
      type: DirectoryOrCreate\
    name: audit-log' $MANIFEST
fi

if ! grep -q "name: audit$" $MANIFEST; then
    sudo sed -i '/volumes:/a\
  - hostPath:\
      path: /etc/kubernetes/audit-policy.yaml\
      type: FileOrCreate\
    name: audit' $MANIFEST
fi

# Step 8: Restart API server
echo "Step 8: Restarting API server..."
sudo crictl pods --name kube-apiserver -q 2>/dev/null | xargs -r sudo crictl stopp 2>/dev/null || true

echo "Waiting for API server to restart (45 seconds)..."
sleep 45

# Step 9: Verify API server is healthy
echo "Step 9: Verifying API server health..."
if kubectl get nodes &>/dev/null; then
    echo "✅ API server is healthy and responding"
else
    echo "⚠️ API server may still be starting..."
fi

# Step 10: Create a test event to trigger audit logging
echo "Step 10: Generating test audit events..."
kubectl get pods -A &>/dev/null
kubectl get secrets -A &>/dev/null
kubectl get configmaps -A &>/dev/null

# Step 11: Check if audit log exists
echo "Step 11: Checking audit log..."
sleep 10

if sudo test -f "$AUDIT_LOG_FILE"; then
    echo "✅ Audit log file created!"
    sudo ls -la $AUDIT_LOG_DIR
    echo ""
    echo "First few lines of audit log:"
    sudo head -5 $AUDIT_LOG_FILE | jq '.' 2>/dev/null || sudo head -5 $AUDIT_LOG_FILE
else
    echo "⚠️ Audit log file not yet created. Checking API server logs..."
    POD_ID=$(sudo crictl ps --name kube-apiserver -q 2>/dev/null | head -1)
    if [ -n "$POD_ID" ]; then
        sudo crictl logs $POD_ID 2>&1 | grep -i audit | head -20
    fi
fi

echo ""
echo "✅ Audit logging configuration complete!"
echo "To monitor audit logs: sudo tail -f $AUDIT_LOG_FILE | jq '.'"