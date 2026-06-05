#!/bin/bash
# Master Node Bootstrap Script - Optimized for t3.medium

set -e  # Exit on error
set -x  # Print commands for debugging

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get the private IP of the instance (works on AWS)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
log_info "Private IP: $PRIVATE_IP"

log_info "Step 1: Updating system packages..."
apt-get update -y
apt-get upgrade -y

log_info "Step 2: Disabling swap..."
swapoff -a
sed -i '/swap/d' /etc/fstab

log_info "Step 3: Loading kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

log_info "Step 4: Configuring sysctl for Kubernetes..."
cat <<EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

log_info "Step 5: Installing containerd..."
apt-get install -y apt-transport-https ca-certificates curl

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y containerd.io

# Configure containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

log_info "Step 6: Installing Kubernetes components..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet=1.31.1-1.1 kubeadm=1.31.1-1.1 kubectl=1.31.1-1.1
apt-mark hold kubelet kubeadm kubectl

log_info "Step 7: Initializing Kubernetes cluster..."
# Use private IP for API server
kubeadm init \
  --apiserver-advertise-address=$PRIVATE_IP \
  --pod-network-cidr=192.168.0.0/16 \
  --kubernetes-version=v1.31.1 \
  --service-cidr=10.96.0.0/12

log_info "Step 8: Configuring kubectl for the current user..."
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Also save for root
cp /etc/kubernetes/admin.conf /root/.kube/config 2>/dev/null || true

log_info "Step 9: Installing Calico network plugin..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/calico.yaml

log_info "Step 10: Waiting for control plane to be ready..."
sleep 30

log_info "Step 11: Removing taint from master node (allow scheduling workloads if desired)..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true

log_info "Step 12: Generating join command for worker nodes..."
kubeadm token create --print-join-command > /tmp/kubeadm_join_command
log_info "Join command saved to /tmp/kubeadm_join_command"

log_info "=== MASTER NODE BOOTSTRAP COMPLETE ==="
echo "---------------------------------------------------"
echo "To check cluster status:"
echo "  kubectl get nodes"
echo "  kubectl get pods -n kube-system"
echo ""
echo "Join command for workers:"
cat /tmp/kubeadm_join_command
echo "---------------------------------------------------"

# Create a summary file
cat > /tmp/bootstrap-summary.txt << EOF
Kubernetes Master Bootstrap Complete
Private IP: $PRIVATE_IP
Join command saved to: /tmp/kubeadm_join_command
Check cluster: kubectl get nodes
EOF