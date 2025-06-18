# Azure IoT Operations multidataset connector

This chart creates the following resources in your cluster:

* The asset and the device - the thing to monitor and collect data from
* The connector template, which e.g., defines the container image to deploy to handle the incoming data

After deploying the chart, the [Akri](https://docs.akri.sh/) operator creates a pod using the container image reference of the connector template.

## Configuration

The default values are set in `values.yaml` file. This can be overriden by providing a new values file when running [`helm install`](https://helm.sh/docs/helm/helm_install/#helm-install). Alternatively, the values can be provided separately in the command.

The custom datasets with datapoints should be provided as a YAML file. See [`sample-datasets.yaml`](https://github.com/suneetnangia/aio-connector-multidataset/blob/main/helm/aio-connector-multidataset/sample-datasets.yaml) for an example. The YAML file should not begin with `---` (three dashes) as it is directly injected inline to the asset template of this chart. To include the datasets YAML file during installation, use `--set-file` flag with [`helm install`](https://helm.sh/docs/helm/helm_install/#helm-install) command.

> **Note**
>
> To use multiple datasets - as in the sample file - you must amend the original (group: `deviceregistry.microsoft.com`, kind: `Asset`) custom resource definition (CRD) to change the value of maximum allowed datasets. This Helm chart contains the modified CRD, but Helm install command will not update it in your cluster.

## Installing/uninstalling locally

To install with default values:

```bash
helm install aio-connector-multidataset . \
  --namespace azure-iot-operations \
  --set-file datasets=sample-datasets.yaml
```

To uninstall:

```bash
helm uninstall aio-connector-multidataset --namespace azure-iot-operations
```

> The namespace is `azure-iot-operations` by default and can be omitted from the commands above.
