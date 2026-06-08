[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04%2B-lightgrey)](#)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-MicroK8s%20%7C%20kubeadm-blue)](#)
[![YouTube](https://img.shields.io/badge/YouTube-TechShorts-red)](https://www.youtube.com/@adaribain)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Adari%20Bain-blue)](https://www.linkedin.com/in/adari-bain-298924152/)


Documentation for Your Production-Ready Cluster Config
Here's the working configuration:



---


1. Audit Policy File (/etc/kubernetes/audit-policy.yaml):
yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata

---


2. API Server Manifest Additions (/etc/kubernetes/manifests/kube-apiserver.yaml):
Command arguments:

yaml
- --audit-policy-file=/etc/kubernetes/audit-policy.yaml
- --audit-log-path=/var/log/kubernetes/audit/audit.log

Volume mounts:
---
yaml
volumeMounts:
- mountPath: /etc/kubernetes/audit-policy.yaml
  name: audit-policy
  readOnly: true
- mountPath: /var/log/kubernetes/audit/
  name: audit-log
  readOnly: false
Volumes:

yaml
volumes:
- name: audit-policy
  hostPath:
    path: /etc/kubernetes/audit-policy.yaml
    type: File
- name: audit-log
  hostPath:
    path: /var/log/kubernetes/audit/
    type: DirectoryOrCreate


---


3. Then restart kube-apiserver (may require updating static pod manifest at /etc/kubernetes/manifests/kube-apiserver.yaml).
   Let's force a restart of the API server by moving the manifest temporarily:

   sudo systemctl restart kubelet or:

bash
# Move manifest out
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/

# Wait 10 seconds
sleep 10

# Move it back
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/

# Wait for API server to start
sleep 30

# Check status
sudo crictl ps | grep apiserver
kubectl get pods -n kube-system | grep apiserver

---

Trigger Suspicious Events
For example:



kubectl auth can-i create clusterroles --as system:anonymous
kubectl get secrets --all-namespaces


Or apply a risky YAML like:
yaml



apiVersion: v1
kind: Pod
metadata:
  name: privileged
  namespace: dev
spec:
  containers:
  - name: shell
    image: busybox
    command: ["sleep", "3600"]
    securityContext:
      privileged: true


--
Analyze Logs
-
View audit logs on the control plane node:
bash



sudo cat /var/log/kubernetes/audit.log | less


Search for:
• create events for pods, secrets

• userAgent fields

• as or impersonatedUser


---

4. Verify Working:
bash
# Check audit logs are being written
sudo tail -f /var/log/kubernetes/audit/audit.log

# Generate some activity
kubectl get pods

# View recent audit events
sudo cat /var/log/kubernetes/audit/audit.log | jq '.verb, .user.username, .objectRef.resource' | head -20
 cluster is now production-ready with audit logging enabled! The logs show all API requests including successful and forbidden operations, which is essential for security compliance and troubleshooting.
