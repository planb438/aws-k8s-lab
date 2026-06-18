#!/bin/bash
# Setup Local Path Provisioner for Storage
# Run on MASTER node

set -e

echo "========================================="
echo "💾 Setting up Local Path Storage"
echo "========================================="

# Install Local Path Provisioner
echo ""
echo "Installing Local Path Provisioner..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

# Wait for provisioner
echo ""
echo "Waiting for provisioner..."
kubectl wait --for=condition=ready pod -l app=local-path-provisioner -n local-path-storage --timeout=60s

# Set as default StorageClass
echo ""
echo "Setting as default StorageClass..."
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Verify
echo ""
echo "✅ StorageClass created:"
kubectl get storageclass

echo ""
echo "💾 Local Path Provisioner ready!"
