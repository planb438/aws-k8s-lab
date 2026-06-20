[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04%2B-lightgrey)](#)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-MicroK8s%20%7C%20kubeadm-blue)](#)
[![YouTube](https://img.shields.io/badge/YouTube-TechShorts-red)](https://www.youtube.com/@adaribain)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Adari%20Bain-blue)](https://www.linkedin.com/in/adari-bain-298924152/)


#### 🎯 This is the Master Blueprint

#### 📋 Complete Phase-by-Phase Implementation
#### Here's the master blueprint with all your scripts organized:

    yaml
    Phase 1  → Cloud Foundation        ✅ Terraform (DONE)
    Phase 2  → Kubernetes Foundation   ✅ kubeadm (DONE)
    Phase 3  → Cluster Hardening       ✅ Audit + Encryption (DONE)
    Phase 4  → Security Tools          ✅ kube-bench, Trivy, etc. (DONE)
    Phase 5  → Validate Hardening      ⏳ Run kube-bench (NEXT)
    Phase 6  → GitOps Layer            ⏳ Argo CD
    Phase 7  → Ingress + TLS           ✅ Nginx + Cert Manager (DONE)
    Phase 8  → Admission Control       ⏳ Kyverno + PSA
    Phase 9  → Network Security        ⏳ Default Deny Policies
    Phase 10 → Observability           ⏳ Prometheus + Grafana
    Phase 11 → Applications            ⏳ NextCloud, WordPress
    Phase 12 → Service Mesh            ⏳ Istio (optional)
#### 🚀 Phase 5: Validate Hardening (Run This Now)
    bash
    #!/bin/bash
# validate-hardening.sh
# Run this to verify all hardening is working

#### echo "========================================="
#### echo "🔐 Phase 5: Validating Cluster Hardening"
#### echo "========================================="

# 1. Run kube-bench
     echo ""
     echo "📊 Running kube-bench (CIS Benchmarks)..."
    mkdir -p results
    sudo kube-bench master --version 1.31 --json > results/kube-bench-$(date +%Y%m%d).json

# 2. Check audit logs
    echo ""
    echo "📊 Checking audit logs..."
    sudo ls -la /var/log/kubernetes/audit/ | head -5

# 3. Check encryption
    echo ""
    echo "📊 Checking encryption..."
    kubectl create secret tmp-test --from-literal=test=value --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
    sudo ETCDCTL_API=3 etcdctl get /registry/secrets/default/tmp-test 2>/dev/null | head -c 80
    kubectl delete secret tmp-test 2>/dev/null

# 4. Check API server flags
    echo ""
    echo "📊 API Server Security Flags:"
    ps aux | grep kube-apiserver | grep -E "(audit|encryption)" | grep -v grep

    echo ""
    echo "✅ Hardening validation complete!"
    echo "   Results saved to: results/kube-bench-$(date +%Y%m%d).json"
#### 📁 Master Setup Script
#### Here's the complete setup-cluster.sh that orchestrates everything:

    bash
    #!/bin/bash
    # Master Cluster Setup Script
    # Run this after Terraform apply

    set -e

    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'

    log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
    log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
    log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

    echo ""
    echo "========================================="
    echo "🚀 KUBERNETES CLUSTER SETUP"
    echo "========================================="
    echo ""

# ============================================
# PHASE 3: Cluster Hardening
# ============================================
    log_step "Phase 3: Cluster Hardening..."
    ./cluster-hardening-scripts/001-audit-policy/001-configure-audit-logging.sh
    ./cluster-hardening-scripts/002-encryption-at-rest/002-configure-encryption-provider.sh
    log_info "✅ Hardening complete"

# ============================================
# PHASE 4: Security Tools
# ============================================
    log_step "Phase 4: Installing Security Tools..."
    ./cluster-hardening-scripts/011-security-tools/combined/install-security-tools.sh
    log_info "✅ Security tools installed"

# ============================================
# PHASE 5: Validate Hardening
# ============================================
    log_step "Phase 5: Validating Hardening..."
    ./validate-hardening.sh
    log_info "✅ Validation complete"

# ============================================
# PHASE 7: Ingress + TLS
# ============================================
    log_step "Phase 7: Ingress + TLS..."
    ./cluster-hardening-scripts/008-deploying-cert-manager-nginx-ingress/install-ingress-certmanager.sh
    log_info "✅ Ingress + TLS complete"

# ============================================
# PHASE 8: Admission Control (Kyverno)
# ============================================
    log_step "Phase 8: Installing Admission Control..."
    ./cluster-hardening-scripts/012-kyverno-policies/install-kyverno.sh
    log_info "✅ Admission Control complete"

# ============================================
# PHASE 11: Applications
# ============================================
    log_step "Phase 11: Deploying Applications..."
    ./cluster-hardening-scripts/013-applications/deploy-nextcloud.sh
    log_info "✅ Applications deployed"

    echo ""
    echo "========================================="
    log_step "CLUSTER SETUP COMPLETE!"
    echo "========================================="
    echo ""
    echo "📝 Next Steps:"
    echo "   Phase 6: Install Argo CD"
    echo "   Phase 9: Apply Network Policies"
    echo "   Phase 10: Install Prometheus + Grafana"
    echo "   Phase 12: Istio (optional)"
    echo ""
    
  ---
  
  # 🏗️ Folder Structure for Scripts  
    
    
     text
    cluster-hardening-scripts/
    ├── 001-audit-policy/
    │   └── 001-configure-audit-logging.sh
    ├── 002-encryption-at-rest/
    │   └── 002-configure-encryption-provider.sh
    ├── 008-deploying-cert-manager-nginx-ingress/
    │   └── install-ingress-certmanager.sh
    ├── 011-security-tools/
    │   ├── combined/
    │   │   └── install-security-tools.sh
    │   └── sealed-secrets/
    │       └── sealed-secrets-002.sh
    ├── 012-kyverno-policies/
    │   ├── install-kyverno.sh
    │   ├── disallow-privileged.yaml
    │   └── require-namespace-labels.yaml
    ├── 013-applications/
    │   ├── deploy-nextcloud.sh
    │   └── deploy-wordpress.sh
    ├── 014-network-policies/
    │   ├── apply-default-deny.sh
    │   └── app-policies.yaml
    ├── 015-observability/
    │   └── install-prometheus-grafana.sh
    └── setup-cluster.sh

---

#### 📊 Phase Status Table
#### Phase	Component	Status
#### 1	Terraform AWS	✅ Complete
#### 2	Kubernetes Cluster	✅ Complete
#### 3	Cluster Hardening	✅ Complete
#### 4	Security Tools	✅ Complete
#### 5	Validate Hardening	⏳ Next
#### 6	GitOps (Argo CD)	⏳ Pending
#### 7	Ingress + TLS	✅ Complete
#### 8	Admission Control	⏳ Kyverno
#### 9	Network Security	⏳ Pending
#### 10	Observability	⏳ Pending
#### 11	Applications	⏳ NextCloud
#### 12	Service Mesh	⏳ Optional

---

#### 🎯 Next Steps
#### Phase 5: Run validate-hardening.sh to verify everything

#### Phase 8: Install Kyverno (your current task)

#### Phase 9: Apply default deny network policies

#### Phase 10: Install Prometheus + Grafana

#### Phase 11: Deploy NextCloud

---

#### 📝 Quick Commands for Your Phases
    bash
    # Phase 5: Validate hardening
    ./validate-hardening.sh

# Phase 8: Install Kyverno
    ./cluster-hardening-scripts/012-kyverno-policies/install-kyverno.sh

# Phase 9: Apply network policies
    ./cluster-hardening-scripts/014-network-policies/apply-default-deny.sh

# Phase 10: Install Observability
    ./cluster-hardening-scripts/015-observability/install-prometheus-grafana.sh

# Phase 11: Deploy NextCloud
    ./cluster-hardening-scripts/013-applications/deploy-nextcloud.sh
#### This is a production-grade, repeatable pattern that maps directly to CKS domains!🚀
