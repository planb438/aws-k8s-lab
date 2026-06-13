#!/bin/bash
# Worker Node Bootstrap Script - Optimized for t3.medium

set -e  # Exit on error
set -x  # Print commands for debugging

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

log_info "Step 1: Updating system packages..."
apt-get update -y

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
apt-get install -y kubelet=1.31.1-1.1 kubeadm=1.31.1-1.1
apt-mark hold kubelet kubeadm

log_info "Step 7: Waiting for join command file..."
JOIN_FILE="/tmp/kubeadm_join_command"
MAX_WAIT=300  # 5 minutes
WAIT_TIME=0

while [ ! -f "$JOIN_FILE" ] && [ $WAIT_TIME -lt $MAX_WAIT ]; do
  log_info "Waiting for join command from master... ($WAIT_TIME/$MAX_WAIT seconds)"
  sleep 10
  WAIT_TIME=$((WAIT_TIME + 10))
done

if [ -f "$JOIN_FILE" ]; then
  log_info "Join command found! Joining cluster..."
  bash "$JOIN_FILE"
  systemctl restart kubelet
  log_info "Worker successfully joined the cluster!"
else
  log_warn "Join command file not found at $JOIN_FILE"
  log_warn "Please run the join command manually after cluster is ready"
  log_warn "Get the join command from master: kubeadm token create --print-join-command"
fi

log_info "=== WORKER NODE BOOTSTRAP COMPLETE ==="