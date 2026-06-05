[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04%2B-lightgrey)](#)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-MicroK8s%20%7C%20kubeadm-blue)](#)
[![YouTube](https://img.shields.io/badge/YouTube-TechShorts-red)](https://www.youtube.com/@adaribain)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Adari%20Bain-blue)](https://www.linkedin.com/in/adari-bain-298924152/)


# aws-k8s-lab

markdown
# 🚀 AWS K8s Lab - Self-Hosted Kubernetes Cluster on EC2

## 📋 Overview

A production-ready Terraform module to deploy a **self-hosted Kubernetes cluster** on AWS EC2 for homelab experimentation, development, and testing. This setup provides a complete Kubernetes environment with security hardening, resource optimization, and state backup capabilities.

### 🎯 Perfect For
- **Homelab experiments** with Kubernetes
- **Development environments** that need a real K8s cluster
- **Testing CKS-level security controls** (PodSecurity, Network Policies, etc.)
- **GitOps practice** with Argo CD
- **Crime analytics platform** (RBDF project) and similar data-intensive apps

### ✨ Features

| Feature | Description |
|---------|-------------|
| **High Availability** | 1 Master + 2 Worker nodes (configurable) |
| **Security Hardened** | IMDSv2 required, encrypted volumes, restricted security groups |
| **Resource Optimized** | t3.medium instances, 30-40GB gp3 volumes |
| **State Management** | S3 backend with versioning + local backups |
| **CNI Ready** | Calico network plugin (192.168.0.0/16) |
| **Container Runtime** | containerd with systemd cgroup driver |
| **K8s Version** | v1.31.1 (latest stable) |

## 📁 Project Structure
aws-k8s-lab/
├── main.tf # Main Terraform configuration
├── variables.tf # Input variables
├── outputs.tf # Output values
├── master-bootstrap.sh # Master node initialization script
├── worker-bootstrap.sh # Worker node preparation script
├── copy-join-command.sh # Join command distribution script
├── check-cluster-resources.sh # Cluster health check
├── terraform-backups/ # Local state backups (auto-created)
└── README.md # This file

text

## 🛠️ Prerequisites

### Local Machine Requirements
- **Terraform** >= 1.0
- **AWS CLI** configured with appropriate credentials
- **kubectl** >= 1.31
- **ssh** client
- **bash** (for helper scripts)

### AWS Requirements
- AWS account with permissions to create:
  - EC2 instances (t3.medium or similar)
  - VPC, Subnet, Internet Gateway
  - Security Groups
  - S3 bucket (for state - created separately)
- **S3 bucket** named `planb-backup-bucket` with versioning enabled

## 🚀 Quick Start

### 1. Clone & Configure

```bash
git clone <your-repo-url>
cd aws-k8s-lab

# Optional: Override default variables
cat >> terraform.tfvars << 'EOF'
master_instance_type = "t3.medium"
worker_instance_type = "t3.medium"
worker_count         = 2
aws_region          = "us-east-1"
EOF
2. Deploy Infrastructure
bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy the cluster
terraform apply -auto-approve
This creates:

1 master node + N worker nodes (default: 2)

VPC with public subnet

Internet Gateway & Route Table

Security groups (SSH, K8s API, HTTP/S, NodePorts)

3. Get Instance IPs
bash
# Get all instance IPs
terraform output

# Or individually
MASTER_IP=$(terraform output -raw master_public_ip)
WORKER1_IP=$(terraform output -json worker_public_ips | jq -r '.[0]')
WORKER2_IP=$(terraform output -json worker_public_ips | jq -r '.[1]')

echo "Master: $MASTER_IP"
echo "Workers: $WORKER1_IP, $WORKER2_IP"
4. Join Workers to Cluster
Run from your LOCAL machine (not from AWS):

bash
# Make script executable
chmod +x copy-join-command.sh

# Run with master and worker public IPs
./copy-join-command.sh $MASTER_IP $WORKER1_IP $WORKER2_IP
The script will:

SSH to master → Generate join token

Copy join command to each worker

Execute join on each worker

5. Configure kubectl
Run on your LOCAL machine (after workers have joined):

bash
# Copy kubeconfig from master
ssh -i k8s-lab-key.pem ubuntu@$MASTER_IP "sudo cat /etc/kubernetes/admin.conf" > kubeconfig.yaml

# Or use terraform output
terraform output -raw kubeconfig_command | bash

# Set as default kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Verify cluster is ready
kubectl get nodes
kubectl get pods -n kube-system
Expected output:

text
NAME           STATUS   ROLES           AGE   VERSION
ip-10-0-1-100  Ready    control-plane   5m    v1.31.1
ip-10-0-1-101  Ready    <none>          2m    v1.31.1
ip-10-0-1-102  Ready    <none>          2m    v1.31.1
📊 Resource Specifications
Component	Instance Type	vCPU	RAM	Root Disk	Use Case
Master	t3.medium	2	4 GB	30 GB gp3	Control plane, etcd
Worker	t3.medium	2	4 GB	40 GB gp3	Workloads, containers
Cost Estimate (us-east-1): ~$0.0416/hr per instance → ~$90/month for 3 nodes

Reducing Costs
hcl
# Use smaller instances for testing
master_instance_type = "t3.small"
worker_instance_type = "t3.small"
worker_count         = 1
🔐 Security Features
Control	Implementation
IMDSv2	Required for all EC2 instances
SSH Access	Key-based only (no password)
Volume Encryption	gp3 volumes encrypted at rest
Network Isolation	VPC with no public ingress except required ports
Security Groups	Least-privilege rules
State Encryption	S3 state encrypted with AES256
Open Ports
Port	Purpose
22	SSH
6443	Kubernetes API
80/443	Ingress (applications)
30000-32767	NodePort services
🛠️ Management Scripts
check-cluster-resources.sh
Check cluster health and resource usage:

bash
./check-cluster-resources.sh
copy-join-command.sh
Distribute join command to workers (run locally):

bash
# Must be run from LOCAL machine with SSH access
./copy-join-command.sh <master-ip> <worker-ip1> <worker-ip2>
SSH into Nodes
bash
# Connect to master
ssh -i k8s-lab-key.pem ubuntu@$(terraform output -raw master_public_ip)

# Connect to worker 1
ssh -i k8s-lab-key.pem ubuntu@$(terraform output -json worker_public_ips | jq -r '.[0]')
💾 State Management & Backup
S3 Backend
State is stored in S3 bucket: planb-backup-bucket

Versioning enabled - All changes preserved

Encrypted at rest - AES256

Private bucket - No public access

Creating the S3 Bucket (One-time setup)
bash
aws s3api create-bucket --bucket planb-backup-bucket --region us-east-1
aws s3api put-bucket-versioning --bucket planb-backup-bucket --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket planb-backup-bucket --server-side-encryption-configuration '{
  "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
}'
View State History
bash
# List all state versions
aws s3api list-object-versions --bucket planb-backup-bucket --prefix k8s-lab/terraform.tfstate

# Download specific version
aws s3api get-object --bucket planb-backup-bucket --key k8s-lab/terraform.tfstate --version-id <VERSION_ID> terraform.tfstate
🧹 Destroying the Cluster
bash
# Destroy all AWS resources
terraform destroy -auto-approve

# Note: S3 bucket and tfstate are preserved!
To also delete the S3 bucket (optional):

bash
aws s3 rm s3://planb-backup-bucket --recursive
aws s3api delete-bucket --bucket planb-backup-bucket
🔄 Deploying Applications
Example: Deploy PostgreSQL (like your crime analytics DB)
bash
# Create namespace
kubectl create namespace postgres

# Deploy PostgreSQL
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: postgres
stringData:
  POSTGRES_PASSWORD: mypassword
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        envFrom:
        - secretRef:
            name: postgres-secret
        ports:
        - containerPort: 5432
EOF
🐛 Troubleshooting
Workers Not Joining
bash
# Check worker kubelet status
ssh -i k8s-lab-key.pem ubuntu@$WORKER_IP "sudo systemctl status kubelet"

# Check join command validity
ssh -i k8s-lab-key.pem ubuntu@$MASTER_IP "sudo kubeadm token list"
kubectl Not Working
bash
# Re-copy kubeconfig from master (run after join is complete)
ssh -i k8s-lab-key.pem ubuntu@$MASTER_IP "sudo cat /etc/kubernetes/admin.conf" > kubeconfig.yaml
export KUBECONFIG=$(pwd)/kubeconfig.yaml
Pods Stuck in Pending
bash
# Check if Calico is running
kubectl get pods -n kube-system | grep calico

# Check node taints
kubectl describe nodes | grep Taints
Node Resource Issues
bash
# Check node capacity
kubectl describe nodes | grep -A 5 "Capacity"

# Check disk pressure
kubectl get nodes -o custom-columns=NAME:.metadata.name,DISK:.status.conditions[-1].message
📈 Customization
Change Instance Sizes
Create terraform.tfvars:

hcl
master_instance_type = "t3.large"  # 2 vCPU, 8 GB RAM
worker_instance_type = "t3.xlarge" # 4 vCPU, 16 GB RAM
worker_count         = 3
Change K8s Version
Edit master-bootstrap.sh and worker-bootstrap.sh:

bash
# Change version numbers
kubeadm=1.32.0-1.1
kubelet=1.32.0-1.1
kubectl=1.32.0-1.1
Add More Worker Nodes
bash
# Update variable and reapply
export TF_VAR_worker_count=4
terraform apply
📝 Important Notes
⚠️ copy-join-command.sh:

Must be run from your LOCAL machine (not from AWS)

Requires SSH access to all instances using k8s-lab-key.pem

Uses public IPs of EC2 instances

⚠️ kubectl Configuration:

Must be run AFTER workers have joined the cluster

The kubeconfig file expires - regenerate if you see auth errors

⚠️ Bootstrap Sequence:

Terraform creates instances

Master runs master-bootstrap.sh (kubeadm init + Calico)

You run copy-join-command.sh locally

Workers join the cluster

You configure kubectl locally

🎓 Learning Resources
Kubernetes Security (CKS)

Calico Network Policy

AWS IMDSv2

📄 License
MIT License - Use freely for homelab and learning

👤 Author
Adari Bain - CKS Certified Kubernetes Security Specialist

GitHub

LinkedIn

Built for homelab experimentation and production-ready Kubernetes deployments 🚀

text

## **Next Steps**

1. **Save this as `README.md`** in your repository root
2. **Add a `.gitignore`** to exclude sensitive files:
```gitignore
# Terraform
*.tfstate
*.tfstate.*
.terraform/
terraform.tfstate.backup
terraform-backups/

# SSH keys
*.pem
*.key

# Kubeconfig
kubeconfig.yaml
kubeconfig
Commit and push to your GitHub repository:

bash
git add .
git commit -m "Initial commit: AWS K8s Lab Terraform deployment"
git push origin main
