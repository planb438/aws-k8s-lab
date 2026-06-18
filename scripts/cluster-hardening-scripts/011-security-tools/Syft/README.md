#### syft
#### SBOM (Software Bill of Materials) Generator
#### Description
#### Syft generates SBOMs for container images, providing a detailed inventory of all packages.

#### Installation
bash
#### chmod +x install.sh
#### ./install.sh
#### Files
#### install.sh - Installation script

#### Verification
#### bash
#### syft version
#### Test Commands
#### bash
# Generate SBOM for an image
#### syft nginx:alpine

# Output as JSON
#### syft nginx:alpine -o json > sbom.json

# Output as CycloneDX
#### syft nginx:alpine -o cyclonedx-json > sbom-cyclonedx.json

# Generate SBOM for a running container
#### syft docker://nginx:alpine
#### Expected Output
#### text
####  ✔ Parsed image
####  ✔ Cataloged packages      [12 packages]
#### NAME                    VERSION      TYPE
#### alpine-baselayout       3.4.3-r1     apk
#### alpine-keys             2.4-r1       apk
#### apk-tools               2.14.0-r5    apk
#### busybox                 1.36.1-r15   apk
