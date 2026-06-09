README.md
markdown
# Cluster Hardening Scripts - Kubernetes Security Hardening

## Overview

A comprehensive suite of scripts to harden a Kubernetes cluster against CIS benchmarks and CKS requirements. Each script is decoupled for easy debugging and selective application.

## Scripts Overview

| Script | Purpose | Target | Priority |
|--------|---------|--------|----------|
| `01-fix-etcd-ownership.sh` | Fix etcd data directory ownership (1.1.12) | Master | HIGH |
| `02-disable-insecure-port.sh` | Disable API server insecure port (1.2.19) | Master | HIGH |
| `03-add-kubelet-ca.sh` | Configure kubelet certificate authority (1.2.6) | Master | HIGH |
| `04-fix-protect-kernel-defaults.sh` | Enable kernel defaults protection (4.2.6) | Worker | MEDIUM |
| `05-configure-audit-logging.sh` | Configure API server audit logging | Master | MEDIUM |
| `06-configure-encryption-provider.sh` | Configure encryption at rest | Master | HIGH |
| `07-configure-security-flags.sh` | Set security flags (anonymous-auth, profiling, admission) | Master | HIGH |
| `08-apply-all.sh` | Run all master scripts in order | Master | - |

## Quick Start

### 1. Clone or copy scripts to master node

```bash
git clone <repo-url> cluster-hardening-scripts
cd cluster-hardening-scripts
chmod +x *.sh
2. Run all master hardening scripts
bash
./08-apply-all.sh
3. Run worker hardening on each worker node
bash
./04-fix-protect-kernel-defaults.sh
4. Verify with kube-bench
bash
./kube-bench --config-dir ./cfg --config ./cfg/config.yaml
Individual Script Usage
Run a specific script
bash
# Fix etcd ownership only
./01-fix-etcd-ownership.sh

# Configure audit logging only
./05-configure-audit-logging.sh
Debug mode (run with bash -x)
bash
bash -x 01-fix-etcd-ownership.sh
Security Controls Applied
Control	CIS Check	Description
etcd ownership	1.1.12	etcd data owned by etcd:etcd
Insecure port	1.2.19	--insecure-port=0
Kubelet CA	1.2.6	--kubelet-certificate-authority
Protect kernel defaults	4.2.6	protectKernelDefaults: true
Anonymous auth	N/A	--anonymous-auth=false
Profiling	N/A	--profiling=false
Admission plugins	N/A	NodeRestriction, AlwaysPullImages
Audit logging	N/A	Full audit policy configured
Encryption at rest	N/A	AES-GCM encryption for secrets
Directory Structure
text
cluster-hardening-scripts/
├── README.md                           # This file
├── 01-fix-etcd-ownership.sh            # Fix etcd directory ownership
├── 02-disable-insecure-port.sh         # Disable API server insecure port
├── 03-add-kubelet-ca.sh                # Add kubelet certificate authority
├── 04-fix-protect-kernel-defaults.sh   # Enable kernel defaults (worker)
├── 05-configure-audit-logging.sh       # Configure audit logging
├── 06-configure-encryption-provider.sh # Configure encryption at rest
├── 07-configure-security-flags.sh      # Set concrete security flags
├── 08-apply-all.sh                     # Apply all master scripts
└── templates/                          # Template files
    ├── audit-policy.yaml               # Audit policy template
    └── encryption-config.yaml          # Encryption config template
Verification Commands
bash
# Check etcd ownership
ls -la /var/lib/etcd

# Check API server flags
ps -ef | grep kube-apiserver | grep -E "insecure-port|anonymous-auth|profiling"

# Check kubelet config
cat /var/lib/kubelet/config.yaml | grep protectKernelDefaults

# Check audit policy
cat /etc/kubernetes/audit-policy.yaml

# Check encryption config
cat /etc/kubernetes/encryption/encryption-config.yaml

# Check all secrets are encrypted
sudo ETCDCTL_API=3 etcdctl get /registry/secrets --prefix --keys-only | head -10
Troubleshooting
API server not restarting
bash
# Check API server logs
sudo crictl logs $(sudo crictl ps --name kube-apiserver -q)

# Check manifest syntax
cat /etc/kubernetes/manifests/kube-apiserver.yaml
kubelet not restarting
bash
# Check kubelet status
sudo systemctl status kubelet

# Check kubelet logs
sudo journalctl -u kubelet -n 50
References
CIS Kubernetes Benchmark

CKS Curriculum

Kubernetes Security Best Practices

Author
Adari Bain - CKS Certified Kubernetes Security Specialist

text

---

## Make All Scripts Executable

```bash
chmod +x 01-fix-etcd-ownership.sh 02-disable-insecure-port.sh 03-add-kubelet-ca.sh
chmod +x 04-fix-protect-kernel-defaults.sh 05-configure-audit-logging.sh
chmod +x 06-configure-encryption-provider.sh 07-configure-security-flags.sh
chmod +x 08-apply-all.sh
This suite gives you complete control over each hardening step with proper error handling and verification at each stage.

---

View Audit Logs Properly
bash
# View real-time audit logs (formatted for readability)
sudo tail -f /var/log/kubernetes/audit/audit.log | jq '.'

# View last 10 audit entries in pretty format
sudo tail -10 /var/log/kubernetes/audit/audit.log | jq '.'

# Count audit entries by verb
sudo cat /var/log/kubernetes/audit/audit.log | jq -r '.verb' | sort | uniq -c

# Find failed authentication attempts
sudo cat /var/log/kubernetes/audit/audit.log | jq 'select(.responseStatus.code >= 400)'
