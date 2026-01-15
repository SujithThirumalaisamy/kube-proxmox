#!/bin/bash
# =============================================================================
# Kubeconfig Setup Script
# =============================================================================
# This script merges the cluster kubeconfig into your local kubectl config
# without overwriting existing clusters, users, or contexts.
#
# Usage: ./scripts/setup-kubeconfig.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$PROJECT_DIR/ansible"
KUBECONFIG_FILE="$ANSIBLE_DIR/kubeconfig"

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
    exit 1
}

prompt() {
    echo -e "${BLUE}[INPUT]${NC} $1"
}

# -----------------------------------------------------------------------------
# Pre-flight checks
# -----------------------------------------------------------------------------

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    warn "kubectl is not installed. Please install kubectl first."
    echo ""
    echo "Installation instructions:"
    echo "  macOS:  brew install kubectl"
    echo "  Linux:  https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
    exit 0
fi

info "kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client | head -1)"

# Check if kubeconfig file exists
if [[ ! -f "$KUBECONFIG_FILE" ]]; then
    error "Kubeconfig file not found at: $KUBECONFIG_FILE

Make sure you have run the Ansible playbook first:
  cd ansible && ansible-playbook site.yml"
fi

# -----------------------------------------------------------------------------
# Extract original cluster information from fetched kubeconfig
# -----------------------------------------------------------------------------

info "Reading cluster configuration from: $KUBECONFIG_FILE"

ORIG_CLUSTER_NAME=$(kubectl config view --kubeconfig="$KUBECONFIG_FILE" -o jsonpath='{.clusters[0].name}')
ORIG_USER_NAME=$(kubectl config view --kubeconfig="$KUBECONFIG_FILE" -o jsonpath='{.users[0].name}')
ORIG_CONTEXT_NAME=$(kubectl config view --kubeconfig="$KUBECONFIG_FILE" -o jsonpath='{.contexts[0].name}')

if [[ -z "$ORIG_CLUSTER_NAME" ]]; then
    error "Could not extract cluster name from kubeconfig"
fi

echo ""
info "Original configuration:"
echo "  Cluster: $ORIG_CLUSTER_NAME"
echo "  User:    $ORIG_USER_NAME"
echo "  Context: $ORIG_CONTEXT_NAME"

# -----------------------------------------------------------------------------
# Ask user for custom names
# -----------------------------------------------------------------------------

echo ""
prompt "Enter custom names for your kubeconfig (press Enter to use defaults):"
echo ""

# Cluster name
read -p "  Cluster name [$ORIG_CLUSTER_NAME]: " CLUSTER_NAME
CLUSTER_NAME="${CLUSTER_NAME:-$ORIG_CLUSTER_NAME}"

# User name
read -p "  User name [$ORIG_USER_NAME]: " USER_NAME
USER_NAME="${USER_NAME:-$ORIG_USER_NAME}"

# Context name - suggest a better default based on cluster name
DEFAULT_CONTEXT="${CLUSTER_NAME}"
read -p "  Context name [$DEFAULT_CONTEXT]: " CONTEXT_NAME
CONTEXT_NAME="${CONTEXT_NAME:-$DEFAULT_CONTEXT}"

echo ""
info "Using configuration:"
echo "  Cluster: $CLUSTER_NAME"
echo "  User:    $USER_NAME"
echo "  Context: $CONTEXT_NAME"

# -----------------------------------------------------------------------------
# Check for existing entries
# -----------------------------------------------------------------------------

EXISTING_CLUSTER=$(kubectl config get-clusters 2>/dev/null | grep -w "$CLUSTER_NAME" || true)
EXISTING_CONTEXT=$(kubectl config get-contexts -o name 2>/dev/null | grep -w "$CONTEXT_NAME" || true)

if [[ -n "$EXISTING_CLUSTER" || -n "$EXISTING_CONTEXT" ]]; then
    echo ""
    warn "Found existing entries in your kubeconfig:"
    [[ -n "$EXISTING_CLUSTER" ]] && echo "  - Cluster: $CLUSTER_NAME"
    [[ -n "$EXISTING_CONTEXT" ]] && echo "  - Context: $CONTEXT_NAME"
    echo ""
    read -p "Do you want to overwrite them? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Aborted. Your existing config was not modified."
        exit 0
    fi
fi

# -----------------------------------------------------------------------------
# Create temporary kubeconfig with custom names
# -----------------------------------------------------------------------------

info "Preparing kubeconfig with custom names..."

TEMP_KUBECONFIG=$(mktemp)
cp "$KUBECONFIG_FILE" "$TEMP_KUBECONFIG"

