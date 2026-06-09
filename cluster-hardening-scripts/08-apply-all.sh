#!/bin/bash
# Apply all hardening scripts in correct order
# Run on MASTER node, then run worker script on workers

set -e

echo "========================================="
echo "🔐 Applying All Cluster Hardening Scripts"
echo "========================================="

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run master scripts
echo ""
echo "Running master node hardening..."
echo "--------------------------------"

for script in 01-fix-etcd-ownership.sh 02-disable-insecure-port.sh 03-add-kubelet-ca.sh 05-configure-audit-logging.sh 06-configure-encryption-provider.sh 07-configure-security-flags.sh; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        echo ""
        echo ">>> Running $script..."
        bash "$SCRIPT_DIR/$script"
    else
        echo "⚠️ Script not found: $script"
    fi
done

echo ""
echo "========================================="
echo "✅ Master node hardening complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Run on each WORKER node:"
echo "   ./04-fix-protect-kernel-defaults.sh"
echo ""
echo "2. Verify with kube-bench"
echo ""