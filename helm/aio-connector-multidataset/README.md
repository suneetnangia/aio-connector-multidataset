# Azure IoT Operations multidataset connector

This chart creates the following resources in your cluster:

* The asset and the device - the thing to monitor and collect data from
* The connector template, which e.g., defines the container image to deploy to handle the incoming data

After deploying the chart, the [Akri](https://docs.akri.sh/) operator creates a pod using the container image reference of the connector template.

## Configuration

The default values are set in `values.yaml` file. This can be overriden by providing a new values file when running [`helm install`](https://helm.sh/docs/helm/helm_install/#helm-install). Alternatively, the values can be provided separately in the command.

The custom datasets with datapoints should be provided as a YAML file. See [`sample-datasets.yaml`](https://github.com/suneetnangia/aio-connector-multidataset/blob/main/helm/aio-connector-multidataset/sample-datasets.yaml) for an example. The YAML file should not begin with `---` (three dashes) as it is directly injected inline to the asset template of this chart. To include the datasets YAML file during installation, use `--set-file` flag with [`helm install`](https://helm.sh/docs/helm/helm_install/#helm-install) command.

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

## Inspecting CRDs

As of writing this, the connector related custom resource definitions (CRDs) are still being developed and online documentation is slim to none. To inspect the CRD schema e.g., to see how the assets are configured, you can use the `kubectl` tool:

To list all CRDs:

```bash
kubectl get crd
```

To list Microsoft specific ones:

```bash
kubectl get crd | grep microsoft
```

Once you find the name of the CRD you want to inspect further, you can dump it in a file, for example:

```bash
kubectl get crd assets.namespaces.deviceregistry.microsoft.com --output yaml > assets.namespaces.deviceregistry.microsoft.com.yaml
```
