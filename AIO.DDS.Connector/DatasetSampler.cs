namespace AIO.DDS.Connector;

using Azure.Iot.Operations.Connector;
using Azure.Iot.Operations.Services.Assets;
using System.Text;
using System.Text.Json;

internal class DatasetSampler : IDatasetSampler, IAsyncDisposable
{
    private readonly ILogger<DatasetSampler> _logger;
    private readonly string _assetName;
    private readonly AssetEndpointProfileCredentials? _credentials;
    private readonly string? _targetAddress;
    private readonly HttpClient _httpClient;

    public DatasetSampler(ILogger<DatasetSampler> logger, string assetName, AssetEndpointProfileCredentials? credentials, string? targetAddress)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        logger.LogInformation("Instantiating Data Sampler Instance {0}", this.GetHashCode());

        _assetName = assetName ?? throw new ArgumentNullException(nameof(assetName));
        _credentials = credentials;
        _targetAddress = targetAddress;
        _httpClient = new HttpClient();
    }

    public async Task<byte[]> SampleDatasetAsync(Dataset dataset, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Initiating sampling of dataset with name {0} in asset with name {1}", dataset.Name, _assetName);

            if (dataset.DataPointsDictionary == null)
            {
                throw new InvalidOperationException($"Dataset with name {dataset.Name} in asset with name {_assetName} has no data points");
            }

            // Get the data source URL from the DataPointConfiguration.
            var currentAmbientTemperatureDataPoint = dataset.DataPointsDictionary!["currentAmbientTemperature"];
            var dataSourceUrl = currentAmbientTemperatureDataPoint.DataSource!;

            _logger.LogInformation("Fetching data from HTTP endpoint: {0}", dataSourceUrl);

            // Make HTTP request to fetch actual data
            string httpData;
            try
            {
                // Use the target address from the asset endpoint profile
                if (string.IsNullOrEmpty(_targetAddress))
                {
                    throw new InvalidOperationException("Target address is not configured in the asset endpoint profile");
                }
                
                var fullUrl = _targetAddress.TrimEnd('/') + dataSourceUrl;
                // Configure HttpClient to ignore SSL validation
                using var handler = new HttpClientHandler
                {
                    ServerCertificateCustomValidationCallback = (sender, cert, chain, sslPolicyErrors) => true
                };
                using var secureHttpClient = new HttpClient(handler);
                _logger.LogInformation("Making HTTP request to: {0}", fullUrl);
                var response = await secureHttpClient.GetAsync(fullUrl, cancellationToken);
                response.EnsureSuccessStatusCode();
                httpData = await response.Content.ReadAsStringAsync(cancellationToken);
                
                _logger.LogInformation("Successfully fetched data from HTTP endpoint");
            }
            catch (Exception httpEx)
            {
                _logger.LogError(httpEx, "Failed to fetch data from HTTP endpoint {0}", dataSourceUrl);
                // Return error information instead of crashing
                httpData = $"{{\"error\": \"Failed to fetch data from {dataSourceUrl}\", \"message\": \"{httpEx.Message}\"}}";
            }
            
            // Create JSON response with the actual fetched data
            var jsonResponse = new
            {
                currentAmbientTemperature = new
                {
                    dataSource = dataSourceUrl,
                    data = httpData,
                    timestamp = DateTimeOffset.UtcNow.ToString("o")
                }
            };
            
            var jsonString = JsonSerializer.Serialize(jsonResponse);
            _logger.LogInformation("Returning sampled data: {0}", jsonString);
            
            return Encoding.UTF8.GetBytes(jsonString);
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Failed to sample dataset with name {dataset.Name} in asset with name {_assetName}", ex);
        }
    }

    public ValueTask DisposeAsync()
    {
        Console.WriteLine("Shutting down DDS DatasetSampler.");
        _httpClient?.Dispose();
        return ValueTask.CompletedTask;
    }
}
