#!/bin/bash

# Script to amend Asset CRD to allow multiple datasets in Kubernetes
# This script removes the maxItems: 1 constraint from the datasets array in the Asset CRD

set -euo pipefail

# Configuration
CRD_NAME="assets.deviceregistry.microsoft.com"
NAMESPACE="${NAMESPACE:-azure-iot-operations}"
BACKUP_DIR="$(dirname "$0")/../crd-backups"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
check_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl could not be found. Please install kubectl and try again."
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq could not be found. Please install jq and try again."
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Create backup directory if it doesn't exist
create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    log_info "Backup directory created: $BACKUP_DIR"
}

# Backup current CRD
backup_crd() {
    local backup_file="$BACKUP_DIR/assets-crd-backup-$TIMESTAMP.yaml"
    
    log_info "Creating backup of current Asset CRD..."
    if kubectl get crd "$CRD_NAME" -o yaml > "$backup_file"; then
        log_info "CRD backed up to: $backup_file"
    else
        log_error "Failed to backup CRD. Exiting."
        exit 1
    fi
}

# Check if CRD exists
check_crd_exists() {
    if ! kubectl get crd "$CRD_NAME" &> /dev/null; then
        log_error "Asset CRD '$CRD_NAME' not found. Please ensure Azure IoT Operations is installed."
        exit 1
    fi
    log_info "Asset CRD found: $CRD_NAME"
}

# Create the JSON patch to remove maxItems constraint
create_patch() {
    cat > /tmp/crd-datasets-patch.json << 'EOF'
[
  {
    "op": "remove",
    "path": "/spec/versions/0/schema/openAPIV3Schema/properties/spec/properties/datasets/maxItems"
  }
]
EOF
    log_info "JSON patch created to remove maxItems constraint from datasets array"
}

# Apply the patch
apply_patch() {
    log_info "Applying patch to remove maxItems constraint from datasets..."
    
    if kubectl patch crd "$CRD_NAME" --type='json' --patch-file=/tmp/crd-datasets-patch.json; then
        log_info "Successfully patched Asset CRD to allow multiple datasets"
    else
        log_error "Failed to apply patch. Check the error messages above."
        exit 1
    fi
}

# Verify the patch was applied successfully
verify_patch() {
    log_info "Verifying the patch was applied successfully..."
    
    # Check if maxItems field is removed from datasets
    local max_items_check
    max_items_check=$(kubectl get crd "$CRD_NAME" -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.datasets.maxItems}' 2>/dev/null || echo "")
    
    if [[ -z "$max_items_check" ]]; then
        log_info "✅ Verification successful: maxItems constraint removed from datasets array"
        log_info "Assets can now have multiple datasets configured"
    else
        log_warn "⚠️  Verification inconclusive: maxItems value is still: $max_items_check"
        log_warn "The patch may not have been applied correctly"
    fi
}

# Show current dataset configuration for reference
show_current_assets() {
    log_info "Current Asset configurations with datasets:"
    
    if kubectl get assets -n "$NAMESPACE" -o json | jq -r '.items[] | select(.spec.datasets | length > 0) | "Asset: \(.metadata.name) - Datasets: \([.spec.datasets[].name] | join(", "))"' 2>/dev/null; then
        log_info "Asset information displayed above"
    else
        log_warn "No assets found with datasets in namespace: $NAMESPACE"
    fi
}

# Cleanup function
cleanup() {
    rm -f /tmp/crd-datasets-patch.json
    log_info "Temporary files cleaned up"
}

# Main execution
main() {
    log_info "Starting Asset CRD amendment to allow multiple datasets..."
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Run all checks and operations
    check_prerequisites
    create_backup_dir
    check_crd_exists
    backup_crd
    create_patch
    apply_patch
    verify_patch
    show_current_assets
    
    log_info "✅ Asset CRD amendment completed successfully!"
    log_info "You can now configure multiple datasets in your Asset resources."
    log_info "Backup stored in: $BACKUP_DIR/assets-crd-backup-$TIMESTAMP.yaml"
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

This script amends the Asset CRD to allow multiple datasets in Kubernetes.
It removes the maxItems: 1 constraint from the datasets array.

Options:
    -h, --help          Show this help message
    -n, --namespace     Specify the namespace (default: azure-iot-operations)

Environment Variables:
    NAMESPACE           Override the default namespace

Examples:
    $0                                    # Use default namespace
    $0 -n my-namespace                    # Use specific namespace
    NAMESPACE=my-ns $0                    # Use environment variable

The script will:
1. Check prerequisites (kubectl, jq)
2. Backup the current CRD
3. Apply a JSON patch to remove the maxItems constraint
4. Verify the changes
5. Show current asset configurations

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main "$@"
