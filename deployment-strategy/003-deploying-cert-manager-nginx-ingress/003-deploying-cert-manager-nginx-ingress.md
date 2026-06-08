
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04%2B-lightgrey)](#)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-MicroK8s%20%7C%20kubeadm-blue)](#)
[![YouTube](https://img.shields.io/badge/YouTube-TechShorts-red)](https://www.youtube.com/@adaribain)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Adari%20Bain-blue)](https://www.linkedin.com/in/adari-bain-298924152/)


✅ Deploying Cert Manager + Nginx Ingress (TLS for Everything)
This is a critical component. Every app in the cluster will need HTTPS, and this gives you automatic Let's Encrypt certificates.

Step 1: Deploy Nginx Ingress Controller
bash
# Add the ingress-nginx helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Create namespace
kubectl create namespace ingress-nginx

# Install Nginx Ingress Controller
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.publishService.enabled=true \
  --set controller.replicaCount=2 \
  --set controller.nodeSelector."kubernetes\.io/os"=linux \
  --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux
Verify installation:

bash
# Check pods are running
kubectl get pods -n ingress-nginx

# Check service (should get an EXTERNAL-IP)
kubectl get svc -n ingress-nginx

# Should see:
# NAME                          TYPE           CLUSTER-IP     EXTERNAL-IP
# ingress-nginx-controller      LoadBalancer   10.100.xx.xx   <pending-or-ip>
# ingress-nginx-controller-admission ClusterIP   10.101.xx.xx   <none>
Note: On EC2, the EXTERNAL-IP may show as <pending> unless you have a LoadBalancer configured. This is fine - we can use NodePort or port-forward for testing.

Step 2: Deploy Cert Manager
bash
# Add Jetstack helm repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Create namespace
kubectl create namespace cert-manager

# Install Cert Manager with CRDs
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true \
  --set nodeSelector."kubernetes\.io/os"=linux
Verify installation:

bash
# Check pods are running
kubectl get pods -n cert-manager

# Should see 3 pods:
# cert-manager-xxx (controller)
# cert-manager-cainjector-xxx
# cert-manager-webhook-xxx

# Verify webhook is ready (may take 30 seconds)
kubectl get validatingwebhookconfigurations | grep cert-manager
Step 3: Create Let's Encrypt ClusterIssuer
bash
# Create ClusterIssuer for Let's Encrypt production
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # Let's Encrypt production API
    server: https://acme-v02.api.letsencrypt.org/directory
    # CHANGE THIS TO YOUR EMAIL!
    email: admin@your-domain.com
    privateKeySecretRef:
      name: letsencrypt-prod-private-key
    solvers:
    - http01:
        ingress:
          class: nginx
---
# Optional: Staging issuer for testing (no rate limits)
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@your-domain.com
    privateKeySecretRef:
      name: letsencrypt-staging-private-key
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
Update the email address! Edit the ClusterIssuer with your real email:

bash
kubectl edit clusterissuer letsencrypt-prod
# Change email: admin@your-domain.com to YOUR actual email
Verify issuers:

bash
kubectl get clusterissuer

# Should show:
# NAME                  READY   AGE
# letsencrypt-prod      True    10s
# letsencrypt-staging   True    10s
Step 4: Test with a Simple App (HTTP → HTTPS)
Let's deploy a test app to verify TLS works:

bash
# Deploy a simple test app
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: whoami
  template:
    metadata:
      labels:
        app: whoami
    spec:
      containers:
      - name: whoami
        image: traefik/whoami:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: whoami
  namespace: default
spec:
  selector:
    app: whoami
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - whoami.your-domain.com  # CHANGE THIS
    secretName: whoami-tls
  rules:
  - host: whoami.your-domain.com  # CHANGE THIS
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
Note: Since you likely don't have a domain name yet, we'll test differently in Step 5.

Step 5: Test Without a Domain Name (Self-Signed Certificate)
If you don't have a domain (typical for homelab), create a self-signed issuer:

bash
# Create self-signed certificate issuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
# Create a CA certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: selfsigned-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: selfsigned-ca
  secretName: selfsigned-ca-secret
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
---
# Create issuer from the CA certificate
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: selfsigned-ca-secret
EOF

# Wait for certificate to be ready
kubectl get certificate -n cert-manager
Test with self-signed certificate:

bash
# Test ingress with self-signed cert
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami-selfsigned
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: ca-issuer
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - whoami.local
    secretName: whoami-local-tls
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

# Test locally (add to /etc/hosts if needed)
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443 &

# In another terminal
curl -k https://whoami.local:8443
# Should get a response from the whoami service
Step 6: Verify Everything Works
bash
# Check certificate status
kubectl get certificate --all-namespaces

# Check ingress status
kubectl get ingress --all-namespaces

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager --tail=20

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=20
Summary of What You've Deployed
Component	Status	Purpose
Nginx Ingress Controller	✅ Deployed	Routes external traffic to services
Cert Manager	✅ Deployed	Manages TLS certificates
Let's Encrypt ClusterIssuer	✅ Configured	Automatic HTTPS certs
CA Issuer (self-signed)	✅ Configured	For homelab testing
What's Next After This
yaml
Platform Security Progress:
  ✅ Encryption at rest (aesgcm)
  ✅ Cert Manager + Ingress (TLS)
  
Remaining Platform Security:
  ⬜ Prometheus + Grafana (observability)
  ⬜ Sealed Secrets (secrets management)
  ⬜ Kyverno (policy enforcement)

Then:
  ⬜ PostgreSQL (dependency for NextCloud)
  ⬜ NextCloud deployment
Quick Commands for Later (NextCloud Ingress)
When you're ready to deploy NextCloud with TLS:

yaml
# NextCloud ingress with Let's Encrypt
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nextcloud
  namespace: nextcloud
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "10G"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - nextcloud.your-domain.com
    secretName: nextcloud-tls
  rules:
  - host: nextcloud.your-domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nextcloud
            port:
              number: 8080
Cert Manager + Ingress is now deployed. Your cluster can now terminate TLS for any application you deploy.
