#!/bin/bash
# etcd Backup Script - CKS Domain: Cluster Setup
# Run on MASTER node
# Backs up etcd to /backup and optionally to S3

set -e

# Colors
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
# Configuration
# ============================================
BACKUP_DIR="/var/backups/etcd"
S3_BUCKET="planb-backup-bucket"
S3_PATH="etcd-backups/"
ETCD_CA="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"
RETENTION_DAYS=30

# ============================================
# Step 1: Create backup directory
# ============================================
log_step "Creating backup directory..."
sudo mkdir -p $BACKUP_DIR
sudo chmod 700 $BACKUP_DIR

# ============================================
# Step 2: Generate snapshot filename
# ============================================
SNAPSHOT_FILE="$BACKUP_DIR/etcd-snapshot-$(date +%Y%m%d_%H%M%S).db"
log_info "Snapshot file: $SNAPSHOT_FILE"

# ============================================
# Step 3: Take etcd snapshot
# ============================================
log_step "Taking etcd snapshot..."
sudo ETCDCTL_API=3 etcdctl snapshot save $SNAPSHOT_FILE \
  --cacert=$ETCD_CA \
  --cert=$ETCD_CERT \
  --key=$ETCD_KEY

# ============================================
# Step 4: Verify snapshot
# ============================================
log_step "Verifying snapshot..."
sudo ETCDCTL_API=3 etcdctl snapshot status $SNAPSHOT_FILE \
  --write-out=table

# ============================================
# Step 5: Compress snapshot
# ============================================
log_step "Compressing snapshot..."
sudo gzip -f $SNAPSHOT_FILE
SNAPSHOT_GZ="${SNAPSHOT_FILE}.gz"
log_info "Compressed: $SNAPSHOT_GZ"

# ============================================
# Step 6: Upload to S3 (if AWS CLI available)
# ============================================
if command -v aws &> /dev/null; then
    log_step "Uploading to S3..."
    aws s3 cp $SNAPSHOT_GZ s3://$S3_BUCKET/$S3_PATH$(basename $SNAPSHOT_GZ)
    log_info "✅ Uploaded to s3://$S3_BUCKET/$S3_PATH$(basename $SNAPSHOT_GZ)"
else
    log_warn "AWS CLI not installed - skipping S3 upload"
fi

# ============================================
# Step 7: Cleanup old backups (local)
# ============================================
log_step "Cleaning up old local backups..."
sudo find $BACKUP_DIR -name "*.gz" -mtime +$RETENTION_DAYS -delete
log_info "✅ Removed backups older than $RETENTION_DAYS days"

# ============================================
# Summary
# ============================================
echo ""
echo "========================================="
log_step "ETCD BACKUP COMPLETE"
echo "========================================="
echo ""
log_info "Snapshot: $SNAPSHOT_GZ"
log_info "Size: $(du -h $SNAPSHOT_GZ | cut -f1)"
log_info "Local backups retained: $RETENTION_DAYS days"
echo ""
echo "========================================="
