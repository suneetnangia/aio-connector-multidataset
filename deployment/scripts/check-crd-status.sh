#!/bin/bash

# Script to check current Asset CRD status and show what needs to be changed

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_header() {
    echo -e "${BLUE}[====]${NC} $1"
}

# Check if CRD exists
check_crd_exists() {
    log_header "Checking Asset CRD existence..."
    
    if kubectl get crd assets.deviceregistry.microsoft.com &> /dev/null; then
        log_info "✅ Asset CRD found: assets.deviceregistry.microsoft.com"
        return 0
    else
        log_error "❌ Asset CRD not found. Azure IoT Operations may not be installed."
        return 1
    fi
}

# Check current maxItems constraint
check_maxitems_constraint() {
    log_header "Checking datasets maxItems constraint..."
    
    local max_items
    max_items=$(kubectl get crd assets.deviceregistry.microsoft.com -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.datasets.maxItems}' 2>/dev/null || echo "")
    
    if [[ -n "$max_items" ]]; then
        log_warn "⚠️  Current maxItems constraint: $max_items"
        log_warn "This limits assets to only $max_items dataset(s)"
        echo -e "   ${YELLOW}→ Amendment needed to allow multiple datasets${NC}"
        return 1
    else
        log_info "✅ No maxItems constraint found - multiple datasets are allowed"
        return 0
    fi
}

# Show current assets and their datasets
show_current_assets() {
    log_header "Current assets and their datasets..."
    
    local assets_found=false
    
    while IFS= read -r namespace; do
        if [[ -n "$namespace" ]]; then
            local asset_count
            asset_count=$(kubectl get assets -n "$namespace" --no-headers 2>/dev/null | wc -l || echo "0")
            
            if [[ "$asset_count" -gt 0 ]]; then
                assets_found=true
                log_info "Namespace: $namespace ($asset_count asset(s))"
                
                while IFS= read -r line; do
                    if [[ -n "$line" ]]; then
                        local asset_name dataset_names dataset_count
                        asset_name=$(echo "$line" | jq -r '.metadata.name')
                        dataset_count=$(echo "$line" | jq '.spec.datasets | length' 2>/dev/null || echo "0")
                        dataset_names=$(echo "$line" | jq -r '.spec.datasets[]?.name // empty' 2>/dev/null | tr '\n' ' ' || echo "none")
                        
                        if [[ "$dataset_count" -gt 0 ]]; then
                            echo -e "  ${GREEN}•${NC} Asset: ${BLUE}$asset_name${NC} - Datasets ($dataset_count): $dataset_names"
                        else
                            echo -e "  ${YELLOW}•${NC} Asset: ${BLUE}$asset_name${NC} - No datasets configured"
                        fi
                    fi
                done < <(kubectl get assets -n "$namespace" -o json 2>/dev/null | jq -c '.items[]?' || true)
            fi
        fi
    done < <(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')
    
    if [[ "$assets_found" == "false" ]]; then
        log_warn "No assets found in any namespace"
    fi
}

# Show what the amendment will do
show_amendment_preview() {
    log_header "Amendment preview..."
    
    log_info "The amendment script will:"
    echo -e "  ${GREEN}1.${NC} Create a backup of the current Asset CRD"
    echo -e "  ${GREEN}2.${NC} Apply JSON patch to remove maxItems constraint"
    echo -e "  ${GREEN}3.${NC} Verify the changes were applied"
    echo -e "  ${GREEN}4.${NC} Show updated asset configurations"
    
    echo ""
    log_info "JSON patch that will be applied:"
    echo -e "${YELLOW}[{\"op\": \"remove\", \"path\": \"/spec/versions/0/schema/openAPIV3Schema/properties/spec/properties/datasets/maxItems\"}]${NC}"
}

# Show next steps
show_next_steps() {
    log_header "Next steps..."
    
    local max_items
    max_items=$(kubectl get crd assets.deviceregistry.microsoft.com -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.datasets.maxItems}' 2>/dev/null || echo "")
    
    if [[ -n "$max_items" ]]; then
        log_info "To allow multiple datasets, run:"
        echo -e "  ${BLUE}# Using Makefile${NC}"
        echo -e "  ${GREEN}make amend_crd${NC}"
        echo ""
        echo -e "  ${BLUE}# Or directly${NC}"
        echo -e "  ${GREEN}./deployment/scripts/amend-asset-crd-multiple-datasets.sh${NC}"
        echo ""
        echo -e "  ${BLUE}# Test the changes${NC}"
        echo -e "  ${GREEN}make test_multiple_datasets${NC}"
    else
        log_info "CRD already allows multiple datasets. You can:"
        echo -e "  ${BLUE}# Test multiple datasets functionality${NC}"
        echo -e "  ${GREEN}make test_multiple_datasets${NC}"
        echo ""
        echo -e "  ${BLUE}# Deploy your connector${NC}"
        echo -e "  ${GREEN}make deploy${NC}"
    fi
}

# Check prerequisites
check_prerequisites() {
    log_header "Checking prerequisites..."
    
    local all_good=true
    
    if command -v kubectl &> /dev/null; then
        log_info "✅ kubectl is available"
    else
        log_error "❌ kubectl not found"
        all_good=false
    fi
    
    if command -v jq &> /dev/null; then
        log_info "✅ jq is available"
    else
        log_error "❌ jq not found"
        all_good=false
    fi
    
    # Test kubectl connectivity
    if kubectl cluster-info &> /dev/null; then
        log_info "✅ kubectl can connect to cluster"
    else
        log_error "❌ kubectl cannot connect to cluster"
        all_good=false
    fi
    
    if [[ "$all_good" == "false" ]]; then
        log_error "Please fix the issues above before running the amendment script"
        return 1
    fi
    
    return 0
}

# Main function
main() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}Asset CRD Status Check${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    
    if ! check_prerequisites; then
        exit 1
    fi
    
    echo ""
    
    if ! check_crd_exists; then
        exit 1
    fi
    
    echo ""
    
    local needs_amendment=false
    if ! check_maxitems_constraint; then
        needs_amendment=true
    fi
    
    echo ""
    show_current_assets
    
    echo ""
    if [[ "$needs_amendment" == "true" ]]; then
        show_amendment_preview
    fi
    
    echo ""
    show_next_steps
    
    echo ""
    echo -e "${BLUE}================================${NC}"
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

This script checks the current Asset CRD status and shows what needs to be changed
to enable multiple datasets functionality.

Options:
    -h, --help          Show this help message

The script will check:
1. Prerequisites (kubectl, jq, cluster connectivity)
2. Asset CRD existence
3. Current maxItems constraint on datasets
4. Existing assets and their dataset configurations
5. Next steps to enable multiple datasets

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main
