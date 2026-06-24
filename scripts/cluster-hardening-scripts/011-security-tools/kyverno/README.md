[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04%2B-lightgrey)](#)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-MicroK8s%20%7C%20kubeadm-blue)](#)
[![YouTube](https://img.shields.io/badge/YouTube-TechShorts-red)](https://www.youtube.com/@adaribain)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Adari%20Bain-blue)](https://www.linkedin.com/in/adari-bain-298924152/)

# 🎯 Deploy Kyverno via Argo CD (GitOps Approach)
#### - now that Argo CD is your GitOps engine, everything should be deployed through it, including Kyverno, Cert Manager, Ingress, and all policies.

#### 📁 Step 1: Create Kyverno Manifests in Your Git Repo
#### bash
# Clone your repo (if not already)
    cd /tmp
    git clone https://github.com/planb438/Argo-CD.git
    cd Argo-CD

# Create kyverno directory
    mkdir -p apps/kyverno
    cd apps/kyverno
#### 1.1 Create Kyverno Installation (Helm Release via Argo CD)
#### Create 00-kyverno-helm.yaml:

#### bash
    cat > 00-kyverno-helm.yaml << 'EOF'
    apiVersion: v1
    kind: Namespace
    metadata:
      name: kyverno
    ---
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: kyverno
      namespace: argocd
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      source:
        repoURL: https://kyverno.github.io/kyverno/
        targetRevision: latest
        chart: kyverno
        helm:
          values: |
            replicaCount: 2
            admissionController:
              replicaCount: 2
            backgroundController:
              enabled: true
            cleanupController:
              enabled: true
            reportsController:
              enabled: true
      destination:
        server: https://kubernetes.default.svc
        namespace: kyverno
      syncPolicy:
        automated:
          selfHeal: true
          prune: true
        syncOptions:
          - CreateNamespace=true
    EOF
#### 1.2 Create Kyverno Policies
#### Create 01-disallow-privileged.yaml:

#### bash
    cat > 01-disallow-privileged.yaml << 'EOF'
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: disallow-privileged
      annotations:
        policies.kyverno.io/title: Disallow Privileged Containers
        policies.kyverno.io/severity: medium
        policies.kyverno.io/subject: Pod
    spec:
      validationFailureAction: Enforce
      background: true
      rules:
      - name: check-privileged
        match:
          resources:
            kinds:
            - Pod
        validate:
          message: "Privileged containers are not allowed!"
          pattern:
            spec:
              containers:
              - securityContext:
                  privileged: "false"
    EOF
#### Create 02-require-labels.yaml:

#### bash
    cat > 02-require-labels.yaml << 'EOF'
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: require-namespace-labels
      annotations:
        policies.kyverno.io/title: Require Namespace Labels
        policies.kyverno.io/severity: low
    spec:
      validationFailureAction: Enforce
      rules:
      - name: require-labels
        match:
          resources:
            kinds:
            - Namespace
        validate:
          message: "All namespaces must have an 'owner' label."
          pattern:
            metadata:
              labels:
                owner: "?*"
    EOF
#### Create 03-disallow-latest-tag.yaml:

#### bash
    cat > 03-disallow-latest-tag.yaml << 'EOF'
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: disallow-latest-tag
      annotations:
        policies.kyverno.io/title: Disallow Latest Image Tag
        policies.kyverno.io/severity: medium
    spec:
      validationFailureAction: Enforce
      background: true
      rules:
      - name: require-image-tag
        match:
          resources:
            kinds:
            - Pod
        validate:
          message: "Using 'latest' image tag is not allowed. Use a specific version."
          pattern:
            spec:
              containers:
              - image: "*:*"
              - image: "!*:latest"
    EOF
#### Create 04-require-readonly-rootfs.yaml:

#### bash
    cat > 04-require-readonly-rootfs.yaml << 'EOF'
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: require-readonly-rootfs
      annotations:
        policies.kyverno.io/title: Require Read-Only Root Filesystem
        policies.kyverno.io/severity: medium
    spec:
      validationFailureAction: Enforce
      background: true
      rules:
      - name: check-rootfs
        match:
          resources:
            kinds:
            - Pod
        validate:
          message: "Containers must have read-only root filesystem."
          pattern:
            spec:
              containers:
              - securityContext:
                  readOnlyRootFilesystem: true
    EOF
#### 1.3 Create Test Pods (Optional)
#### Create 05-test-pods.yaml:

#### bash
    cat > 05-test-pods.yaml << 'EOF'
    apiVersion: v1
    kind: Namespace
    metadata:
      name: policy-test
      labels:
        owner: "admin"
    ---
    # This should be BLOCKED (privileged: true)
    apiVersion: v1
    kind: Pod
    metadata:
      name: naughty
      namespace: policy-test
    spec:
      containers:
      - name: cks
        image: busybox:1.36
        command: ["sh", "-c", "sleep 3600"]
        securityContext:
          privileged: true
    ---
    # This should be ALLOWED
    apiVersion: v1
    kind: Pod
    metadata:
      name: good
      namespace: policy-test
    spec:
      containers:
      - name: cks
        image: busybox:1.36
        command: ["sh", "-c", "sleep 3600"]
        securityContext:
          privileged: false
          readOnlyRootFilesystem: true
    EOF
#### 📂 Step 2: Commit and Push
bash
cd /tmp/Argo-CD

# Check directory structure
#### tree apps/kyverno/

# Should show:
    apps/kyverno/
    ├── 00-kyverno-helm.yaml
    ├── 01-disallow-privileged.yaml
    ├── 02-require-labels.yaml
    ├── 03-disallow-latest-tag.yaml
    ├── 04-require-readonly-rootfs.yaml
    └── 05-test-pods.yaml

# Commit and push
    git add .
    git commit -m "Add Kyverno with policies for GitOps deployment"
    git push
🚀 Step 3: Deploy Kyverno via Argo CD
bash
# Apply the Kyverno Application manifest
    kubectl apply -f apps/kyverno/00-kyverno-helm.yaml

# Check Argo CD sync status
    argocd app list
    argocd app get kyverno

# Wait for sync (may take 2-3 minutes)
    argocd app sync kyverno --force

# Check Kyverno pods
    kubectl get pods -n kyverno

# Check policies
    kubectl get clusterpolicy
📊 Step 4: Verify Kyverno Policies
bash
# Apply test pods (to verify policies are working)
    kubectl apply -f apps/kyverno/05-test-pods.yaml

# Check if naughty pod was blocked
    kubectl get pods -n policy-test

# Check Kyverno policy reports
    kubectl get policyreport -A

# Check individual policy status
    kubectl describe clusterpolicy disallow-privileged
🔍 Step 5: Test Kyverno Policies
bash
# Test: Create a privileged pod (should be blocked)
    cat <<EOF | kubectl apply -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: test-privileged
    spec:
      containers:
      - name: cks
        image: busybox:1.36
        command: ["sh", "-c", "sleep 3600"]
        securityContext:
          privileged: true
    EOF

# Expected output: Error from server: admission webhook "validate.kyverno.svc" denied the request

# Test: Create a pod with latest tag (should be blocked)
    cat <<EOF | kubectl apply -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: test-latest
    spec:
      containers:
      - name: cks
        image: busybox:latest
        command: ["sh", "-c", "sleep 3600"]
    EOF

# Test: Create a valid pod (should be allowed)
    cat <<EOF | kubectl apply -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: test-good
    spec:
      containers:
      - name: cks
        image: busybox:1.36
        command: ["sh", "-c", "sleep 3600"]
        securityContext:
          privileged: false
          readOnlyRootFilesystem: true
    EOF
🧹 Step 6: Clean Up Test Resources
bash
# Delete test namespace
    kubectl delete namespace policy-test

# Delete test pods (if any survived)
    kubectl delete pod test-privileged --ignore-not-found=true
    kubectl delete pod test-latest --ignore-not-found=true
    kubectl delete pod test-good --ignore-not-found=true
#### 📁 Final Git Repo Structure
#### text
    Argo-CD/
    ├── apps/
    │   ├── kyverno/
    │   │   ├── 00-kyverno-helm.yaml      # Kyverno Helm Application
    │   │   ├── 01-disallow-privileged.yaml
    │   │   ├── 02-require-labels.yaml
    │   │   ├── 03-disallow-latest-tag.yaml
    │   │   ├── 04-require-readonly-rootfs.yaml
    │   │   └── 05-test-pods.yaml
    │   ├── nextcloud/
    │   │   ├── 00-namespace.yaml
    │   │   ├── 01-postgres.yaml
    │   │   ├── 02-nextcloud.yaml
    │   │   └── 03-ingress.yaml
    │   └── nginx-test/
    │       ├── 00-deployment.yaml
    │       └── 01-service.yaml
    ├── k8s-manifests/
    └── README.md
#### 📝 Argo CD App Creation Summary
#### Application	Source	Namespace	Status
#### Kyverno	Helm Chart (kyverno/kyverno)	kyverno	⏳ Deploying
#### NextCloud	apps/nextcloud	nextcloud	✅ Deployed
#### Nginx Test	k8s-manifests	default	✅ Deployed
#### 🚀 Quick Commands
bash
# Deploy Kyverno
    kubectl apply -f apps/kyverno/00-kyverno-helm.yaml
    argocd app sync kyverno --force

# Check Kyverno status
    kubectl get pods -n kyverno
    kubectl get clusterpolicy

# Test policies
    kubectl apply -f apps/kyverno/05-test-pods.yaml

# Check policy reports
    kubectl get policyreport -A
#### 🔐 Kyverno Policy Summary
#### Policy	Purpose	Action
#### disallow-privileged	Blocks privileged containers	Enforce
#### require-namespace-labels	Requires owner label on namespaces	Enforce
#### disallow-latest-tag	Blocks images with :latest tag	Enforce
#### require-readonly-rootfs	Requires read-only root filesystem	Enforce
#### 🏆 What's Done
#### Step	Status
#### Kyverno Helm chart as Argo CD Application	✅
#### Kyverno policies in Git	✅
#### GitOps-driven deployment	✅
#### Policy enforcement	✅
#### Test verification	✅
#### Kyverno is now fully GitOps-managed via Argo CD! 🚀

#### This means every time you push changes to your Git repo, Argo CD will automatically apply them. No more manual kubectl apply for policies!
