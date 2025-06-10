# Asset CRD Multiple Datasets Amendment

This guide explains how to amend the Asset Custom Resource Definition (CRD) in Kubernetes to allow multiple datasets per asset, which is currently limited to 1 dataset.

## Problem

The current Asset CRD has a constraint `maxItems: 1` on the `datasets` array, which prevents assets from having multiple datasets. However, your DatasetSamplerFactory code and asset configurations already support multiple datasets (thermodynamics, pneumatics, etc.).

## Solution

Use the provided shell script to remove the `maxItems: 1` constraint from the Asset CRD.

## Quick Start

### Option 1: Using Makefile (Recommended)

```bash
# Amend the CRD only
make amend_crd

# Full setup: amend CRD + deploy
make setup

# Full workflow: setup + test
make setup_and_test

# Test multiple datasets functionality
make test_multiple_datasets
```

### Option 2: Using Scripts Directly

```bash
# Amend the Asset CRD
./deployment/scripts/amend-asset-crd-multiple-datasets.sh

# Test the changes
./deployment/scripts/test-multiple-datasets.sh

# With custom namespace
./deployment/scripts/amend-asset-crd-multiple-datasets.sh -n my-namespace
```

## What the Amendment Does

1. **Backs up** the current Asset CRD to `crd-backups/` with timestamp
2. **Applies a JSON patch** to remove `maxItems: 1` constraint from datasets array
3. **Verifies** the change was applied successfully
4. **Shows** current asset configurations for reference

## Files Created/Modified

- `deployment/scripts/amend-asset-crd-multiple-datasets.sh` - Main amendment script
- `deployment/scripts/test-multiple-datasets.sh` - Test script
- `deployment/scripts/README.md` - Script documentation
- `crd-datasets-json-patch.json` - JSON patch definition
- `crd-backups/` - Directory for CRD backups
- `Makefile` - Added new targets

## Script Features

### amend-asset-crd-multiple-datasets.sh
- ✅ Prerequisites checking (kubectl, jq)
- ✅ Automatic backup with timestamps
- ✅ JSON patch application
- ✅ Verification of changes
- ✅ Colored output and logging
- ✅ Error handling and cleanup
- ✅ Help documentation

### test-multiple-datasets.sh
- ✅ CRD status validation
- ✅ Creates test asset with 4 datasets
- ✅ Validates asset creation
- ✅ Automatic cleanup
- ✅ Keep resources option for debugging

## Example Asset with Multiple Datasets

After amendment, you can create assets like this:

```yaml
apiVersion: deviceregistry.microsoft.com/v1
kind: Asset
metadata:
  name: multi-dataset-device
spec:
  displayName: Multi Dataset Device
  assetEndpointProfileRef: azure-iot-operations/device-001
  datasets:
    - name: thermodynamics
      dataPoints:
        - dataSource: /api/temperature
          name: currentTemperature
    - name: pneumatics
      dataPoints:
        - dataSource: /api/pressure
          name: currentPressure
    - name: electrical
      dataPoints:
        - dataSource: /api/voltage
          name: currentVoltage
    - name: mechanical
      dataPoints:
        - dataSource: /api/vibration
          name: vibrationLevel
```

## Verification

After running the script, verify the changes:

```bash
# Check that maxItems constraint is removed
kubectl get crd assets.deviceregistry.microsoft.com -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.datasets.maxItems}'
# Should return empty (no output)

# Check existing assets
kubectl get assets -n azure-iot-operations -o yaml
```

## Rollback (if needed)

If you need to restore the original CRD:

```bash
# Find your backup
ls crd-backups/

# Restore from backup
kubectl apply -f crd-backups/assets-crd-backup-<timestamp>.yaml
```

## Troubleshooting

### Common Issues

1. **Permission denied**: Ensure you have cluster-admin or CRD modification permissions
2. **CRD not found**: Ensure Azure IoT Operations is installed
3. **kubectl not found**: Install kubectl CLI
4. **jq not found**: Install jq for JSON processing

### Debug Commands

```bash
# Check CRD status
kubectl get crd assets.deviceregistry.microsoft.com

# Check current datasets constraint
kubectl get crd assets.deviceregistry.microsoft.com -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.datasets}'

# Check existing assets
kubectl get assets -A

# View script logs in detail
./deployment/scripts/amend-asset-crd-multiple-datasets.sh -v
```

## Integration with DatasetSamplerFactory

Your `DatasetSamplerFactory.cs` already supports multiple dataset types:
- `thermodynamics`
- `pneumatics`

After the CRD amendment, assets can be configured with both datasets simultaneously, and the factory will create appropriate samplers for each.

## Next Steps

1. Run the amendment script
2. Test with the provided test script
3. Update your asset configurations to use multiple datasets
4. Deploy and verify the connector works with multiple datasets
5. Monitor logs to ensure all datasets are being sampled correctly
