#!/bin/bash
# Copy join command from master to workers
# Runs with sudo on workers

set -e  # Exit on error
# set -x  # Uncomment for debugging

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# ============================================
# Parameter validation
# ============================================
MASTER_IP="$1"
shift
WORKER_IPS=("$@")

if [ -z "$MASTER_IP" ] || [ ${#WORKER_IPS[@]} -eq 0 ]; then
  echo "Usage: $0 <master-ip> <worker-ip1> <worker-ip2> ..."
  echo "Example: $0 10.0.1.100 10.0.1.101 10.0.1.102"
  echo ""
  echo "First get your IPs from terraform output:"
  echo "  terraform output -raw master_public_ip"
  echo "  terraform output -json worker_public_ips | jq -r '.[]'"
  exit 1
fi

# ============================================
# Function: Wait for API server to be ready
# ============================================
wait_for_api_server() {
  local master_ip=$1
  local max_attempts=60  # 5 minutes total
  local attempt=1
  
  log_step "Waiting for API server to be ready on $master_ip..."
  
  while [ $attempt -le $max_attempts ]; do
    if ssh -i k8s-lab-key.pem ubuntu@$master_ip "kubectl get --raw='/healthz' &>/dev/null" 2>/dev/null; then
      log_info "✅ API server is ready! (attempt $attempt)"
      return 0
    fi
    
    echo -n "."
    sleep 5
    attempt=$((attempt + 1))
  done
  
  log_error "API server not ready after $((max_attempts * 5)) seconds"
  return 1
}

# ============================================
# Function: Wait for all nodes to be ready
# ============================================
wait_for_nodes() {
  local master_ip=$1
  local expected_workers=$2
  local max_attempts=60
  local attempt=1
  
  log_step "Waiting for nodes to register and become Ready..."
  
  while [ $attempt -le $max_attempts ]; do
    # Get ready node count
    READY_NODES=$(ssh -i k8s-lab-key.pem ubuntu@$master_ip \
      "kubectl get nodes --no-headers 2>/dev/null | grep -c Ready" || echo "0")
    
    TOTAL_NODES=$((1 + expected_workers))
    
    if [ "$READY_NODES" -eq "$TOTAL_NODES" ]; then
      log_info "✅ All $TOTAL_NODES nodes are Ready!"
      ssh -i k8s-lab-key.pem ubuntu@$master_ip "kubectl get nodes"
      return 0
    fi
    
    echo -n "."
    sleep 5
    attempt=$((attempt + 1))
  done
  
  log_error "Nodes not ready after $((max_attempts * 5)) seconds"
  ssh -i k8s-lab-key.pem ubuntu@$master_ip "kubectl get nodes --no-headers" || true
  return 1
}

# ============================================
# Function: Get join command with retries
# ============================================
get_join_command() {
  local master_ip=$1
  local max_attempts=30
  local attempt=1
  
  log_step "Generating kubeadm join token..."
  
  while [ $attempt -le $max_attempts ]; do
    # Generate token and capture join command
    ssh -i k8s-lab-key.pem ubuntu@$master_ip \
      "sudo kubeadm token create --print-join-command 2>/dev/null" > /tmp/kubeadm_join_command
    
    if [ -s /tmp/kubeadm_join_command ] && ! grep -q "error" /tmp/kubeadm_join_command; then
      log_info "✅ Join command generated successfully! (attempt $attempt)"
      echo "   Command: $(cat /tmp/kubeadm_join_command)"
      return 0
    fi
    
    echo -n "."
    sleep 3
    attempt=$((attempt + 1))
  done
  
  log_error "Failed to generate join command after $max_attempts attempts"
  return 1
}

# ============================================
# Function: Join a single worker with retry
# ============================================
join_worker() {
  local worker_ip=$1
  local max_attempts=10
  local attempt=1
  
  log_step "Joining worker: $worker_ip"
  
  # Copy join command to worker
  scp -i k8s-lab-key.pem /tmp/kubeadm_join_command ubuntu@$worker_ip:/tmp/kubeadm_join_command 2>/dev/null
  
  while [ $attempt -le $max_attempts ]; do
    if ssh -i k8s-lab-key.pem ubuntu@$worker_ip "sudo bash /tmp/kubeadm_join_command" 2>&1 | tee /tmp/join_output; then
      if grep -q "This node has joined the cluster" /tmp/join_output; then
        log_info "✅ Worker $worker_ip joined successfully! (attempt $attempt)"
        
        # Restart kubelet to ensure clean state
        ssh -i k8s-lab-key.pem ubuntu@$worker_ip "sudo systemctl restart kubelet" 2>/dev/null
        return 0
      fi
    fi
    
    log_warn "Join attempt $attempt failed, retrying in 5 seconds..."
    sleep 5
    attempt=$((attempt + 1))
  done
  
  log_error "Worker $worker_ip failed to join after $max_attempts attempts"
  return 1
}

# ============================================
# MAIN EXECUTION FLOW
# ============================================

echo ""
echo "========================================="
echo "🔗 Kubernetes Worker Join Automation"
echo "========================================="
echo ""
log_info "Master IP: $MASTER_IP"
log_info "Worker IPs: ${WORKER_IPS[*]}"
echo ""

# Step 1: Wait for API server to be ready
wait_for_api_server "$MASTER_IP" || exit 1

# Step 2: Generate join command
get_join_command "$MASTER_IP" || exit 1

# Step 3: Join all workers
FAILED_WORKERS=0
for WORKER_IP in "${WORKER_IPS[@]}"; do
  if ! join_worker "$WORKER_IP"; then
    FAILED_WORKERS=$((FAILED_WORKERS + 1))
  fi
  echo ""
done

# Step 4: Wait for nodes to register (if any workers joined)
if [ $FAILED_WORKERS -lt ${#WORKER_IPS[@]} ]; then
  wait_for_nodes "$MASTER_IP" ${#WORKER_IPS[@]}
fi

# Step 5: Label worker nodes
echo ""
log_step "Labeling worker nodes..."

CONTROL_PLANE=$(ssh -i k8s-lab-key.pem ubuntu@$MASTER_IP \
  "kubectl get nodes -o name 2>/dev/null | grep control-plane | head -1 | cut -d'/' -f2" || echo "")

if [ -n "$CONTROL_PLANE" ]; then
  # Label all non-control-plane nodes as workers
  ssh -i k8s-lab-key.pem ubuntu@$MASTER_IP \
    "kubectl get nodes -o name 2>/dev/null | grep -v $CONTROL_PLANE | cut -d'/' -f2 | xargs -I {} kubectl label node {} node-role.kubernetes.io/worker= --overwrite 2>/dev/null || true"
  
  # Remove worker label from control-plane
  ssh -i k8s-lab-key.pem ubuntu@$MASTER_IP \
    "kubectl label node $CONTROL_PLANE node-role.kubernetes.io/worker- 2>/dev/null || true"
  
  log_info "✅ Node labels applied"
else
  log_warn "Could not find control-plane node, skipping labeling"
fi

# ============================================
# Final summary
# ============================================
echo ""
echo "========================================="
if [ $FAILED_WORKERS -eq 0 ]; then
  echo "✅ ALL WORKERS JOINED SUCCESSFULLY!"
else
  echo "⚠️ $FAILED_WORKERS workers failed to join"
fi
echo "========================================="
echo ""
echo "Verify cluster status:"
echo "  ssh -i k8s-lab-key.pem ubuntu@$MASTER_IP 'kubectl get nodes -o wide'"
echo "  ssh -i k8s-lab-key.pem ubuntu@$MASTER_IP 'kubectl get pods -A'"
echo ""
