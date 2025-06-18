namespace Aio.Multidataset.Rest.Connector;

using Azure.Iot.Operations.Connector;
using Azure.Iot.Operations.Services.AssetAndDeviceRegistry.Models;
using Microsoft.Extensions.Logging;
using System.Text;
using System.Text.Json;

internal class DatasetSampler : IDatasetSampler, IAsyncDisposable
{
    private readonly ILogger<DatasetSampler> _logger;
    private readonly string _assetName;
    private readonly string _targetAddress;
    private readonly HttpClient _httpClient;

    public DatasetSampler(ILogger<DatasetSampler> logger, string assetName, string targetAddress)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        logger.LogInformation("Instantiating data sampler instance {hashCode}", GetHashCode());

        _assetName = assetName ?? throw new ArgumentNullException(nameof(assetName));
        _targetAddress = string.IsNullOrEmpty(targetAddress) ? throw new ArgumentNullException(nameof(targetAddress)) : targetAddress;
        _httpClient = new HttpClient();
    }

    public async Task<byte[]> SampleDatasetAsync(AssetDataset dataset, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Initiating sampling of dataset with name {datasetName} in asset with name {assetName}", dataset.Name, _assetName);

        if (dataset.DataPointsDictionary == null)
        {
            throw new InvalidOperationException($"Dataset with name {dataset.Name} in asset with name {_assetName} has no data points");
        }

        Dictionary<string, string> sampledData = [];

        foreach (string key in dataset.DataPointsDictionary.Keys)
        {
            AssetDatasetDataPointSchemaElement dataPoint = dataset.DataPointsDictionary[key];
            string? dataSource = dataPoint.DataSource;

            if (string.IsNullOrEmpty(dataSource))
            {
                _logger.LogWarning("Data point {dataPointName} in dataset {datasetName} does not have data source", key, dataset.Name);
                continue;
            }

            string dataSourceUrl = string.Format("{0}/{1}", _targetAddress.TrimEnd('/'), dataSource.TrimStart('/'));

            using var handler = new HttpClientHandler
            {
                ServerCertificateCustomValidationCallback = (sender, cert, chain, sslPolicyErrors) => true
            };

            using var secureHttpClient = new HttpClient(handler);

            _logger.LogInformation("Fetching data for data point {dataPointName} in dataset {datasetName} from source {dataSource}", key, dataset.Name, dataSourceUrl);
            string responseContent;

            try
            {
                HttpResponseMessage response = await secureHttpClient.GetAsync(dataSourceUrl, cancellationToken);
                response.EnsureSuccessStatusCode();
                responseContent = await response.Content.ReadAsStringAsync(cancellationToken);
                _logger.LogInformation("Received data for data point {dataPointName} in dataset {datasetName}", key, dataset.Name);
            }
            catch (Exception e)
            {
                _logger.LogError("Failed to fetch data for data point {dataPointName} in dataset {datasetName} from source {dataSource}: {errorMessage}", key, dataset.Name, dataSourceUrl, e.Message);
                responseContent = $"{{\"error\": \"Failed to fetch data from {dataSourceUrl}\", \"message\": \"{e.Message}\"}}";
            }

            var jsonResponse = new
            {
                dataSource = dataSourceUrl,
                data = responseContent,
                timestamp = DateTimeOffset.UtcNow.ToString("o")
            };

            try
            {
                sampledData.Add(key, JsonSerializer.Serialize(jsonResponse));
            }
            catch (NotSupportedException e)
            {
                _logger.LogError("Failed to serialize response {responseContent}: {errorMessage}", responseContent, e.Message);
            }
        }

        string jsonString = JsonSerializer.Serialize(sampledData);
        _logger.LogInformation("Returning sampled data: {jsonString}", jsonString);
        return Encoding.UTF8.GetBytes(jsonString);
    }

    public Task<TimeSpan> GetSamplingIntervalAsync(AssetDataset dataset, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Fetching sampling interval for dataset with name {datasetName} in asset with name {assetName}", dataset.Name, _assetName);

            // Parse the DataPointConfiguration JSON to extract samplingInterval
            var dataPointConfig = dataset.DataPointsDictionary?["genericDataPoint"]?.DataPointConfiguration;
            int samplingIntervalMs = 5000; // Default to 5 seconds if not found

            if (dataPointConfig != null)
            {
                try
                {
                    var rootElement = dataPointConfig.RootElement;
                    if (rootElement.TryGetProperty("samplingInterval", out var samplingIntervalProperty))
                    {
                        samplingIntervalMs = samplingIntervalProperty.GetInt32();
                    }
                }
                catch (Exception jsonEx)
                {
                    _logger.LogWarning(jsonEx, "Failed to parse DataPointConfiguration JSON, using default sampling interval");
                }
            }

            var samplingInterval = TimeSpan.FromMilliseconds(samplingIntervalMs);
            _logger.LogInformation("Sampling interval for dataset {datasetName} is {samplingInterval} seconds", dataset.Name, samplingInterval.TotalSeconds);

            return Task.FromResult(samplingInterval);
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Failed to get sampling interval for dataset with name {dataset.Name} in asset with name {_assetName}", ex);
        }
    }

    public ValueTask DisposeAsync()
    {
        _logger.LogInformation("Shutting down data sampler instance {0}", GetHashCode());
        Console.WriteLine("Shutting down data sampler instance {0}", GetHashCode());
        _httpClient?.Dispose();
        return ValueTask.CompletedTask;
    }
}
