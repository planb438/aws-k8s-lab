#!/bin/bash
# Configure audit logging for Kubernetes API server
# Run on MASTER node
# Reference: https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/

set -e

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
AUDIT_POLICY="/etc/kubernetes/audit-policy.yaml"
AUDIT_LOG_DIR="/var/log/kubernetes/audit"
AUDIT_LOG_FILE="$AUDIT_LOG_DIR/audit.log"

echo "========================================="
echo "🔐 Configuring Kubernetes Audit Logging"
echo "========================================="

# Step 1: Create audit log directory
echo ""
echo "📁 Step 1: Creating audit log directory..."
sudo mkdir -p $AUDIT_LOG_DIR
sudo chmod 755 $AUDIT_LOG_DIR
sudo chown root:root $AUDIT_LOG_DIR
echo "   Directory: $AUDIT_LOG_DIR"

# Step 2: Create audit policy file
echo ""
echo "📝 Step 2: Creating audit policy file..."
sudo tee $AUDIT_POLICY << 'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: None
  users: ["system:kube-proxy", "system:unsecured", "system:kube-scheduler"]
  verbs: ["watch"]
  resources:                       # <-- ADD COLON HERE
  - group: ""                      # <-- FIX INDENTATION
    resources: ["endpoints", "services"]
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
- level: Metadata
  omitStages:
  - RequestReceived
EOF

sudo chmod 644 $AUDIT_POLICY
echo "   Policy file: $AUDIT_POLICY"

# Step 3: Backup current manifest
echo ""
echo "💾 Step 3: Backing up API server manifest..."
sudo cp $MANIFEST ${MANIFEST}.backup.$(date +%Y%m%d_%H%M%S)
echo "   Backup: ${MANIFEST}.backup.$(date +%Y%m%d_%H%M%S)"

# Step 4: Remove existing audit flags and volumes (clean up)
echo ""
echo "🧹 Step 4: Cleaning up existing audit configuration..."
sudo sed -i '/--audit-/d' $MANIFEST
sudo sed -i '/name: audit$/d' $MANIFEST
sudo sed -i '/name: audit-log$/d' $MANIFEST
# Remove the hostPath lines associated with audit volumes
sudo sed -i '/path: \/etc\/kubernetes\/audit-policy.yaml/d' $MANIFEST
sudo sed -i '/path: \/var\/log\/kubernetes\/audit/d' $MANIFEST
sudo sed -i '/type: FileOrCreate/d' $MANIFEST
sudo sed -i '/type: DirectoryOrCreate/d' $MANIFEST

# Step 5: Add audit flags AFTER kube-apiserver line
echo ""
echo "⚙️ Step 5: Adding audit flags..."
sudo sed -i '/- kube-apiserver/a\
    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml\
    - --audit-log-path=/var/log/kubernetes/audit/audit.log\
    - --audit-log-maxage=30\
    - --audit-log-maxbackup=10\
    - --audit-log-maxsize=100' $MANIFEST
echo "   Added audit flags"

# Step 6: Add volume mount for audit policy (readOnly: true)
echo ""
echo "🔌 Step 6: Adding volume mount for audit policy..."
if ! grep -q "name: audit" $MANIFEST; then
    sudo sed -i '/volumeMounts:/a\
    - mountPath: /etc/kubernetes/audit-policy.yaml\
      name: audit\
      readOnly: true' $MANIFEST
    echo "   Added volume mount: audit"
fi

# Step 7: Add volume mount for audit log (readOnly: false)
echo ""
echo "🔌 Step 7: Adding volume mount for audit log..."
if ! grep -q "name: audit-log" $MANIFEST; then
    sudo sed -i '/volumeMounts:/a\
    - mountPath: /var/log/kubernetes/audit\
      name: audit-log\
      readOnly: false' $MANIFEST
    echo "   Added volume mount: audit-log"
fi

# Step 8: Add hostPath volume for audit policy (CRITICAL FIX)
echo ""
echo "💿 Step 8: Adding hostPath volume for audit policy..."
if ! grep -q "path: /etc/kubernetes/audit-policy.yaml" $MANIFEST; then
    sudo sed -i '/volumes:/a\
  - name: audit\
    hostPath:\
      path: /etc/kubernetes/audit-policy.yaml\
      type: FileOrCreate' $MANIFEST
    echo "   Added volume: audit -> /etc/kubernetes/audit-policy.yaml"
fi

# Step 9: Add hostPath volume for audit log (CRITICAL FIX)
echo ""
echo "💿 Step 9: Adding hostPath volume for audit log..."
if ! grep -q "path: /var/log/kubernetes/audit" $MANIFEST; then
    sudo sed -i '/volumes:/a\
  - name: audit-log\
    hostPath:\
      path: /var/log/kubernetes/audit/\
      type: DirectoryOrCreate' $MANIFEST
    echo "   Added volume: audit-log -> /var/log/kubernetes/audit/"
fi

# Step 10: Restart API server
echo ""
echo "🔄 Step 10: Restarting API server..."
sudo crictl pods --name kube-apiserver -q 2>/dev/null | xargs -r sudo crictl stopp 2>/dev/null || true

echo "   Waiting for API server to restart (45 seconds)..."
sleep 45

# Step 11: Verify API server is healthy
echo ""
echo "🏥 Step 11: Verifying API server health..."
if kubectl get nodes &>/dev/null; then
    echo "   ✅ API server is healthy and responding"
else
    echo "   ⚠️ API server may still be starting..."
fi

# Step 12: Generate test audit events
echo ""
echo "📊 Step 12: Generating test audit events..."
kubectl get pods -A &>/dev/null
kubectl get secrets -A &>/dev/null
kubectl get configmaps -A &>/dev/null

# Step 13: Check audit log
echo ""
echo "🔍 Step 13: Checking audit log..."
sleep 10

if sudo test -f "$AUDIT_LOG_FILE"; then
    echo "   ✅ Audit log file created!"
    sudo ls -la $AUDIT_LOG_DIR
    echo ""
    echo "   First audit entry:"
    sudo head -1 $AUDIT_LOG_FILE | jq '.' 2>/dev/null || sudo head -1 $AUDIT_LOG_FILE
else
    echo "   ⚠️ Audit log file not yet created"
fi

# Step 14: Verify volumes exist in manifest
echo ""
echo "🔍 Step 14: Verifying volumes in manifest..."
echo ""
echo "   Volume mounts:"
grep -A1 "name: audit" $MANIFEST | head -6
echo ""
echo "   Volumes (hostPath):"
grep -B1 -A2 "audit" $MANIFEST | grep -E "name:|path:|type:" | head -12

# Summary
echo ""
echo "========================================="
echo "✅ Audit Logging Configuration Complete!"
echo "========================================="
echo ""
echo "Audit Configuration:"
echo "  --audit-policy-file=/etc/kubernetes/audit-policy.yaml"
echo "  --audit-log-path=/var/log/kubernetes/audit/audit.log"
echo "  --audit-log-maxage=30"
echo "  --audit-log-maxbackup=10"
echo "  --audit-log-maxsize=100"
echo ""
echo "Volumes Configured:"
echo "  - name: audit (FileOrCreate) -> /etc/kubernetes/audit-policy.yaml"
echo "  - name: audit-log (DirectoryOrCreate) -> /var/log/kubernetes/audit/"
echo ""
echo "To monitor audit logs:"
echo "  sudo tail -f $AUDIT_LOG_FILE | jq '.'"
echo ""
echo "========================================="
