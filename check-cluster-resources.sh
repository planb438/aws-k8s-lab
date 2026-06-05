#!/bin/bash
# Check cluster resource usage

echo "=== Node Resource Usage ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory

echo -e "\n=== Pod Resource Usage ==="
kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null || echo "Metrics server not installed yet"

echo -e "\n=== Node Conditions ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,READY:.status.conditions[-1].type,STATUS:.status.conditions[-1].status

echo -e "\n=== Disk Usage on Nodes ==="
for node in $(kubectl get nodes -o name | cut -d/ -f2); do
  echo "Node: $node"
  kubectl exec -n kube-system $(kubectl get pods -n kube-system -l k8s-app=kube-dns -o name | head -1) -- df -h 2>/dev/null | grep "/$" || echo "  Cannot get disk usage"
done