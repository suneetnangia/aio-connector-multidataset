namespace Aio.Multidataset.Rest.Connector;

using Azure.Iot.Operations.Connector;
using Azure.Iot.Operations.Services.AssetAndDeviceRegistry.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

internal class DatasetSampler : IDatasetSampler, IAsyncDisposable
{
    private readonly ILogger<DatasetSampler> _logger;
    private readonly DatasetSamplerOptions _dataSamplerOptions;
    private readonly string _assetName;
    private readonly string _targetAddress;
    private readonly HttpClient _httpClient;
    private readonly JsonSerializerOptions _jsonSerializerOptions;

    public DatasetSampler(ILogger<DatasetSampler> logger, IOptions<DatasetSamplerOptions> dataSamplerOptions, string assetName, string targetAddress)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _dataSamplerOptions = dataSamplerOptions?.Value ?? new();
        _assetName = assetName ?? throw new ArgumentNullException(nameof(assetName));
        _targetAddress = string.IsNullOrEmpty(targetAddress) ? throw new ArgumentNullException(nameof(targetAddress)) : targetAddress;

        logger.LogInformation("Instantiating data sampler instance {hashCode} for asset \"{assetName}\" with target address \"{targetAddress}\" and default sampling interval of {defaultSamplingInterval} ms", GetHashCode(), assetName, targetAddress, _dataSamplerOptions.DefaultSamplingIntervalInMs);

        _httpClient = new HttpClient();

        _jsonSerializerOptions = new()
        {
            Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
        };
    }

    public async Task<byte[]> SampleDatasetAsync(AssetDataset dataset, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(dataset);
        _logger.LogDebug("Initiating sampling of dataset \"{datasetName}\" in asset \"{assetName}\"", dataset.Name, _assetName);

        if (dataset.DataPointsDictionary == null)
        {
            throw new InvalidOperationException($"Dataset \"{dataset.Name}\" in asset \"{_assetName}\" has no data points");
        }

        _logger.LogDebug("SampleDatasetAsync: Dataset \"{datasetName}\" has data points: {dataPoints}", dataset.Name, dataset.DataPointsDictionary.Keys);
        Dictionary<string, string> sampledData = [];

        foreach (string key in dataset.DataPointsDictionary.Keys)
        {
            AssetDatasetDataPointSchemaElement dataPoint = dataset.DataPointsDictionary[key];
            string? dataSource = dataPoint.DataSource;

            if (string.IsNullOrEmpty(dataSource))
            {
                _logger.LogWarning("Data point \"{dataPointName}\" in dataset \"{datasetName}\" does not have data source", key, dataset.Name);
                continue;
            }

            string dataSourceUrl = string.Format("{0}/{1}", _targetAddress.TrimEnd('/'), dataSource.TrimStart('/'));

            // SSL cert verification to be added later
            using var handler = new HttpClientHandler
            {
                ServerCertificateCustomValidationCallback = (sender, cert, chain, sslPolicyErrors) => true
            };

            using var secureHttpClient = new HttpClient(handler);

            _logger.LogInformation("Fetching data for data point \"{dataPointName}\" in dataset \"{datasetName}\" from source \"{dataSource}\"", key, dataset.Name, dataSourceUrl);
            string responseContent;

            try
            {
                HttpResponseMessage response = await secureHttpClient.GetAsync(dataSourceUrl, cancellationToken);
                response.EnsureSuccessStatusCode();
                responseContent = await response.Content.ReadAsStringAsync(cancellationToken);
                _logger.LogDebug("Received data for data point \"{dataPointName}\" in dataset \"{datasetName}\": {data}", key, dataset.Name, responseContent);
            }
            catch (Exception e)
            {
                _logger.LogError(e, "Failed to fetch data for data point \"{dataPointName}\" in dataset \"{datasetName}\" from source \"{dataSource}\": {errorMessage}", key, dataset.Name, dataSourceUrl, e.Message);
                responseContent = $"{{\"error\": \"Failed to fetch data from source {dataSourceUrl}\"}}";
            }

            var jsonResponse = new
            {
                dataSource = dataSourceUrl,
                data = responseContent,
                timestamp = DateTimeOffset.UtcNow.ToString("o")
            };

            try
            {
                sampledData.Add(key, Regex.Unescape(JsonSerializer.Serialize(jsonResponse)));
            }
            catch (NotSupportedException e)
            {
                _logger.LogError(e, "Failed to serialize response {responseContent}: {errorMessage}", responseContent, e.Message);
            }
        }

        string jsonString = Regex.Unescape(JsonSerializer.Serialize(sampledData, _jsonSerializerOptions));
        _logger.LogDebug("Returning sampled data: {jsonString}", jsonString);
        return Encoding.UTF8.GetBytes(jsonString);
    }

    /// <summary>
    /// Gets the sampling interval for the given <see cref="AssetDataset"/>.
    /// Note that the dataset can only have one sampling interval for all of its data points.
    /// </summary>
    /// <param name="dataset"></param>
    /// <param name="cancellationToken"></param>
    /// <returns></returns>
    /// <exception cref="InvalidOperationException">Thrown, if the dataset has no data points.</exception>
    public Task<TimeSpan> GetSamplingIntervalAsync(AssetDataset dataset, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Fetching sampling interval for dataset \"{datasetName}\" in asset \"{assetName}\"", dataset.Name, _assetName);

        if (dataset.DataPointsDictionary == null || dataset.DataPointsDictionary.Count == 0)
        {
            throw new InvalidOperationException($"Dataset \"{dataset.Name}\" in asset \"{_assetName}\" has no data points");
        }

        _logger.LogInformation("GetSamplingIntervalAsync: Dataset \"{datasetName}\" has data points: {dataPoints}", dataset.Name, dataset.DataPointsDictionary.Keys);
        JsonDocument? dataPointConfiguration = dataset.DataPointsDictionary.First().Value.DataPointConfiguration;
        int samplingIntervalMs = _dataSamplerOptions.DefaultSamplingIntervalInMs;

        if (dataPointConfiguration != null)
        {
            try
            {
                var rootElement = dataPointConfiguration.RootElement;

                if (rootElement.TryGetProperty("samplingInterval", out var samplingIntervalProperty))
                {
                    samplingIntervalMs = samplingIntervalProperty.GetInt32();
                }
            }
            catch (Exception e)
            {
                _logger.LogWarning(e, "Failed to parse the sampling interval for dataset \"{datasetName}\" (using default sampling interval): {errorMessage}", dataset.Name, e.Message);
            }
        }

        var samplingInterval = TimeSpan.FromMilliseconds(samplingIntervalMs);
        _logger.LogInformation("Sampling interval for dataset \"{datasetName}\" set to {samplingInterval} second(s)", dataset.Name, samplingInterval.TotalSeconds);
        return Task.FromResult(samplingInterval);
    }

    public ValueTask DisposeAsync()
    {
        _logger.LogInformation("Shutting down data sampler instance {hashCode}", GetHashCode());
        _httpClient?.Dispose();
        return ValueTask.CompletedTask;
    }
}
