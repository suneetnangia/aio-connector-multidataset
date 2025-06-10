#!/bin/bash

# Test script to validate Asset CRD amendment for multiple datasets
# This script tests creating an asset with multiple datasets after the CRD is amended

set -euo pipefail

# Configuration
NAMESPACE="${NAMESPACE:-azure-iot-operations}"
TEST_ASSET_NAME="test-multi-dataset-asset"

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

# Clean up test resources
cleanup_test_asset() {
    if kubectl get asset "$TEST_ASSET_NAME" -n "$NAMESPACE" &> /dev/null; then
        log_info "Cleaning up test asset: $TEST_ASSET_NAME"
        kubectl delete asset "$TEST_ASSET_NAME" -n "$NAMESPACE"
    fi
}

# Create test asset with multiple datasets
create_test_asset() {
    log_info "Creating test asset with multiple datasets..."
    
    cat > /tmp/test-multi-dataset-asset.yaml << EOF
apiVersion: deviceregistry.microsoft.com/v1
kind: Asset
metadata:
  name: $TEST_ASSET_NAME
  namespace: $NAMESPACE
spec:
  displayName: Test Multi Dataset Asset
  description: Test asset to validate multiple datasets functionality
  assetEndpointProfileRef: $NAMESPACE/device-001
  defaultDatasetsConfiguration: |-
    {
       "samplingInterval": 2000
    }
  defaultTopic:
    path: azure-iot-operations/data/test-multi-dataset
    retain: Keep
  datasets:
    - name: thermodynamics
      datasetConfiguration: |-
        {
           "samplingInterval": 5000
        }
      dataPoints:
        - dataSource: /api/temperature
          name: currentTemperature
          dataPointConfiguration: |-
            {
               "HttpRequestMethod": "GET"
            }
        - dataSource: /api/humidity
          name: currentHumidity
          dataPointConfiguration: |-
            {
               "HttpRequestMethod": "GET"
            }
    - name: pneumatics
      datasetConfiguration: |-
        {
           "samplingInterval": 1000
        }
      dataPoints:
        - dataSource: /api/pressure
          name: currentPressure
          dataPointConfiguration: |-
            {
               "HttpRequestMethod": "GET"
            }
    - name: electrical
      datasetConfiguration: |-
        {
           "samplingInterval": 3000
        }
      dataPoints:
        - dataSource: /api/voltage
          name: currentVoltage
          dataPointConfiguration: |-
            {
               "HttpRequestMethod": "GET"
            }
        - dataSource: /api/current
          name: currentCurrent
          dataPointConfiguration: |-
            {
               "HttpRequestMethod": "GET"
            }
    - name: mechanical
      datasetConfiguration: |-
        {
           "samplingInterval": 4000
        }
      dataPoints:
        - dataSource: /api/vibration
          name: vibrationLevel
          dataPointConfiguration: |-
            {
               "HttpRequestMethod": "GET"
            }
EOF
}

# Test applying the asset
test_asset_creation() {
    log_info "Testing asset creation with multiple datasets..."
    
    if kubectl apply -f /tmp/test-multi-dataset-asset.yaml; then
        log_info "✅ Successfully created asset with multiple datasets"
        return 0
    else
        log_error "❌ Failed to create asset with multiple datasets"
        return 1
    fi
}

# Validate the asset was created correctly
validate_asset() {
    log_info "Validating asset configuration..."
    
    # Check if asset exists
    if ! kubectl get asset "$TEST_ASSET_NAME" -n "$NAMESPACE" &> /dev/null; then
        log_error "❌ Test asset not found"
        return 1
    fi
    
    # Count datasets
    local dataset_count
    dataset_count=$(kubectl get asset "$TEST_ASSET_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.datasets}' | jq '. | length' 2>/dev/null || echo "0")
    
    if [[ "$dataset_count" -ge 2 ]]; then
        log_info "✅ Asset has $dataset_count datasets (multiple datasets confirmed)"
        
        # List dataset names
        local dataset_names
        dataset_names=$(kubectl get asset "$TEST_ASSET_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.datasets[*].name}' 2>/dev/null || echo "")
        log_info "Dataset names: $dataset_names"
        
        return 0
    else
        log_error "❌ Asset only has $dataset_count dataset(s), expected multiple"
        return 1
    fi
}

# Check CRD status
check_crd_status() {
    log_info "Checking Asset CRD status..."
    
    local max_items_check
    max_items_check=$(kubectl get crd assets.deviceregistry.microsoft.com -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.datasets.maxItems}' 2>/dev/null || echo "")
    
    if [[ -z "$max_items_check" ]]; then
        log_info "✅ CRD allows multiple datasets (maxItems constraint removed)"
        return 0
    else
        log_error "❌ CRD still has maxItems constraint: $max_items_check"
        log_error "Run the amendment script first: ./amend-asset-crd-multiple-datasets.sh"
        return 1
    fi
}

# Main test function
run_test() {
    log_info "Starting Asset CRD multiple datasets test..."
    
    # Set up cleanup trap
    trap cleanup_test_asset EXIT
    
    # Check CRD status first
    if ! check_crd_status; then
        log_error "CRD is not properly amended. Exiting."
        exit 1
    fi
    
    # Clean up any existing test assets
    cleanup_test_asset
    
    # Create and test the asset
    create_test_asset
    
    if test_asset_creation && validate_asset; then
        log_info "✅ All tests passed! Multiple datasets functionality is working correctly."
        
        # Show asset details
        log_info "Final asset configuration:"
        kubectl get asset "$TEST_ASSET_NAME" -n "$NAMESPACE" -o yaml | grep -A 20 "datasets:"
        
        return 0
    else
        log_error "❌ Test failed. Check the errors above."
        return 1
    fi
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

This script tests the Asset CRD amendment for multiple datasets functionality.

Options:
    -h, --help          Show this help message
    -n, --namespace     Specify the namespace (default: azure-iot-operations)
    --keep              Keep test resources after completion (for debugging)

Environment Variables:
    NAMESPACE           Override the default namespace

Examples:
    $0                                    # Use default namespace
    $0 -n my-namespace                    # Use specific namespace
    $0 --keep                            # Keep test resources

The script will:
1. Check that the CRD has been properly amended
2. Create a test asset with multiple datasets
3. Validate that the asset was created successfully
4. Clean up test resources (unless --keep is used)

EOF
}

# Cleanup function
cleanup() {
    rm -f /tmp/test-multi-dataset-asset.yaml
}

# Parse command line arguments
KEEP_RESOURCES=false
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
        --keep)
            KEEP_RESOURCES=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Override cleanup if keep is requested
if [[ "$KEEP_RESOURCES" == "true" ]]; then
    log_info "Resources will be kept after test completion"
    trap cleanup EXIT
else
    trap 'cleanup_test_asset; cleanup' EXIT
fi

# Run the test
run_test
