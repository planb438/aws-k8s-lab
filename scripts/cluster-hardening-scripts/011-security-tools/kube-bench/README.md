kube-bench
CIS Benchmark Scanner
Description
kube-bench runs checks against the Kubernetes CIS Benchmark to ensure your cluster meets security standards.

Installation
bash
chmod +x install.sh
./install.sh
Files
install.sh - Installation script

run-security-checks.sh - Validation script (created after install)

Verification
bash
kube-bench version
kube-bench master --version 1.31
Test Commands
bash
# Run all master node checks
sudo kube-bench master --version 1.31

# Run specific check
sudo kube-bench master --version 1.31 --check 1.1.1

# JSON output for automation
sudo kube-bench master --version 1.31 --json | jq '.Totals'

# Run node checks (from worker node)
sudo kube-bench node --version 1.31
Expected Output
text
[INFO] 1 Master Node Security Configuration
[PASS] 1.1.1 Ensure that the API server pod specification file permissions are set to 644 or more restrictive
[WARN] 1.1.2 Ensure that the API server pod specification file ownership is set to root:root
