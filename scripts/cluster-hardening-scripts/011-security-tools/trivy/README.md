#### trivy
#### Container Vulnerability Scanner
#### Description
#### Trivy scans container images for vulnerabilities, misconfigurations, and secrets.

#### Installation
#### bash
#### chmod +x install.sh
#### ./install.sh
#### Files
#### install.sh - Installation script

#### Verification
#### bash
#### trivy --version
#### Test Commands
#### bash
# Scan an image for critical/high vulnerabilities
#### trivy image nginx:alpine --severity CRITICAL,HIGH

# Scan with detailed output
#### trivy image --format table --severity HIGH,CRITICAL nextcloud:latest

# Scan filesystem
#### trivy fs --severity HIGH,CRITICAL /path/to/code

# Output to JSON
#### trivy image nginx:alpine --format json > scan-results.json
#### Expected Output
#### text
#### nginx:alpine (alpine 3.19.1)
#### Total: 0 (UNKNOWN: 0, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
