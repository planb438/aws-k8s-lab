# ✅ Metrics Server GitOps
#### GitOps-managed application via Argo CD.

#### 📁 Step 1: Create Metrics Server Application in Your Repo
#### bash
    cd ~/argocd-applications-homelab
    mkdir -p apps/metrics-server

cat > apps/metrics-server/00-application.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: kube-system
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: metrics-server
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://kubernetes-sigs.github.io/metrics-server
    targetRevision: "3.12.1"
    chart: metrics-server
    helm:
      values: |
        args:
          - --kubelet-insecure-tls
          - --kubelet-preferred-address-types=InternalIP
        nodeSelector:
          kubernetes.io/os: linux
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
EOF
#### 📁 Step 2: Fix the Repo URL
#### The correct repo URL for Metrics Server Helm chart is:

#### bash
# CORRECT repo URL
    repoURL: https://kubernetes-sigs.github.io/metrics-server

#### 📁 Step 3: Commit and Deploy
#### bash
# Add to Git
    git add apps/metrics-server/
    git commit -m "Add Metrics Server via Argo CD"
    git push

# Deploy to cluster
    kubectl apply -f apps/metrics-server/00-application.yaml

# Sync with Argo CD
    argocd app sync metrics-server --force

# Verify
    kubectl get pods -n kube-system | grep metrics-server
    kubectl get deployment metrics-server -n kube-system
    kubectl top nodes
#### 📁 Step 4: Remove Manual Helm Installation
#### bash
# Uninstall the manual Helm release
    helm uninstall metrics-server -n default 2>/dev/null

# Argo CD will now manage it in kube-system
    argocd app sync metrics-server --force

# Verify
    kubectl get pods -n kube-system | grep metrics-server
    kubectl top nodes
#### 📁 Updated Working Application
#### Here's the complete working file:

yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kube-system
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: metrics-server
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://kubernetes-sigs.github.io/metrics-server
    targetRevision: "3.12.1"
    chart: metrics-server
    helm:
      values: |
        args:
          - --kubelet-insecure-tls
          - --kubelet-preferred-address-types=InternalIP
        nodeSelector:
          kubernetes.io/os: linux
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
📁 Verify Metrics Server is Working
bash
# Check pod status
    kubectl get pods -n kube-system | grep metrics-server

# Check deployment
    kubectl get deployment metrics-server -n kube-system

# Test metrics
    kubectl top nodes
    kubectl top pods -A

# Check Argo CD app status
    argocd app get metrics-server


# ============================================
# Summary
# ============================================
#### echo ""
#### echo "========================================="
#### log_step "INSTALLATION COMPLETE"
#### echo "========================================="
#### echo ""
#### echo "✅ Metrics Server installed and configured"
#### echo ""
#### echo "📝 Test Commands:"
#### echo ""
#### echo "  # Check node metrics"
#### echo "  kubectl top nodes"
#### echo ""
#### echo "  # Check pod metrics"
#### echo "  kubectl top pods -A"
#### echo ""
#### echo "  # Check HPA"
#### echo "  kubectl get hpa -A"
#### echo ""
#### echo "  # Check API service"
#### echo "  kubectl get apiservices | grep metrics"
#### echo ""
#### echo "========================================="
#### echo ""
#### log_info "⚠️ Note: First 'kubectl top' may take 1-2 minutes to show data"
#### Quick One-Liner Alternative
#### If you prefer a simpler approach:

    bash
    #!/bin/bash
    # Quick Metrics Server Install

    echo "Installing Metrics Server..."
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

    echo "Patching for local development..."
    kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
    {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"},
    {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-preferred-address-types=InternalIP"}
    ]'

    echo "Waiting for rollout..."
    kubectl rollout status deployment/metrics-server -n kube-system --timeout=60s

    echo "✅ Metrics Server installed!"
    echo ""
    echo "Test: kubectl top nodes"
    Verify Metrics Server
    bash
    # Check deployment
    kubectl get deployment metrics-server -n kube-system

# Check pods
    kubectl get pods -n kube-system | grep metrics-server

# Check API service
    kubectl get apiservices | grep metrics

# Test node metrics (may take 30-60 seconds first time)
    kubectl top nodes

# Test pod metrics
    kubectl top pods -A
#### Troubleshooting
#### If kubectl top returns "error: Metrics API not available"
bash
# Check API service status
    kubectl get apiservices | grep metrics

# If not available, wait 1-2 minutes and retry
    kubectl get pods -n kube-system | grep metrics-server

# Check logs
    kubectl logs -n kube-system deployment/metrics-server --tail=20
#### If kubectl top returns "No resources found"
bash
# Wait 1-2 minutes for metrics to be collected
     sleep 60
     kubectl top nodes
#### If metrics-server pods are crashing
bash
# Check pod status
    kubectl get pods -n kube-system | grep metrics-server

# Check logs
    kubectl logs -n kube-system deployment/metrics-server --tail=50

# Common fix: ensure --kubelet-insecure-tls flag is set
    kubectl edit deployment metrics-server -n kube-system
# Add: - --kubelet-insecure-tls
#### Security Notes
#### Practice	Why It Matters
#### Don't use --kubelet-insecure-tls in production	In production, use secure kubelet CA trust chains
#### #### Ensure RBAC is scoped	Metrics server reads node/pod stats – ensure it doesn't have write privileges
#### Monitor availability	If metrics-server crashes, HPA and kubectl top break silently
#### What's Next
#### Now that metrics-server is installed, you can:

#### Deploy HPA for autoscaling workloads

#### Use kubectl top for monitoring

#### Enable VPA for vertical scaling

#### Built with ☁️ for Production Kubernetes
