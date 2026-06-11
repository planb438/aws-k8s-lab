#!/bin/bash
# Copy join command from master to workers
# Runs with sudo on workers

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

log_info "Waiting for all nodes to be ready..."
sleep 30

MASTER_IP="$1"
shift
WORKER_IPS=("$@")

if [ -z "$MASTER_IP" ] || [ ${#WORKER_IPS[@]} -eq 0 ]; then
  echo "Usage: $0 <master-ip> <worker-ip1> <worker-ip2> ..."
  echo "Example: $0 10.0.1.100 10.0.1.101 10.0.1.102"
  echo ""
  echo "First get your IPs from terraform output:"
  echo "  terraform output -raw master_public_ip"
  echo "  terraform output -json worker_public_ips | jq -r '.[]'"
  exit 1
fi

echo "Getting join command from master $MASTER_IP..."
ssh -i k8s-lab-key.pem ubuntu@$MASTER_IP "sudo kubeadm token create --print-join-command" > /tmp/kubeadm_join_command

if [ ! -s /tmp/kubeadm_join_command ]; then
  echo "ERROR: Failed to get join command from master"
  exit 1
fi

echo "Join command: $(cat /tmp/kubeadm_join_command)"
echo ""

for WORKER_IP in "${WORKER_IPS[@]}"; do
  echo "Processing worker $WORKER_IP..."
  
  # Copy join command to worker
  scp -i k8s-lab-key.pem /tmp/kubeadm_join_command ubuntu@$WORKER_IP:/tmp/kubeadm_join_command
  
  # Execute join with sudo on worker
  echo "Executing kubeadm join on worker $WORKER_IP..."
  ssh -i k8s-lab-key.pem ubuntu@$WORKER_IP "sudo bash /tmp/kubeadm_join_command"
  
  if [ $? -eq 0 ]; then
    echo "✅ Worker $WORKER_IP joined successfully!"
    
    # Restart kubelet
    ssh -i k8s-lab-key.pem ubuntu@$WORKER_IP "sudo systemctl restart kubelet"
  else
    echo "❌ Worker $WORKER_IP failed to join"
  fi
  echo ""
done

echo "All workers processed!"
echo ""
echo "Verify cluster status from master:"
echo "  ssh -i k8s-lab-key.pem ubuntu@$MASTER_IP 'kubectl get nodes'"
