cosign
Container Image Signing
Description
Cosign enables signing and verifying container images using Sigstore.

Installation
bash
chmod +x install.sh
./install.sh
Files
install.sh - Installation script

Verification
bash
cosign version
Test Commands
bash
# Generate a key pair
cosign generate-key-pair

# Sign an image
cosign sign --key cosign.key ghcr.io/username/image:tag

# Verify an image
cosign verify --key cosign.pub ghcr.io/username/image:tag

# List signatures
cosign triangulate ghcr.io/username/image:tag
