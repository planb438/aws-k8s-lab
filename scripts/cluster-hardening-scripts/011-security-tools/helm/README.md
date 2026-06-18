helm
Kubernetes Package Manager
Description
Helm is the package manager for Kubernetes, used to deploy and manage applications.

Installation
bash
chmod +x install.sh
./install.sh
Files
install.sh - Installation script

Verification
bash
helm version
Test Commands
bash
# Add a repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Update repos
helm repo update

# Search for charts
helm search repo nginx

# Install a chart
helm install my-nginx ingress-nginx/ingress-nginx

# List releases
helm list -A

# Uninstall
helm uninstall my-nginx -n namespace
