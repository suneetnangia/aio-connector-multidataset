namespace Aio.Multidataset.Rest.Connector;

using Azure.Iot.Operations.Connector;
using Azure.Iot.Operations.Services.Assets;
using Microsoft.Extensions.Logging;
using System.Text;
using System.Text.Json;

internal class DatasetSampler : IDatasetSampler, IAsyncDisposable
{
    private readonly ILogger<DatasetSampler> _logger;
    private readonly string _assetName;
    private readonly AssetEndpointProfileCredentials? _credentials;
    private readonly string _targetAddress;
    private readonly HttpClient _httpClient;

    public DatasetSampler(ILogger<DatasetSampler> logger, string assetName, AssetEndpointProfileCredentials? credentials, string targetAddress)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        logger.LogInformation("Instantiating data sampler instance {hashCode}", GetHashCode());

        _assetName = assetName ?? throw new ArgumentNullException(nameof(assetName));
        _credentials = credentials;
        _targetAddress = string.IsNullOrEmpty(targetAddress) ? throw new ArgumentNullException(nameof(targetAddress)) : targetAddress;
        _httpClient = new HttpClient();
    }

    public async Task<byte[]> SampleDatasetAsync(Dataset dataset, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Initiating sampling of dataset with name {datasetName} in asset with name {assetName}", dataset.Name, _assetName);

        if (dataset.DataPointsDictionary == null)
        {
            throw new InvalidOperationException($"Dataset with name {dataset.Name} in asset with name {_assetName} has no data points");
        }

        Dictionary<string, string> sampledData = [];

        foreach (string key in dataset.DataPointsDictionary.Keys)
        {
            DataPoint dataPoint = dataset.DataPointsDictionary[key];
            string dataSourceUrl = string.Format("{0}/{1}", _targetAddress.TrimEnd('/'), dataPoint.DataSource.TrimStart('/'));

            using var handler = new HttpClientHandler
            {
                ServerCertificateCustomValidationCallback = (sender, cert, chain, sslPolicyErrors) => true
            };

            using var secureHttpClient = new HttpClient(handler);

            _logger.LogInformation("Fetching data from datasource {dataSource}", dataSourceUrl);
            string responseContent;

            try
            {
                HttpResponseMessage response = await secureHttpClient.GetAsync(dataSourceUrl, cancellationToken);
                response.EnsureSuccessStatusCode();
                responseContent = await response.Content.ReadAsStringAsync(cancellationToken);
                _logger.LogInformation("Received data from datasource {dataSource}", dataSourceUrl);
            }
            catch (Exception e)
            {
                _logger.LogError("Failed to fetch data from {dataSourceUrl}: {errorMessage}", dataSourceUrl, e.Message);
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

    public ValueTask DisposeAsync()
    {
        _logger.LogInformation("Shutting down data sampler instance {0}", GetHashCode());
        Console.WriteLine("Shutting down data sampler instance {0}", GetHashCode());
        _httpClient?.Dispose();
        return ValueTask.CompletedTask;
    }
}
