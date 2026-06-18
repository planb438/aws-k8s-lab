kubeseal
Sealed Secrets for GitOps
Description
kubeseal encrypts Kubernetes secrets into SealedSecrets that are safe to store in Git.

Installation
bash
chmod +x install.sh
./install.sh
Files
install.sh - Installation script

Verification
bash
kubeseal --version
Test Commands
bash
# Create a plain secret
kubectl create secret generic my-secret --from-literal=password=secret123 --dry-run=client -o yaml > secret.yaml

# Seal the secret
kubeseal < secret.yaml > sealed-secret.yaml

# Apply sealed secret
kubectl apply -f sealed-secret.yaml

# Get the public key
kubeseal --fetch-cert > public-key.pem
Expected Output
text
sealedsecret.bitnami.com/my-secret created
