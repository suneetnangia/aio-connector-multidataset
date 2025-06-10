# CRD Amendment Scripts

This directory contains scripts for modifying Custom Resource Definitions (CRDs) in the Azure IoT Operations environment.

## Scripts

### amend-asset-crd-multiple-datasets.sh

**Purpose**: Amends the Asset CRD to allow multiple datasets by removing the `maxItems: 1` constraint.

**Usage**:
```bash
# Use default namespace (azure-iot-operations)
./amend-asset-crd-multiple-datasets.sh

# Use specific namespace
./amend-asset-crd-multiple-datasets.sh -n my-namespace

# Show help
./amend-asset-crd-multiple-datasets.sh --help
```

**Prerequisites**:
- `kubectl` installed and configured
- `jq` installed for JSON processing
- Proper access to the Kubernetes cluster
- Azure IoT Operations installed

**What it does**:
1. Creates a backup of the current Asset CRD
2. Applies a JSON patch to remove the `maxItems: 1` constraint from the datasets array
3. Verifies the changes were applied successfully
4. Shows current asset configurations

**Safety features**:
- Creates timestamped backups before making changes
- Validates prerequisites before execution
- Provides detailed logging and error handling
- Cleanup of temporary files

**Backup location**: `../crd-backups/assets-crd-backup-<timestamp>.yaml`

## Important Notes

- Always test in a development environment first
- Keep backups of your CRDs before making changes
- Verify that existing assets still function after the amendment
- The script is idempotent - it can be run multiple times safely

## Troubleshooting

If the script fails:
1. Check that you have proper permissions to modify CRDs
2. Ensure Azure IoT Operations is properly installed
3. Verify kubectl is configured for the correct cluster
4. Check the logs for specific error messages

To restore from backup if needed:
```bash
kubectl apply -f ../crd-backups/assets-crd-backup-<timestamp>.yaml
```
