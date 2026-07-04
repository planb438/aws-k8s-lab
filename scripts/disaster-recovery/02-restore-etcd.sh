#!/bin/bash
# etcd Restore Script - CKS Domain: Cluster Setup
# Run on MASTER node during disaster recovery
# WARNING: This will overwrite cluster state!

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

echo ""
echo "========================================="
echo "⚠️  ETCD RESTORE OPERATION"
echo "========================================="
echo ""
log_warn "This will OVERWRITE the entire cluster state!"
read -p "Type 'YES' to continue: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    log_error "Aborted by user"
    exit 1
fi

# ============================================
# Choose snapshot
# ============================================
BACKUP_DIR="/var/backups/etcd"
SNAPSHOT_GZ=$(ls -t $BACKUP_DIR/*.gz 2>/dev/null | head -1)

if [ -z "$SNAPSHOT_GZ" ]; then
    log_error "No snapshot found in $BACKUP_DIR"
    exit 1
fi

log_info "Using snapshot: $SNAPSHOT_GZ"

# ============================================
# Extract and restore
# ============================================
log_info "Extracting snapshot..."
gunzip -c $SNAPSHOT_GZ > /tmp/etcd-restore.db

log_info "Restoring etcd..."
sudo ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-restore.db \
  --data-dir=/var/lib/etcd-restored

log_info "✅ etcd restored successfully!"
log_warn "You must restart etcd for changes to take effect"

echo ""
echo "========================================="
