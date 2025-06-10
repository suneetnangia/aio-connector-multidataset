# AIO Data Distribution Service (DDS) Connector

This repo provides the DSS messaging protocol connector for Azure IoT Operations (AIO) product. The protocol is often used on both general public vehicles or armoured vehicles in sensitive settings, for a real-time messaging.

The repo makes use of AKRI (A Kubernetes Resource Interface) framework and AIO SDKs for building the connector which is well integrated with AIO's ecosystem of services e.g. asset model.

## DDS Key Points

This section describes some of the key DDS points for connectivity purposes.

### Data Centric Pub Sub (DCPS)

OMG IDL which defines topics must be translated into code for message serialization and deserialization by publisher and subscriber. An example IDL file is provided below for reference:

```IDL
module Messenger {

  @topic
  struct Message {
    string from;
    string subject;
    @key long subject_id;
    string text;
    long count;
  };
};
```

`Key` defines the DDS instance within the same topic, each message sample with the same key is considered as a replacement value.

## General Questions for Connector Adoption

1. Does the server make use of DCPS for messaging?
2. Does the server makes use of OMG Interface Definition Language (IDL) for messaging?

## Dev Loop

Follow these steps to deploy this solution:

1. Clone repo locally and move to the solution directory

    `git clone git@github.com:suneetnangia/aio-dds-connector.git && cd aio-dds-connector`

2. Set the environment variables:

    ```sh
    export CONNECTOR_DOCKER_IMAGE_TAG="suneetnangia/aio-dds-connector:v0.8"
    export ARM_LOCATION="eastus2"
    export ARM_SUBSCRIPTION_ID="6fe459a5-48ef-46ec-a521-1d9da467ab54"
    export ARM_RESOURCE_GROUP="rg-sungia001-spike-001"
    export ARM_CUSTOM_LOCATION="arc-sungia001-spike-001-cl"
    ```

2. Build and push connector's container image

    `make`

3. Deploy AIO in Azure

    1. We use Terraform scripts to deploy AIO and its dependencies in Azure

        `/deployment/operate-all-terraform.sh`

    2. Create a `terraform.tfvars` file with at least the following minimum configuration settings:

        ```hcl
        # Required, environment hosting resource: "dev", "prod", "test", etc...
        environment     = "<environment>"
        # Required, short unique alphanumeric string: "sample123", "plantwa", "uniquestring", etc...
        resource_prefix = "<resource-prefix>"
        # Required, region location: "eastus2", "westus3", etc...
        location        = "<location>"
        # Optional, instance/replica number: "001", "002", etc...
        instance        = "<instance>"
        ```

        `./deployment/operate-all-terraform.sh --start-layer 000-subscription --end-layer 040-iot-ops`

        > Use working directory `/deployment/` when running the script

4. Deploy connector to AIO environment

    1. Create a local connection to your AIO deployment in Azure

        `az connectedk8s proxy -n <Arc Connected Cluster Above> -g $ARM_RESOURCE_GROUP`

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

1. [Open DDS](https://opendds.readthedocs.io/)
2. [Atostek RustDDS](https://github.com/Atostek/RustDDS)
3. OpenDDSSharp:
    1. [OpenDDSSharp](https://www.openddsharp.com/)
    2. [OpenDDSSharp Articles](https://www.openddsharp.com/articles/getting_started.html)
    3. [OpenDDSSharp Example](https://objectcomputing.com/resources/publications/sett/october-2020-opendds-in-a-net-application-with-openddsharp)
