MicroK8s Cluster Setup Guide
---


Overview
This guide explains how to properly configure a MicroK8s Kubernetes cluster with dedicated control plane and worker nodes.

---

Current Node Status
bash
NAME      STATUS   ROLES    AGE     VERSION
cp        Ready    <none>   51m     v1.32.3
worker1   Ready    <none>   3m43s   v1.32.3
worker2   Ready    <none>   24s     v1.32.3


---

Step-by-Step Configuration


---

1. Set Up Control Plane Node
SSH into your control plane node (cp) and execute:

bash 

# Label the control plane node
microk8s kubectl label node cp node-role.kubernetes.io/control-plane=



# Taint the control plane to prevent user workloads
microk8s kubectl taint node cp node-role.kubernetes.io/control-plane:NoSchedule

---

2. Generate Join Command
On the control plane node, generate join tokens for worker nodes:

bash

microk8s add-node
This will output a join command like:

text

microk8s join 192.168.1.100:25000/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

---

3. Join Worker Nodes
SSH into each worker node and run the join command from step 2:

On worker1 and worker2:

bash

microk8s join <IP:PORT/TOKEN> # Use the actual command from above

---

4. Label Worker Nodes
Back on the control plane node, label the worker nodes:

bash

microk8s kubectl label node worker1 node-role.kubernetes.io/worker=
microk8s kubectl label node worker2 node-role.kubernetes.io/worker=

---

5. Verify Cluster Configuration
Check your node roles and status:

bash

microk8s kubectl get nodes -o wide
Expected output:

text
NAME      STATUS   ROLES            AGE     VERSION
cp        Ready    control-plane    51m     v1.32.3
worker1   Ready    worker           3m43s   v1.32.3
worker2   Ready    worker           24s     v1.32.3

---

6. Enable Essential Addons
On the control plane node, enable necessary MicroK8s addons:

bash

microk8s enable dns storage dashboard
Deployment Configuration Example
To ensure pods are scheduled correctly, use node selectors and tolerations:

yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: example-app
  template:
    metadata:
      labels:
        app: example-app
    spec:
      nodeSelector:
        node-role.kubernetes.io/worker: ""
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: app
        image: nginx:latest
        ports:
        - containerPort: 80

---

Maintenance Commands
Check Cluster Status
bash

microk8s status
View All Pods
bash

microk8s kubectl get pods -A -o wide
Drain a Node (for maintenance)
bash

microk8s kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
Uncordon a Node
bash

microk8s kubectl uncordon <node-name>
Troubleshooting
Common Issues
Nodes not joining: Ensure firewall allows traffic on port 25000

Pods pending: Check node resources and taints

DNS not working: Verify the dns addon is enabled

Check Node Details
bash

microk8s kubectl describe node <node-name>
Check Cluster Events
bash

microk8s kubectl get events -A

---


Notes
The control plane node will now only run system pods and critical services

Worker nodes will handle application workloads

Always cordon/drain nodes before maintenance

Regularly update MicroK8s with microk8s refresh

This configuration provides a proper Kubernetes cluster architecture with separated control plane and worker roles.
