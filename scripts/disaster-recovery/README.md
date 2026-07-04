#### This is a critical insight that many engineers miss:

# 📊 The Difference - Visual Summary
#### text
    ┌─────────────────────────────────────────────────────────────────┐
    │                    VELERO BACKUP                               │
    ├─────────────────────────────────────────────────────────────────┤
    │  ✅ Kubernetes objects (deployments, services, configmaps)    │
    │  ✅ PVC snapshots (application data)                          │
    │  ✅ Application workloads                                     │
    │  ❌ etcd (cluster state)                                      │
    │  ❌ Control plane configuration                               │
    └─────────────────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────────┐
    │                    ETCD BACKUP                                 │
    ├─────────────────────────────────────────────────────────────────┤
    │  ✅ Everything in Kubernetes state (binary level)             │
    │  ✅ All cluster objects                                       │
    │  ✅ Certificates and cluster config                           │
    │  ✅ The entire control plane "brain"                          │
    │  ❌ PVC data (application data)                               │
    │  ❌ Persistent volumes                                        │
    │  ❌ Container images                                          │
    └─────────────────────────────────────────────────────────────────┘

# 🔄 Disaster Scenarios
#### Scenario	Velero	etcd Backup
#### WordPress pod corrupted	✅ Restores in minutes	❌ Not needed
#### Control plane dies / etcd corrupted	❌ Cannot help	✅ Restores cluster state
#### Entire cluster destroyed	✅ Restores apps (after etcd)	✅ Restores cluster state

# 🏗️ Your Complete DR Strategy
#### text
    Layer 1 — etcd Snapshot (daily → S3)
          Protects: Cluster state, control plane, certificates

    Layer 2 — Velero Backup (daily → MinIO)
          Protects: Application data + K8s objects

    Layer 3 — Terraform State (S3 backend)
          Protects: Infrastructure as Code

    Disaster Recovery Sequence:
    ┌─────────────────────────────────────────────────────────────────┐
    │  1. terraform apply     → rebuild infrastructure              │
    │  2. etcd restore        → restore cluster brain               │
    │  3. velero restore      → restore applications + data         │
    └─────────────────────────────────────────────────────────────────┘

# ✅ etcd Backup Script
#### Save as 01-backup-etcd.sh:

#### bash
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

# 🔄 etcd Restore Script
#### Save as 02-restore-etcd.sh:

#### bash
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

# ⏰ CronJob for Automated Backups
#### Save as 03-etcd-cronjob.yaml:

#### yaml
    apiVersion: batch/v1
    kind: CronJob
    metadata:
      name: etcd-backup
      namespace: kube-system
    spec:
      schedule: "0 2 * * *"
      jobTemplate:
        spec:
          template:
            spec:
              hostNetwork: true
              nodeSelector:
                node-role.kubernetes.io/control-plane: ""
              tolerations:
              - key: node-role.kubernetes.io/control-plane
                operator: Exists
                effect: NoSchedule
              restartPolicy: OnFailure
              containers:
              - name: etcd-backup
                image: bitnami/kubectl:latest
                command:
                - /bin/bash
                - -c
                - |
                  BACKUP_DIR=/backup/etcd
                  mkdir -p $BACKUP_DIR
                  SNAPSHOT="$BACKUP_DIR/etcd-snapshot-$(date +%Y%m%d_%H%M%S).db"
                  ETCDCTL_API=3 etcdctl snapshot save $SNAPSHOT \
                    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
                    --cert=/etc/kubernetes/pki/etcd/server.crt \
                    --key=/etc/kubernetes/pki/etcd/server.key
                  gzip -f $SNAPSHOT
                  find $BACKUP_DIR -name "*.gz" -mtime +30 -delete
                  echo "✅ etcd backup completed: $SNAPSHOT.gz"
                volumeMounts:
                - name: backup
                  mountPath: /backup
                - name: etcd-certs
                  mountPath: /etc/kubernetes/pki/etcd
                  readOnly: true
              volumes:
              - name: backup
                hostPath:
                  path: /var/backups/etcd
                  type: DirectoryOrCreate
              - name: etcd-certs
                hostPath:
                  path: /etc/kubernetes/pki/etcd
                  type: Directory

# 📊 Summary: What You Need
#### Component	Purpose	Frequency	Storage
#### etcd Snapshot	Cluster state	Daily	S3 / Local
#### Velero Backup	Application data	Daily	MinIO
#### Terraform State	Infrastructure	On apply	S3

# 🏆 CKS Domain Coverage
#### CKS Domain	Velero	etcd Backup
#### Cluster Setup	✅	✅
#### Cluster Hardening	✅	✅
#### System Hardening	❌	❌
#### Microservice Vulnerabilities	❌	❌
#### Supply Chain Security	❌	❌
#### Monitoring & Logging	❌	❌
#### Runtime Security	❌	❌
#### Network Security	❌	❌
