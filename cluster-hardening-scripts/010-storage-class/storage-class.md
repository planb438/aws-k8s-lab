[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04%2B-lightgrey)](#)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-MicroK8s%20%7C%20kubeadm-blue)](#)
[![YouTube](https://img.shields.io/badge/YouTube-TechShorts-red)](https://www.youtube.com/@adaribain)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Adari%20Bain-blue)](https://www.linkedin.com/in/adari-bain-298924152/)


Since the cluster has no StorageClass defined, we need to set up storage before deploying Nextcloud (or any stateful application). Here's how to configure a local storage provider :

---

Option 1: Local Path Provisioner (Simplest for Home Lab)
This creates PersistentVolumes using disk space on your worker nodes.


---

1. Install Local Path Provisioner:
bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

---

2. Set as Default StorageClass:
bash
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

---

3. Verify:
bash
kubectl get storageclass
Output should show:

text
NAME                   PROVISIONER             AGE
local-path (default)   rancher.io/local-path   30s

---

Option 2: NFS Server (If You Want Shared Storage)
Better for multi-node clusters where pods might reschedule.

---

1. Install NFS Server on a Node:
On one of your worker nodes (SSH into it):

bash
sudo apt-get update && sudo apt-get install nfs-kernel-server -y
sudo mkdir -p /mnt/nfs
sudo chown nobody:nogroup /mnt/nfs
sudo chmod 777 /mnt/nfs
echo "/mnt/nfs *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
sudo exportfs -a
sudo systemctl restart nfs-kernel-server

---

2. Install NFS Client Provisioner:
bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=<NFS-SERVER-NODE-IP> \
  --set nfs.path=/mnt/nfs \
  --set storageClass.defaultClass=true
Verify Storage is Ready
Before installing Nextcloud, confirm:

bash
kubectl get storageclass
kubectl get pods -n default -l app.kubernetes.io/name=nfs-subdir-external-provisioner  # For NFS option