#!/bin/bash
# =============================================================================
# Configuration Initialization Script
# =============================================================================
# This script copies all example configuration files to create your local
# configuration. Run this once after cloning the repository.
#
# Usage: ./scripts/init-config.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

success() {
  echo -e "${GREEN}[OK]${NC} $1"
}

skip() {
  echo -e "${YELLOW}[SKIP]${NC} $1"
}

echo ""
echo "==========================================="
echo "  Kubernetes on Proxmox - Config Setup"
echo "==========================================="
echo ""

cd "$PROJECT_DIR"

COPIED=0
SKIPPED=0
FAILED=0

# Function to copy example file
copy_config() {
  local example="$1"
  local target="$2"

  if [[ ! -f "$example" ]]; then
    error "Example file not found: $example"
    ((FAILED++))
    return
  fi

  if [[ -f "$target" ]]; then
    skip "$target (already exists)"
    ((SKIPPED++))
  else
    # Create parent directory if needed
    mkdir -p "$(dirname "$target")"
    cp "$example" "$target"
    success "$target"
    ((COPIED++))
  fi
}

# Copy all configuration files
copy_config "terraform/terraform.tfvars.example" "terraform/terraform.tfvars"
copy_config "terraform/credentials.auto.tfvars.example" "terraform/credentials.auto.tfvars"
copy_config "ansible/inventory/hosts.yml.example" "ansible/inventory/hosts.yml"
copy_config "ansible/group_vars/all.yml.example" "ansible/group_vars/all.yml"

echo ""
echo "==========================================="
echo "  Summary"
echo "==========================================="
echo ""
info "Copied: $COPIED file(s)"
[[ $SKIPPED -gt 0 ]] && warn "Skipped: $SKIPPED file(s) (already exist)"
[[ $FAILED -gt 0 ]] && error "Failed: $FAILED file(s)"

if [[ $COPIED -gt 0 || $SKIPPED -gt 0 ]]; then
  echo ""
  echo "==========================================="
  echo "  Next Steps"
  echo "==========================================="
  echo ""
  echo "1. Edit Terraform configuration:"
  echo -e "   ${BLUE}vim terraform/credentials.auto.tfvars${NC}  # Add Proxmox credentials"
  echo -e "   ${BLUE}vim terraform/terraform.tfvars${NC}         # Configure VMs"
  echo ""
  echo "2. Provision VMs:"
  echo -e "   ${BLUE}cd terraform && terraform init && terraform apply${NC}"
  echo ""
  echo "3. Edit Ansible configuration:"
  echo -e "   ${BLUE}vim ansible/inventory/hosts.yml${NC}        # Add VM IPs"
  echo -e "   ${BLUE}vim ansible/group_vars/all.yml${NC}         # Configure K8s"
  echo ""
  echo "4. Initialize Kubernetes cluster:"
  echo -e "   ${BLUE}cd ansible && ansible-playbook site.yml${NC}"
  echo ""
  echo "5. Setup kubeconfig:"
  echo -e "   ${BLUE}./scripts/setup-kubeconfig.sh${NC}"
  echo ""
fi
