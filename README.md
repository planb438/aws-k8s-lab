[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04%2B-lightgrey)](#)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-MicroK8s%20%7C%20kubeadm-blue)](#)
[![YouTube](https://img.shields.io/badge/YouTube-TechShorts-red)](https://www.youtube.com/@adaribain)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Adari%20Bain-blue)](https://www.linkedin.com/in/adari-bain-298924152/)


# AWS Kubernetes Lab - Production Ready Cluster

---


### 📋 Overview
This repository provisions a production-ready Kubernetes cluster on AWS using Terraform with CKS-level security controls pre-configured.

---

### What's Included
#### Component	Configuration
####  Infrastructure	AWS VPC, Subnet, Security Groups, EC2 (gp3 encrypted volumes)
####  Kubernetes	v1.31.1 with kubeadm, Calico CNI
####  Audit Logging	Full API audit with rotation (maxage=30, maxbackup=10, maxsize=100)
####  Encryption at Rest	AES-GCM encryption for secrets
### Security	IMDSv2 enforced, encrypted root volumes, CIS-compliant security groups
### Node Setup	1 Master + 2 Workers (configurable)
### State Management	S3 backend + automatic local recovery

---

### 🏗️ Architecture
---

### [1. Local Machine] ──(terraform apply)──> [2. AWS EC2 Instances]
###                                                   │
###                                           (Runs Master Bootstrap)
###                                                   │
### [3. Local Machine] <──(copy-join-command.sh)──────┴───> [4. Worker Nodes Joined]
                                                              │
### [5. Local Master Node] <──(Hardening Scripts)────────────────┘
#### Execution Flow
#### 
#### Terraform Apply
####     ↓
#### VPC + Networking (10.0.0.0/16)
####     ↓
#### Security Groups (SSH, API, HTTP/S, NodePorts)
####     ↓
#### Master Node (t3.medium, 30GB gp3 encrypted)
####     ↓
#### Worker Nodes (t3.medium ×2, 40GB gp3 encrypted)
####     ↓
#### Wait 45s for kubeadm init
####     ↓
#### Workers Join Cluster (auto-labeling)
####     ↓
#### Cluster Hardening (Audit + Encryption)
####    ↓
## ✅ Production-Ready Cluster
### 📁 Project Structure
text
### aws-k8s-lab/
### ├── main.tf                           # Terraform configuration
### ├── variables.tf                      # Input variables
### ├── outputs.tf                        # Output values
### ├── terraform.tfvars.example          # Variable examples
### ├── k8s-lab-key.pem                   # Auto-generated SSH key
### │
### ├── scripts/
### │   ├── terraform/
### │   │   ├── master-bootstrap.sh       # Control plane setup
### │   │   ├── worker-bootstrap.sh       # Worker node setup
### │   │   └── copy-join-command.sh      # Worker join automation
### │   │
### │   └── cluster-hardening-scripts/
### │       ├── 001-audit-policy/
### │       │   └── 001-configure-audit-logging.sh
### │       └── 002-encryption-at-rest/
### │           └── 002-configure-encryption-provider.sh
### │
### └── terraform-backups/                # Auto-created state backups

---

### 🚀 Quick Start
### Prerequisites
bash
####  Install Terraform (v1.0+)
# Configure AWS CLI
aws configure

####  Verify S3 bucket exists for state
aws s3 ls planb-backup-bucket
Deployment
bash
# 1. Clone and configure
git clone <your-repo>
cd aws-k8s-lab

####  2. Customize variables (optional)
cp terraform.tfvars.example terraform.tfvars
# Edit instance types, worker count, region

####  3. Initialize Terraform
terraform init

####  4. Review plan
terraform plan

####  5. Deploy cluster
terraform apply -auto-approve

# Output will show:
# - master_public_ip
# - worker_public_ips
# - kubeconfig command
Access the Cluster
bash
# SSH to master node
ssh -i k8s-lab-key.pem ubuntu@<master-public-ip>

####  Verify cluster nodes
kubectl get nodes -o wide

####  Expected output:
# NAME            STATUS   ROLES           AGE   VERSION
# ip-10-0-1-xxx   Ready    control-plane   5m    v1.31.1
# ip-10-0-1-xxx   Ready    <none>          4m    v1.31.1
# ip-10-0-1-xxx   Ready    <none>          4m    v1.31.1
#### 🔐 Security Features
#### 1. Audit Logging
bash
# Check audit logs
sudo cat /var/log/kubernetes/audit/audit.log | jq '.'

# Configuration:
# - Policy: Logs all Metadata level
# - Rotation: 30 days, 10 backups, 100MB max
# - Omitted stages: RequestReceived
#### 2. Encryption at Rest
bash
# Verify encryption
sudo ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/default/any-secret

# Encrypted output shows: k8s:enc:aesgcm:v1:key1:
3. IMDSv2 Enforcement
hcl
metadata_options {
  http_endpoint = "enabled"
  http_tokens   = "required"  # IMDSv2 only - prevents SSRF attacks
}
4. Encrypted Volumes
Master: 30GB gp3 encrypted

Workers: 40GB gp3 encrypted (each)

5. Security Groups
Port(s)	Purpose	Source
22	SSH	0.0.0.0/0
6443	Kubernetes API	0.0.0.0/0
80,443	HTTP/HTTPS	0.0.0.0/0
30000-32767	NodePort services	0.0.0.0/0
All	Internal cluster	Self (SG)
📊 Terraform State Management
Remote State (S3)
hcl
terraform {
  backend "s3" {
    bucket = "planb-backup-bucket"
    key    = "k8s-lab/terraform.tfstate"
    region = "us-east-1"
  }
}
Automatic Recovery
If local state is lost, Terraform automatically:

Checks S3 for remote state

Finds latest backup in terraform-backups/

Restores state before applying changes

Manual backup:

bash
cp terraform.tfstate terraform-backups/terraform.tfstate.$(date +%Y%m%d_%H%M%S)
🛠️ Variables
Variable	Description	Default
aws_region	AWS region	us-east-1
master_instance_type	Master node size	t3.medium
worker_instance_type	Worker node size	t3.medium
worker_count	Number of workers	2
Optional: Create terraform.tfvars
hcl
aws_region            = "us-east-1"
master_instance_type  = "t3.large"
worker_instance_type  = "t3.large"
worker_count          = 3
🔧 Troubleshooting
Workers Not Joining
bash
# Check join script logs
ssh -i k8s-lab-key.pem ubuntu@<master-ip>
kubectl get nodes

# Manually run join command
sudo kubeadm token create --print-join-command
Audit Logs Not Writing
bash
# Verify API server flags
ps aux | grep kube-apiserver | grep audit

# Check if file exists
sudo ls -la /var/log/kubernetes/audit/
Encryption Not Working
bash
# Check encryption flag
ps aux | grep kube-apiserver | grep encryption

# Verify config file exists
sudo cat /etc/kubernetes/encryption-config.yaml
Cluster Not Starting
bash
# Check kubelet status
sudo systemctl status kubelet

# Check container runtime
sudo crictl ps

# View API server logs
sudo crictl logs $(sudo crictl ps --name kube-apiserver -q)
🧹 Clean Up
bash
# Destroy all resources
terraform destroy -auto-approve

# Remove local files (optional)
rm -f k8s-lab-key.pem terraform.tfstate*
rm -rf terraform-backups/
📝 Verification Commands
bash
# After deployment, run these checks:

# 1. Cluster health
kubectl get nodes -o wide
kubectl get pods -n kube-system

# 2. Audit logging
sudo tail -5 /var/log/kubernetes/audit/audit.log | jq '.'

# 3. Encryption
kubectl create secret generic test --from-literal=foo=bar --dry-run=client -o yaml | kubectl apply -f -
sudo ETCDCTL_API=3 etcdctl get /registry/secrets/default/test | head -c 50
kubectl delete secret test

# 4. API server security flags
ps aux | grep kube-apiserver | grep -E '(audit|encryption)'

---

### 📚 Lessons Learned
---

### 1. Mounting Files vs Directories
### Audit policy: Mount as FileOrCreate (single file)
### 
### Encryption config: Mount as FileOrCreate (single file)
### 
### Log directories: Mount as DirectoryOrCreate
### 
### 2. Backup Files in Manifests Directory
### ❌ Never store .backup.* files in /etc/kubernetes/manifests/
### 
### ✅ Store backups in /etc/kubernetes/backups/manifests/
### 
### 3. SubPath Not Needed
### When mounting a single file, don't use subPath
### 
### mountPath: /path/to/file.yaml (full file path)
### 
### 4. Wait Conditions in Automation
### Always add sleep 45 before worker joins
### 
### Health-check loop after API server restarts
### 
### Retry logic for join commands

---
🎯 CKS Alignment
---

### CKS Domain	Implemented
### Cluster Setup	✅ CIS benchmarks, IMDSv2, encrypted volumes
### Cluster Hardening	✅ Audit logging, encryption at rest, RBAC
### System Hardening	✅ IMDSv2, security groups, least privilege
### Microservice Vulnerabilities	✅ Calico network policies, Pod Security
### Supply Chain Security	✅ SBOM tools, image scanning ready
### 📞 Support
### Issues: GitHub Issues
### 
### Contributions: Pull requests welcome
### 
### License: MIT
### 
### 🔗 Related Repositories
### Kubernetes Hardening Scripts
### 
### CKS Exam Preparation
### 
### NextCloud on Kubernetes
### 
### Built with ☁️ by Adari Bain | LinkedIn | YouTube


