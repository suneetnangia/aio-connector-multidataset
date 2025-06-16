namespace Aio.Multidataset.Rest.Connector;

using Azure.Iot.Operations.Connector;
using Azure.Iot.Operations.Services.Assets;

public class DatasetSamplerFactory : IDatasetSamplerFactory
{
    private static ILogger<DatasetSampler>? _logger;

    public static Func<IServiceProvider, IDatasetSamplerFactory> DatasetSourceFactoryProvider = service =>
    {
        _logger = service.GetRequiredService<ILogger<DatasetSampler>>();
        return new DatasetSamplerFactory();
    };

    /// <summary>
    /// Creates a dataset sampler for the given dataset.
    /// </summary>
    /// <param name="assetEndpointProfile">The asset endpoint profile to connect to when sampling this dataset.</param>
    /// <param name="asset">The asset that the dataset sampler will sample from.</param>
    /// <param name="dataset">The dataset that a sampler is needed for.</param>
    /// <returns>The dataset sampler for the provided dataset.</returns>
    public IDatasetSampler CreateDatasetSampler(AssetEndpointProfile assetEndpointProfile, Asset asset, Dataset dataset)
    {
        ArgumentNullException.ThrowIfNull(_logger);
        ArgumentNullException.ThrowIfNull(assetEndpointProfile);
        ArgumentNullException.ThrowIfNull(asset);
        ArgumentNullException.ThrowIfNull(dataset);

        // Make dataset name configurable
        if (dataset.Name.Equals("thermodynamics"))
        {
            _logger.LogInformation("Creating DatasetSampler for thermodynamics dataset on asset {AssetName}", asset.DisplayName);
            return new DatasetSampler(_logger, asset.DisplayName!, assetEndpointProfile.Credentials, assetEndpointProfile.TargetAddress);
        }
        else if (dataset.Name.Equals("pneumatics"))
        {
            _logger.LogInformation("Creating DatasetSampler for pneumatics dataset on asset {AssetName}", asset.DisplayName);
            return new DatasetSampler(_logger, asset.DisplayName!, assetEndpointProfile.Credentials, assetEndpointProfile.TargetAddress);
        }
        else
        {
            throw new InvalidOperationException($"Unrecognized dataset with name {dataset.Name} on asset with name {asset.DisplayName}");
        }
    }
}
