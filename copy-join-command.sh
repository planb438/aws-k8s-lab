#!/bin/bash
# Copy join command from master to workers

set -e

MASTER_IP="$1"
shift
WORKER_IPS=("$@")

if [ -z "$MASTER_IP" ] || [ ${#WORKER_IPS[@]} -eq 0 ]; then
  echo "Usage: $0 <master-ip> <worker-ip1> <worker-ip2> ..."
  echo "Example: $0 10.0.1.100 10.0.1.101 10.0.1.102"
  exit 1
fi

echo "Getting join command from master $MASTER_IP..."
ssh -i k8s-lab-key.pem ubuntu@$MASTER_IP "sudo kubeadm token create --print-join-command" > /tmp/kubeadm_join_command

if [ ! -s /tmp/kubeadm_join_command ]; then
  echo "ERROR: Failed to get join command"
  exit 1
fi

echo "Join command: $(cat /tmp/kubeadm_join_command)"
echo ""

for WORKER_IP in "${WORKER_IPS[@]}"; do
  echo "Processing worker $WORKER_IP..."
  
  # Clean previous Kubernetes installation
  ssh -i k8s-lab-key.pem ubuntu@$WORKER_IP "sudo kubeadm reset -f" 2>/dev/null || true
  
  # Copy join command
  scp -i k8s-lab-key.pem /tmp/kubeadm_join_command ubuntu@$WORKER_IP:/tmp/kubeadm_join_command
  
  # Execute join
  ssh -i k8s-lab-key.pem ubuntu@$WORKER_IP "sudo bash /tmp/kubeadm_join_command && sudo systemctl restart kubelet"
  
  echo "✅ Worker $WORKER_IP processed"
  echo ""
done

echo "Waiting 30 seconds for nodes to register..."
sleep 30

echo "Final cluster status:"
ssh -i k8s-lab-key.pem ubuntu@$MASTER_IP "kubectl get nodes"

echo ""
echo "✅ All workers joined!"
