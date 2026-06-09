#!/bin/bash
# Configure audit logging for API server
# Run on MASTER node

set -e

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
AUDIT_POLICY="/etc/kubernetes/audit-policy.yaml"
AUDIT_LOG_DIR="/var/log/kubernetes/audit"

echo "🔧 Configuring audit logging..."

# Create audit log directory
echo "Creating audit log directory..."
sudo mkdir -p $AUDIT_LOG_DIR
sudo chmod 700 $AUDIT_LOG_DIR

# Create audit policy file
echo "Creating audit policy file..."
sudo tee $AUDIT_POLICY << 'EOF'
# Log all requests at the Metadata level
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
EOF

echo "✅ Audit policy created at $AUDIT_POLICY"

# Backup manifest
sudo cp $MANIFEST ${MANIFEST}.backup.$(date +%Y%m%d_%H%M%S)

# Add audit flags if not present
add_flag_if_missing() {
    local flag="$1"
    if ! grep -q "$flag" $MANIFEST; then
        sudo sed -i "/command:/a\    - $flag" $MANIFEST
        echo "  Added: $flag"
    else
        echo "  Already present: $flag"
    fi
}

echo "Adding audit flags to API server..."
add_flag_if_missing "--audit-policy-file=$AUDIT_POLICY"
add_flag_if_missing "--audit-log-path=$AUDIT_LOG_DIR/audit.log"
add_flag_if_missing "--audit-log-maxage=30"
add_flag_if_missing "--audit-log-maxbackup=10"
add_flag_if_missing "--audit-log-maxsize=100"

# Add volume for audit policy
if ! grep -q "path: $AUDIT_POLICY" $MANIFEST; then
    echo "Adding audit policy volume mount..."
    sudo sed -i "/volumeMounts:/a\    - mountPath: $AUDIT_POLICY\n      name: audit\n      readOnly: true" $MANIFEST
fi

if ! grep -q "path: $AUDIT_LOG_DIR" $MANIFEST; then
    echo "Adding audit log volume mount..."
    sudo sed -i "/volumeMounts:/a\    - mountPath: $AUDIT_LOG_DIR\n      name: audit-log" $MANIFEST
fi

# Add volumes
if ! grep -q "name: audit$" $MANIFEST; then
    echo "Adding audit policy volume..."
    sudo sed -i "/volumes:/a\  - hostPath:\n      path: $AUDIT_POLICY\n      type: FileOrCreate\n    name: audit" $MANIFEST
fi

if ! grep -q "name: audit-log$" $MANIFEST; then
    echo "Adding audit log volume..."
    sudo sed -i "/volumes:/a\  - hostPath:\n      path: $AUDIT_LOG_DIR\n      type: DirectoryOrCreate\n    name: audit-log" $MANIFEST
fi

echo "✅ Audit logging configured"
echo "API server will auto-restart..."

sleep 30
kubectl get pods -n kube-system | grep apiserver