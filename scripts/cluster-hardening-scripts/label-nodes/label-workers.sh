#!/bin/bash
# Label worker nodes
# Run on MASTER node

set -e

echo "========================================="
echo "🏷️ Labeling Worker Nodes"
echo "========================================="

# Get control plane node
CONTROL_PLANE=$(kubectl get nodes -o name | grep control-plane | head -1 | cut -d'/' -f2)

echo "Control Plane: $CONTROL_PLANE"

# Label all non-control-plane nodes as workers
echo ""
echo "Labeling worker nodes..."
kubectl get nodes -o name | grep -v $CONTROL_PLANE | cut -d'/' -f2 | while read node; do
    echo "  Labeling: $node"
    kubectl label node $node node-role.kubernetes.io/worker= --overwrite 2>/dev/null || true
done

# Remove worker label from control-plane (if it got labeled)
kubectl label node $CONTROL_PLANE node-role.kubernetes.io/worker- 2>/dev/null || true

echo ""
echo "✅ Node labels applied:"
kubectl get nodes -o wide
