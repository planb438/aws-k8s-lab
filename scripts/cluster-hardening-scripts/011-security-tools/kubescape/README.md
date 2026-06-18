#### kubescape
#### Kubernetes Security Scanner
#### Description
#### Kubescape scans Kubernetes clusters for security issues across multiple frameworks (NSA, MITRE, CIS).

#### Installation
#### bash
#### chmod +x install.sh
#### ./install.sh
#### Files
#### install.sh - Installation script

#### run-security-checks.sh - Validation script

#### Verification
#### bash
#### kubescape version
#### Test Commands
#### bash
# Scan cluster with NSA framework
#### kubescape scan framework nsa

# Scan with MITRE framework
#### kubescape scan framework mitre

# Scan a specific file
#### kubescape scan file deployment.yaml

# Scan with verbose output
#### kubescape scan framework nsa --verbose

# Output to JSON
#### kubescape scan framework nsa --format json > kubescape-report.json
#### Expected Output
#### text
#### Scanning cluster...
#### ✅ All controls passed (or ⚠️ X controls failed)
