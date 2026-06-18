grype
Vulnerability Scanner for SBOMs
Description
Grype scans SBOMs or container images for known vulnerabilities.

Installation
bash
chmod +x install.sh
./install.sh
Files
install.sh - Installation script

Verification
bash
grype version
Test Commands
bash
# Scan an image
grype nginx:alpine

# Scan an SBOM file
grype sbom:sbom.json

# Only show HIGH and CRITICAL
grype nginx:alpine --fail-on high

# Output to JSON
grype nginx:alpine -o json > vulnerability-report.json
Expected Output
text
 ✔ Vulnerability DB        [updated]
 ✔ Scanned image           [nginx:alpine]
   ├── 0 vulnerabilities
   └── No vulnerabilities found