# Rename cluster
if [[ "$CLUSTER_NAME" != "$ORIG_CLUSTER_NAME" ]]; then
    kubectl config rename-context "$ORIG_CONTEXT_NAME" "__temp_context__" --kubeconfig="$TEMP_KUBECONFIG" 2>/dev/null || true
    kubectl config set-cluster "$CLUSTER_NAME" \
        --server="$(kubectl config view --kubeconfig="$TEMP_KUBECONFIG" -o jsonpath='{.clusters[0].cluster.server}')" \
        --certificate-authority-data="$(kubectl config view --kubeconfig="$TEMP_KUBECONFIG" --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')" \
        --kubeconfig="$TEMP_KUBECONFIG" >/dev/null
    kubectl config unset clusters."$ORIG_CLUSTER_NAME" --kubeconfig="$TEMP_KUBECONFIG" 2>/dev/null || true
fi

# Rename user
if [[ "$USER_NAME" != "$ORIG_USER_NAME" ]]; then
    CLIENT_CERT=$(kubectl config view --kubeconfig="$TEMP_KUBECONFIG" --raw -o jsonpath='{.users[0].user.client-certificate-data}')
    CLIENT_KEY=$(kubectl config view --kubeconfig="$TEMP_KUBECONFIG" --raw -o jsonpath='{.users[0].user.client-key-data}')
    kubectl config set-credentials "$USER_NAME" \
        --client-certificate-data="$CLIENT_CERT" \
        --client-key-data="$CLIENT_KEY" \
        --kubeconfig="$TEMP_KUBECONFIG" >/dev/null 2>&1 || \
    kubectl config set-credentials "$USER_NAME" \
        --embed-certs=true \
        --kubeconfig="$TEMP_KUBECONFIG" >/dev/null 2>&1 || true
    kubectl config unset users."$ORIG_USER_NAME" --kubeconfig="$TEMP_KUBECONFIG" 2>/dev/null || true
fi

# Delete old context and create new one
kubectl config delete-context "__temp_context__" --kubeconfig="$TEMP_KUBECONFIG" 2>/dev/null || true
kubectl config delete-context "$ORIG_CONTEXT_NAME" --kubeconfig="$TEMP_KUBECONFIG" 2>/dev/null || true
kubectl config set-context "$CONTEXT_NAME" \
    --cluster="$CLUSTER_NAME" \
    --user="$USER_NAME" \
    --kubeconfig="$TEMP_KUBECONFIG" >/dev/null

# Set as current context in temp file
kubectl config use-context "$CONTEXT_NAME" --kubeconfig="$TEMP_KUBECONFIG" >/dev/null

# -----------------------------------------------------------------------------
# Merge kubeconfig
# -----------------------------------------------------------------------------

echo ""
info "Merging kubeconfig into ~/.kube/config"

# Ensure ~/.kube directory exists
mkdir -p ~/.kube

# Backup existing config if it exists
if [[ -f ~/.kube/config ]]; then
    BACKUP_FILE=~/.kube/config.backup.$(date +%Y%m%d_%H%M%S)
    cp ~/.kube/config "$BACKUP_FILE"
    info "Backed up existing config to: $BACKUP_FILE"
fi

# Merge using KUBECONFIG environment variable
if [[ -f ~/.kube/config ]]; then
    KUBECONFIG="$TEMP_KUBECONFIG:${HOME}/.kube/config" kubectl config view --flatten > ~/.kube/config.merged
    mv ~/.kube/config.merged ~/.kube/config
else
    cp "$TEMP_KUBECONFIG" ~/.kube/config
fi

chmod 600 ~/.kube/config

# Cleanup
rm -f "$TEMP_KUBECONFIG"

info "Kubeconfig merged successfully!"

# -----------------------------------------------------------------------------
# Set context (optional)
# -----------------------------------------------------------------------------

echo ""
read -p "Do you want to switch to context '$CONTEXT_NAME' now? [Y/n] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    kubectl config use-context "$CONTEXT_NAME"
    info "Switched to context: $CONTEXT_NAME"
fi

# -----------------------------------------------------------------------------
# Verify connection
# -----------------------------------------------------------------------------

echo ""
info "Verifying cluster connection..."
echo ""

if kubectl cluster-info &>/dev/null; then
    kubectl cluster-info
    echo ""
    info "Cluster nodes:"
    kubectl get nodes
else
    warn "Could not connect to cluster. Please check:"
    echo "  - Network connectivity to the control plane"
    echo "  - Firewall rules allow access to port 6443"
    echo "  - VPN connection if required"
fi

echo ""
info "Setup complete!"
echo ""
echo "Useful commands:"
echo "  kubectl get nodes              # List cluster nodes"
echo "  kubectl get pods -A            # List all pods"
echo "  kubectl config get-contexts    # List all contexts"
echo "  kubectl config use-context $CONTEXT_NAME"
