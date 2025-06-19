// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using Azure.Iot.Operations.Connector;
using Azure.Iot.Operations.Connector.Assets;
using Azure.Iot.Operations.Services.AssetAndDeviceRegistry.Models;

namespace Aio.Multidataset.Rest.Connector
{
    public class DatasetSamplerFactory : IDatasetSamplerFactory
    {   
        public static Func<IServiceProvider, IDatasetSamplerFactory> DatasetSourceFactoryProvider = service =>
        {
            return new DatasetSamplerFactory();
        };
        
        /// <summary>
        /// Creates a dataset sampler for the given dataset.
        /// </summary>
        /// <param name="device">The device that the dataset sampler will sample from.</param>
        /// <param name="inboundEndpointName">The name of the inbound endpoint.</param>
        /// <param name="assetName">The name of the asset.</param>
        /// <param name="asset">The asset that the dataset sampler will sample from.</param>
        /// <param name="dataset">The dataset that a sampler is needed for.</param>
        /// <param name="endpointCredentials">The credentials for the endpoint.</param>
        /// <returns>The dataset sampler for the provided dataset.</returns>
        public IDatasetSampler CreateDatasetSampler(Device device, string inboundEndpointName, string assetName, Asset asset, AssetDataset dataset, EndpointCredentials? endpointCredentials)
        {
            // Use the target address from the deployment configuration
            // Based on the deployment YAML, the device endpoint should have address: "https://11.0.0.4:443"
#pragma warning disable CS8602 // Dereference of a possibly null reference.
            bool? success = device.Endpoints.Inbound.TryGetValue(inboundEndpointName, out var inboundEndpoint);
#pragma warning restore CS8602 // Dereference of a possibly null reference.

            if (success == null || success == false || inboundEndpoint == null)
            {
                throw new InvalidOperationException($"Failed to get the device inbound endpoint for asset \"{assetName}\"");
            }

            Console.WriteLine($"Creating DatasetSampler for asset \"{assetName}\" with endpoint \"{inboundEndpointName}\", target address \"{inboundEndpoint.Address}\" and dataset \"{dataset.Name}\"");

            // Create a logger using a simple factory pattern
            var loggerFactory = LoggerFactory.Create(builder => builder.AddConsole());
            var logger = loggerFactory.CreateLogger<DatasetSampler>();

            // Return a dataset sampler for the provided asset + dataset
            // Use the assetName parameter instead of asset.DisplayName which can be null
            return new DatasetSampler(logger, assetName, inboundEndpoint!.Address);
        }
    }
}
