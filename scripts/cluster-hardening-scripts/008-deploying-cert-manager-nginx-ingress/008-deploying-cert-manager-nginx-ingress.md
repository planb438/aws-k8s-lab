
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04%2B-lightgrey)](#)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-MicroK8s%20%7C%20kubeadm-blue)](#)
[![YouTube](https://img.shields.io/badge/YouTube-TechShorts-red)](https://www.youtube.com/@adaribain)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Adari%20Bain-blue)](https://www.linkedin.com/in/adari-bain-298924152/)


#### ✅ Deploying Cert Manager + Nginx Ingress (TLS for Everything)
#### This is a critical component. Every app in the cluster will need HTTPS, and this gives you automatic Let's Encrypt certificates.

#### Kubernetes Ingress + Cert Manager Automation
#### 📋 Overview
#### This automated script deploys a complete Ingress Controller with TLS termination using self-signed certificates on a Kubernetes cluster #### (kubeadm + Calico).
#### 
#### What This Script Does
#### Step	Component	Action
#### 1	Ingress Controller	Installs Nginx Ingress with hostNetwork (bypasses Calico issues)
#### 2	Cert Manager	Installs cert-manager WITHOUT --wait (prevents timeout)
#### 3	Webhook Fix	Deletes blocking webhook, restarts pods (critical for Calico)
#### 4	ClusterIssuer	Creates self-signed CA issuer for internal testing
#### 5	Test App	Deploys whoami test application
#### 6	TLS Ingress	Creates Ingress with HTTPS certificate
#### 7	Webhook Cleanup	Fixes Ingress admission webhook
#### 8	Verification	Tests HTTPS connection via port-forward
#### 🚀 Quick Start
#### Prerequisites
bash
####  On your MASTER node, ensure you have:
#### helm version   # v3.0+
#### kubectl version  # v1.31+
#### Run the Script
bash
####  Make executable
#### chmod +x install-ingress-certmanager.sh

####  Run it
#### ./install-ingress-certmanager.sh
#### Expected Output (Success)
bash
#### [STEP] Installing Nginx Ingress Controller...
#### [INFO] ✅ Ingress installed

#### [STEP] Installing Cert Manager (background)...
#### [INFO] Cert Manager installation started

#### [STEP] Fixing cert-manager webhook...
#### [INFO] ✅ Cert Manager webhook fixed

#### [STEP] Creating self-signed ClusterIssuer...
#### NAME                READY   AGE
#### ca-issuer           True    10s
#### selfsigned-issuer   True    10s

#### [STEP] Deploying test app...
#### [INFO] ✅ Test app deployed

#### [STEP] Creating Ingress with TLS...
#### NAME               READY   SECRET             AGE
#### whoami-local-tls   True    whoami-local-tls   15s

=========================================
#### 🔍 TEST: curl with HTTPS
=========================================
#### Hostname: whoami-69bd47c6b5-btpth
#### X-Forwarded-Proto: https

#### ✅ INSTALLATION COMPLETE!
#### 🧪 Verification Commands
#### After script completes, verify your setup:

bash
####  1. Check ClusterIssuers
kubectl get clusterissuer

####  2. Check Certificates
kubectl get certificate -A

####  3. Check Ingress
kubectl get ingress

####  4. Test HTTPS (port-forward)
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443 &
curl -k https://whoami.local:8443 --resolve whoami.local:8443:127.0.0.1

####  5. Check Ingress Controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=20
#### 📝 Access Methods
#### Method 1: Port-Forward (Always Works)
bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443 &
curl -k https://whoami.local:8443 --resolve whoami.local:8443:127.0.0.1
#### Method 2: NodePort (Requires AWS Security Group)
bash
####  Add this to your AWS security group: TCP 30443 from 0.0.0.0/0
NODE_PORT=$(kubectl get svc -n ingress-nginx -o jsonpath='{.items[0].spec.ports[?(@.name=="https")].nodePort}')
curl -k https://$(hostname -I | awk '{print $1}'):$NODE_PORT -H "Host: whoami.local"
Method 3: HostNetwork Direct (If Ingress is on master node)
bash
curl -k https://$(hostname -I | awk '{print $1}') -H "Host: whoami.local"
#### 🐛 Lessons Learned
#### 1. Never Use --wait with cert-manager on Calico
Problem: Cert-manager installation times out because the webhook can't be reached during initial deployment.

Fix:

bash
####  WRONG - Times out
helm upgrade --install cert-manager ... --wait

####  CORRECT - Install without wait, then fix webhook
helm upgrade --install cert-manager ...  # no --wait
kubectl delete validatingwebhookconfiguration cert-manager-webhook
kubectl delete pods -n cert-manager --all
#### 2. Calico Blocks Ingress to Pod Traffic
Problem: Ingress controller can't reach pods on different nodes (504 errors).

Fix: Use controller.hostNetwork=true to bypass Calico:

bash
--set controller.hostNetwork=true \
--set controller.service.type=ClusterIP
#### 3. Ingress Admission Webhook Causes Timeouts
Problem: The ingress admission webhook can block ingress creation on fresh clusters.

Fix:

bash
kubectl delete validatingwebhookconfiguration ingress-nginx-admission
kubectl delete pods -n ingress-nginx --all
#### 4. Cert-Manager Webhook Needs Immediate Fix
Problem: Even after installation, the webhook prevents ClusterIssuer creation.

Fix: Delete webhook and restart pods within 10-20 seconds of installation.

#### 5. Port-Forward Takes Time to Stabilize
Problem: Running curl immediately after port-forward often times out.

#### Fix: Add sleep 5 after starting port-forward before testing.

#### 📁 File Structure
text
#### cluster-hardening-scripts/
#### └── 008-deploying-cert-manager-nginx-ingress/
####    ├── install-ingress-certmanager.sh    # Main script
####     ├── Self-Signed-ClusterIssuer.yaml    # ClusterIssuer definition
####     ├── Deploy-whoami-Test-App.yaml       # Test app deployment
####     └── Ingress-with-Self-Signed-Cert.yaml # Ingress definition
#### 🔧 Troubleshooting
Issue: Cert-manager pods not starting
bash
kubectl get pods -n cert-manager
kubectl logs -n cert-manager deployment/cert-manager
Issue: Certificate stuck in "False" state
bash
kubectl describe certificate whoami-local-tls
kubectl describe clusterissuer ca-issuer
Issue: 504 Gateway Timeout
bash
####  Check if Ingress can reach pod
INGRESS_POD=$(kubectl get pods -n ingress-nginx -o name | head -1)
kubectl exec -n ingress-nginx $INGRESS_POD -- curl -s http://whoami.default
Issue: "connection refused" on port 8443
bash
####  Kill and restart port-forward
pkill -f "kubectl port-forward"
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443 &
sleep 5
curl -k https://whoami.local:8443 --resolve whoami.local:8443:127.0.0.1
#### 📊 Validation Checklist
After running the script, verify each item:

bash
####  ✅ ClusterIssuers ready
kubectl get clusterissuer | grep True

####  ✅ Certificate ready
kubectl get certificate whoami-local-tls | grep True

####  ✅ Ingress created
kubectl get ingress whoami-selfsigned

####  ✅ whoami pod running
kubectl get pods -l app=whoami

####  ✅ HTTPS responds
curl -k --max-time 5 https://whoami.local:8443 --resolve whoami.local:8443:127.0.0.1 | grep -q "Hostname" && echo "✅ HTTPS WORKING"
#### 🎯 Next Steps
#### After successful installation:
#### 
#### Deploy real applications (NextCloud, WordPress, etc.) using the same Ingress pattern
#### 
#### Switch to Let's Encrypt for production domains
#### 
#### Add Sealed Secrets for GitOps secret management
#### 
#### Deploy Kyverno for policy enforcement
#### 
#### Example: NextCloud Ingress with Let's Encrypt
yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nextcloud
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
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

---
markdown
## Ingress + Cert Manager Installation

Run the automated script:

```bash
./cluster-hardening-scripts/008-deploying-cert-manager-nginx-ingress/install-ingress-certmanager.sh
The script will:

Install Nginx Ingress Controller with hostNetwork (bypasses Calico)

Install cert-manager using kubectl manifests (no timeout)

Fix cert-manager webhook (removes blocking configuration)

Create self-signed ClusterIssuer for testing

Deploy a test whoami application

Create a TLS-enabled Ingress

Verify HTTPS is working

Expected output:

text
Hostname: whoami-xxxxx
X-Forwarded-Proto: https
text

### 3. Create a Cleanup Script (Already Have One)

Save this as `cleanup.sh`:

```bash
#!/bin/bash
# Clean up for re-testing
kubectl delete ns ingress-nginx cert-manager --ignore-not-found=true
kubectl delete clusterissuer --all
kubectl delete validatingwebhookconfiguration cert-manager-webhook ingress-nginx-admission --ignore-not-found=true
kubectl delete deployment whoami
kubectl delete svc whoami
kubectl delete ingress whoami-selfsigned
echo "✅ Cleanup complete"
4. Test the Full Cycle
bash
# Clean up
./cleanup.sh

# Re-run script
./install-ingress-certmanager.sh

# Should work every time!
Your Project Status
Item	Status
Terraform AWS infrastructure	✅ Complete
Kubernetes cluster (1 master + 2 workers)	✅ Complete
Audit logging	✅ Complete
Encryption at rest (AES-GCM)	✅ Complete
Ingress Controller	✅ Complete
Cert Manager	✅ Complete
TLS certificates	✅ Complete
Automated installation script	✅ NOW WORKING
Documentation	✅ Ready

---

#### 📞 Support
#### Issue	Solution
#### Helm not found	curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
#### kubectl not found	Install via apt install kubectl
#### Permission denied	chmod +x install-ingress-certmanager.sh
#### API server not reachable	Wait 60 seconds after cluster creation
#### 📄 License
#### MIT License - Use freely for learning and production.
#### 
#### 🙏 Acknowledgments
#### Kubernetes documentation
#### 
#### Cert-Manager project
#### 
#### Nginx Ingress Controller team
#### 
#### All the debugging sessions that led to these fixes
#### 
#### Built with ☁️ for production Kubernetes clusters


