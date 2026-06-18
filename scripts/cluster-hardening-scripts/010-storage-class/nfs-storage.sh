#!/bin/bash
# Setup NFS Storage
# Run on MASTER node

set -e

echo "========================================="
echo "💾 Setting up NFS Storage"
echo "========================================="

# Get NFS server IP (default: first worker)
NFS_IP=$(kubectl get nodes -o wide | grep worker | head -1 | awk '{print $6}')
echo "NFS Server IP: $NFS_IP"

echo ""
echo "📌 On the NFS node, run:"
echo "    sudo apt-get update && sudo apt-get install nfs-kernel-server -y"
echo "    sudo mkdir -p /mnt/nfs"
echo "    sudo chown nobody:nogroup /mnt/nfs"
echo "    sudo chmod 777 /mnt/nfs"
echo "    echo '/mnt/nfs *(rw,sync,no_subtree_check,no_root_squash)' | sudo tee -a /etc/exports"
echo "    sudo exportfs -a"
echo "    sudo systemctl restart nfs-kernel-server"

read -p "Press Enter after NFS server is configured..."

# Install NFS client provisioner
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
helm repo update

helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=$NFS_IP \
  --set nfs.path=/mnt/nfs \
  --set storageClass.defaultClass=true \
  --set storageClass.name=nfs-storage

echo ""
echo "✅ NFS Storage configured!"
kubectl get storageclass
