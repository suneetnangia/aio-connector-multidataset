# AIO Data Distribution Service (DDS) Connector

This repo provides the REST protocol connector for Azure IoT Operations (AIO) product.

The repo makes use of AKRI (A Kubernetes Resource Interface) framework and AIO SDKs for building the connector which is well integrated with AIO's ecosystem of services e.g. asset model.

## Dev Loop

Follow these steps to deploy this solution:

1. Clone repo locally and move to the solution directory

    `git clone git@github.com:suneetnangia/aio-dds-connector.git && cd aio-dds-connector`

2. Set the environment variables:

    ```sh
    export CONNECTOR_DOCKER_IMAGE_TAG="suneetnangia/aio-connector-multidataset:v0.1"
    export ARM_LOCATION="eastus2"
    export ARM_SUBSCRIPTION_ID="<your subscription id>"
    export ARM_RESOURCE_GROUP="<your AIO resource group>"
    export ARM_CUSTOM_LOCATION="<your custom location>"
    ```

3. Build and push connector's container image

    `make`

4. Deploy connector to AIO environment

    1. Create a local connection to your AIO deployment in Azure

        `az connectedk8s proxy -n <Arc Connected Cluster> -g $ARM_RESOURCE_GROUP`

    2. Deploy Connector

        `make deploy`

## Multiple Datasets Support

The connector supports multiple datasets per asset (thermodynamics, pneumatics, etc.), but by default, the Asset CRD in Kubernetes limits assets to only 1 dataset. To enable multiple datasets:

### Quick Setup

```bash
# Check current CRD status
make check_crd_status

# Amend CRD to allow multiple datasets
make amend_crd

# Test multiple datasets functionality  
make test_multiple_datasets

# Full setup (amend + deploy)
make setup

# Full workflow (setup + test)
make setup_and_test
```

### Manual Process

```bash
# Check what needs to be changed
./deployment/scripts/check-crd-status.sh

# Amend the Asset CRD
./deployment/scripts/amend-asset-crd-multiple-datasets.sh

# Test the changes
./deployment/scripts/test-multiple-datasets.sh
```

### Supported Dataset Types

The `DatasetSamplerFactory` currently supports:

- `thermodynamics` - Temperature and thermal data
- `pneumatics` - Pressure and pneumatic data

### Documentation

For detailed information about multiple datasets support, see [Asset CRD Multiple Datasets Guide](docs/ASSET_CRD_MULTIPLE_DATASETS.md).

## Available Make Targets

- `make` - Build and push container image
- `make deploy` - Deploy connector to AIO
- `make check_crd_status` - Check Asset CRD status
- `make amend_crd` - Amend CRD to allow multiple datasets
- `make test_multiple_datasets` - Test multiple datasets functionality
- `make setup` - Amend CRD and deploy
- `make setup_and_test` - Full workflow with testing
- `make clean_deploy` - Clean up deployment
- `make redeploy` - Clean and redeploy

## References

...
