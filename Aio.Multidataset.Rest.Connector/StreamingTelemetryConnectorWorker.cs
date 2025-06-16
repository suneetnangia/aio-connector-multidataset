// Copyright(c) Microsoft Corporation.
// Licensed under the MIT License.

using Azure.Iot.Operations.Protocol;
using Azure.Iot.Operations.Services.Assets;
using System.Text.Json;

namespace Azure.Iot.Operations.Connector
{
    public class StreamingTelemetryConnectorWorker : TelemetryConnectorWorker
    {
        private readonly Dictionary<string, Dictionary<string, (Task, CancellationTokenSource)>> _assetsSamplingTasks = new();
        private readonly IDatasetSamplerFactory _datasetSamplerFactory;

        public StreamingTelemetryConnectorWorker(ApplicationContext applicationContext, ILogger<StreamingTelemetryConnectorWorker> logger, IMqttClient mqttClient, IDatasetSamplerFactory datasetSamplerFactory, IMessageSchemaProvider messageSchemaFactory, IAssetMonitor assetMonitor) : base(applicationContext, logger, mqttClient, messageSchemaFactory, assetMonitor)
        {
            base.OnAssetAvailable += OnAssetSampleableAsync;
            base.OnAssetUnavailable += OnAssetNotSampleableAsync;
            _datasetSamplerFactory = datasetSamplerFactory;
        }

        public void OnAssetNotSampleableAsync(object? sender, AssetUnavailableEventArgs args)
        {
            if (_assetsSamplingTasks.Remove(args.AssetName, out Dictionary<string, (Task, CancellationTokenSource)>? datasetTimers) && datasetTimers != null)
            {
                foreach (string datasetName in datasetTimers.Keys)
                {
                    Task task = datasetTimers[datasetName].Item1;
                    datasetTimers[datasetName].Item2.Cancel();

                    _logger.LogInformation("Dataset with name {0} in asset with name {1} will no longer be periodically sampled", datasetName, args.AssetName);
                    task.GetAwaiter().GetResult();
                    _logger.LogInformation("Dataset with name {0} in asset with name {1} is completed", datasetName, args.AssetName);
                }
            }
        }

        public void OnAssetSampleableAsync(object? sender, AssetAvailabileEventArgs args)
        {
            try
            {
            _logger.LogInformation("Asset with name {0} is now available for sampling", args.AssetName);

            if (args.Asset.Datasets == null)
            {
                 _logger.LogWarning("Asset with name {0} does not have any datasets, cancelling sampling.", args.AssetName);
                return;
            }
            else
            {
                _logger.LogInformation($"Asset with name {args.AssetName} has {args.Asset.Datasets.Count()} datasets");
            }            

            // Check if the asset is already being sampled, drain the sampling tasks if it is.
                if (_assetsSamplingTasks.ContainsKey(args.AssetName))
                {
                    _logger.LogInformation("Asset with name {0} is already being sampled, draining the existing sampling tasks before updating config...", args.AssetName);
                    foreach (var datasetName in _assetsSamplingTasks[args.AssetName].Keys)
                    {
                        var task = _assetsSamplingTasks[args.AssetName][datasetName].Item1;
                        var cancellationTokenSource = _assetsSamplingTasks[args.AssetName][datasetName].Item2;
                        cancellationTokenSource.Cancel();
                        task.GetAwaiter().GetResult();
                    }
                    _assetsSamplingTasks.Remove(args.AssetName);
                }

            _assetsSamplingTasks[args.AssetName] = new Dictionary<string, (Task, CancellationTokenSource)>();

            foreach (Dataset dataset in args.Asset.Datasets)
            {
                IDatasetSampler datasetSampler = _datasetSamplerFactory.CreateDatasetSampler(AssetEndpointProfile!, args.Asset, dataset);
                _logger.LogInformation("Dataset with name {0} in asset with name {1} will be sampled", dataset.Name, args.AssetName);

                // Create a timer that will start a long running timer for continuous sampling by data sampler.                
                var cancellationTokenSource = new CancellationTokenSource();
                var cancellationToken = cancellationTokenSource.Token;
                
                _assetsSamplingTasks[args.AssetName][dataset.Name] = (
                Task.Run(async () =>
                {
                    try
                    {
                        // Cancellation token is passed to the task to allow for cancellation of the long running task.
                        byte[] sampledData = await datasetSampler.SampleDatasetAsync(dataset, cancellationToken);
                        await ForwardSampledDatasetAsync(args.Asset, dataset, sampledData);
                    }
                    catch (Exception e)
                    {
                        _logger.LogError(e, "Failed to sample the dataset");
                    }
                }), cancellationTokenSource);
            }
            }
            catch (Exception e)
            {
                _logger.LogError(e, "Failed to sample the asset");
            }
        }

        public override void Dispose()
        {
            base.Dispose();
        }
    }
}