#### label-workers
#### Worker Node Labeling
#### Description
#### Labels worker nodes with node-role.kubernetes.io/worker= for node selection and scheduling.

#### Installation
#### bash
#### chmod +x label-workers.sh
#### ./label-workers.sh
#### Files
#### label-workers.sh - Labeling script

#### Verification
#### bash
#### kubectl get nodes -o wide
# Should show worker nodes with ROLE=worker
#### Test Commands
#### bash
# Check node labels
#### kubectl get nodes --show-labels

# Check specific node
#### kubectl describe node <node-name>

# Verify worker label
#### kubectl get nodes -l node-role.kubernetes.io/worker
