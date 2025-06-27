// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using Azure.Iot.Operations.Protocol;
using Azure.Iot.Operations.Services.AssetAndDeviceRegistry.Models;

namespace Azure.Iot.Operations.Connector
{
    public class StreamingTelemetryConnectorWorker : PollingTelemetryConnectorWorker
    {
        private readonly Dictionary<string, Dictionary<string, (Task, CancellationTokenSource)>> _assetsSamplingTasks = new();
        private readonly IDatasetSamplerFactory _datasetSamplerFactory;

        public StreamingTelemetryConnectorWorker(ApplicationContext applicationContext, ILogger<StreamingTelemetryConnectorWorker> logger, IMqttClient mqttClient, IDatasetSamplerFactory datasetSamplerFactory, IMessageSchemaProvider messageSchemaProvider, IAdrClientWrapper adrClientWrapper, IConnectorLeaderElectionConfigurationProvider? leaderElectionConfigurationProvider = null) : base(applicationContext, logger, mqttClient, datasetSamplerFactory, messageSchemaProvider, adrClientWrapper, leaderElectionConfigurationProvider)
        {
            base.OnAssetAvailable += OnAssetSampleableAsync;
            base.OnAssetUnavailable += OnAssetNotSampleableAsync;
            _datasetSamplerFactory = datasetSamplerFactory;
        }

        public new void OnAssetNotSampleableAsync(object? sender, AssetUnavailableEventArgs args)
        {
            if (_assetsSamplingTasks.Remove(args.AssetName, out Dictionary<string, (Task, CancellationTokenSource)>? datasetTimers) && datasetTimers != null)
            {
                foreach (string datasetName in datasetTimers.Keys)
                {
                    Task task = datasetTimers[datasetName].Item1;
                    datasetTimers[datasetName].Item2.Cancel();

                    _logger.LogInformation("Dataset \"{datasetName}\" in asset \"{assetName}\" will no longer be periodically sampled", datasetName, args.AssetName);
                    task.GetAwaiter().GetResult();
                    _logger.LogInformation("Dataset \"{datasetName}\" in asset \"{assetName}\" is completed", datasetName, args.AssetName);
                }
            }
        }

        public new void OnAssetSampleableAsync(object? sender, AssetAvailableEventArgs args)
        {
            _logger.LogInformation("Asset \"{assetName}\" is now available for sampling", args.AssetName);

            if (args.Asset.Datasets == null)
            {
                _logger.LogWarning("Asset \"{assetName}\" does not have any datasets, cancelling sampling", args.AssetName);
                return;
            }

            _logger.LogInformation("Asset \"{assetName}\" has {datasetCount} datasets", args.AssetName, args.Asset.Datasets.Count);

            // Check if the asset is already being sampled, drain the sampling tasks if it is
            if (_assetsSamplingTasks.ContainsKey(args.AssetName))
            {
                _logger.LogInformation("Asset \"{assetName}\" is already being sampled, draining the existing sampling tasks before updating config...", args.AssetName);

                foreach (var datasetName in _assetsSamplingTasks[args.AssetName].Keys)
                {
                    var task = _assetsSamplingTasks[args.AssetName][datasetName].Item1;
                    var cancellationTokenSource = _assetsSamplingTasks[args.AssetName][datasetName].Item2;

                    try
                    {
                        cancellationTokenSource.Cancel();
                        task.GetAwaiter().GetResult();
                    }
                    catch (Exception e)
                    {
                        _logger.LogError(e, "Failed to cancel sampling of asset \"{assetName}\": {errorMessage}", args.AssetName, e.Message);
                    }
                }

                _assetsSamplingTasks.Remove(args.AssetName);
            }

            _assetsSamplingTasks[args.AssetName] = new Dictionary<string, (Task, CancellationTokenSource)>();
            
            foreach (var dataset in args.Asset.Datasets)
            {
                // Use the factory method with the available parameters for the older API
                IDatasetSampler datasetSampler = _datasetSamplerFactory.CreateDatasetSampler(
                    device: new Device(), // Pass empty device for now
                    inboundEndpointName: string.Empty,
                    assetName: args.AssetName,
                    asset: args.Asset,
                    dataset: dataset,
                    endpointCredentials: null
                );

                _logger.LogInformation("Dataset \"{datasetName}\" in asset \"{assetName}\" will be sampled", dataset.Name, args.AssetName);

                // Create a timer that will start a long running timer for continuous sampling by data sampler
                var cancellationTokenSource = new CancellationTokenSource();
                var cancellationToken = cancellationTokenSource.Token;

                _assetsSamplingTasks[args.AssetName][dataset.Name] = (
                Task.Run(async () =>
                {
                    try
                    {
                        // Cancellation token is passed to the task to allow for cancellation of the long running task
                        byte[] sampledData = await datasetSampler.SampleDatasetAsync(dataset, cancellationToken);
                        await ForwardSampledDatasetAsync(args.Asset, dataset, sampledData);
                    }
                    catch (Exception e)
                    {
                        _logger.LogError(e, "Failed to sample the dataset \"{datasetName}\" in asset \"{assetName}\": {errorMessage}", dataset.Name, args.AssetName, e.Message);
                    }
                }), cancellationTokenSource);
            }
        }

        public override void Dispose()
        {
            base.Dispose();
        }
    }
}
