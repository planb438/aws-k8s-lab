#!/bin/bash
# Copy join command from master to workers

MASTER_IP=$1
WORKER_IPS=(${@:2})

if [ -z "$MASTER_IP" ] || [ ${#WORKER_IPS[@]} -eq 0 ]; then
  echo "Usage: $0 <master-ip> <worker-ip1> <worker-ip2> ..."
  echo "Example: $0 10.0.1.100 10.0.1.101 10.0.1.102"
  exit 1
fi

echo "Getting join command from master..."
ssh -i k8s-lab-key.pem ubuntu@$MASTER_IP "kubeadm token create --print-join-command" > /tmp/kubeadm_join_command

for WORKER_IP in "${WORKER_IPS[@]}"; do
  echo "Copying join command to worker $WORKER_IP..."
  scp -i k8s-lab-key.pem /tmp/kubeadm_join_command ubuntu@$WORKER_IP:/tmp/kubeadm_join_command
  
  echo "Executing join on worker $WORKER_IP..."
  ssh -i k8s-lab-key.pem ubuntu@$WORKER_IP "bash /tmp/kubeadm_join_command && systemctl restart kubelet"
done

echo "All workers joined the cluster!"