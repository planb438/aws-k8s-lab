markdown
# Ingress + Cert Manager Setup

One-Liner to Run Everything After terraform apply
bash
# SSH to master and run
ssh -i k8s-lab-key.pem ubuntu@$(terraform output -raw master_public_ip) 'bash -s' < install-ingress-certmanager.sh

## Prerequisites
- Kubernetes cluster running (1 master + 2 workers)
- Helm installed on master node

## Automated Installation
```bash
# Copy script to master
scp -i k8s-lab-key.pem install-ingress-certmanager.sh ubuntu@<master-ip>:~/

# SSH to master and run
ssh -i k8s-lab-key.pem ubuntu@<master-ip>
chmod +x install-ingress-certmanager.sh
./install-ingress-certmanager.sh
Manual Steps (if script fails)
Step 1: Install Ingress
bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
kubectl create ns ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.https=30443 \
  --set controller.admissionWebhooks.enabled=false
Step 2: Install Cert Manager
bash
helm repo add jetstack https://charts.jetstack.io
kubectl create ns cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true
Step 3: Fix Webhook (CRITICAL)
bash
kubectl delete validatingwebhookconfiguration cert-manager-webhook
kubectl delete pods -n cert-manager --all
Step 4: Create ClusterIssuer
bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: selfsigned-ca-secret
EOF
Step 5: Deploy Test App
bash
kubectl create deployment whoami --image=traefik/whoami
kubectl expose deployment whoami --port=80
Step 6: Create Ingress
bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami
  annotations:
    cert-manager.io/cluster-issuer: ca-issuer
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - whoami.local
    secretName: whoami-tls
  rules:
  - host: whoami.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: whoami
            port:
              number: 80
EOF
Verification
bash
# Check certificate
kubectl get certificate whoami-tls

# Test via port-forward
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443 &
curl -k https://whoami.local:8443 --resolve whoami.local:8443:127.0.0.1
Known Issues & Fixes
Issue	Fix
cert-manager webhook timeout	Delete webhook, restart pods
ingress admission webhook timeout	Delete webhook, restart ingress
NodePort not accessible	Add 30000-32767 to AWS security group