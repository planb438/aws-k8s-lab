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


3. Verify Working:
bash
# Check audit logs are being written
sudo tail -f /var/log/kubernetes/audit/audit.log

# Generate some activity
kubectl get pods

# View recent audit events
sudo cat /var/log/kubernetes/audit/audit.log | jq '.verb, .user.username, .objectRef.resource' | head -20
 cluster is now production-ready with audit logging enabled! The logs show all API requests including successful and forbidden operations, which is essential for security compliance and troubleshooting.
