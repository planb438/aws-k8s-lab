#!/bin/bash
# Fix 1.1.12 - etcd data directory ownership
# Run on MASTER node

set -e

echo "🔧 Fixing etcd data directory ownership..."

# Check if etcd data directory exists
ETCD_DATA_DIR="/var/lib/etcd"

if [ -d "$ETCD_DATA_DIR" ]; then
    echo "Current ownership:"
    ls -la $ETCD_DATA_DIR | head -5
    
    echo "Fixing ownership to etcd:etcd..."
    sudo chown -R etcd:etcd $ETCD_DATA_DIR
    
    echo "Verified ownership:"
    ls -la $ETCD_DATA_DIR | head -5
    echo "✅ etcd ownership fixed"
else
    echo "⚠️ etcd data directory not found at $ETCD_DATA_DIR"
    echo "Check etcd data directory with: ps -ef | grep etcd | grep data-dir"
fi