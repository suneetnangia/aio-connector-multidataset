namespace AIO.DDS.Connector;

using Azure.Iot.Operations.Connector;
using Azure.Iot.Operations.Services.Assets;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

internal class DatasetSampler : IDatasetSampler, IAsyncDisposable
{
    private readonly string _assetName;
    private readonly AssetEndpointProfileCredentials? _credentials;

    public DatasetSampler(string assetName, AssetEndpointProfileCredentials? credentials)
    {
        _assetName = assetName;
        _credentials = credentials;
    }

    public async Task<byte[]> SampleDatasetAsync(Dataset dataset, CancellationToken cancellationToken = default)
    {
        try
        {
            var currentAmbientTemperatureDataPoint = dataset.DataPointsDictionary!["currentAmbientTemperature"];
            var httpServerCurrentAmbientTemperatureHttpMethod = HttpMethod.Parse(currentAmbientTemperatureDataPoint.DataPointConfiguration!.RootElement.GetProperty("HttpRequestMethod").GetString());
            var httpServerCurrentAmbientTemperatureRequestPath = currentAmbientTemperatureDataPoint.DataSource!;

            if (_credentials != null)
            {
                string httpServerUsername = _credentials.Username!;
                byte[] httpServerPassword = _credentials.Password!;
            }

            // TODO: Replace mocked datapoint with actual sample from DDS here.
            var jsonString = JsonSerializer.Serialize(new
            {
                Temperature = 23.4,
                Timestamp = DateTime.UtcNow
            });

            return Encoding.UTF8.GetBytes(jsonString);
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Failed to sample dataset with name {dataset.Name} in asset with name {_assetName}", ex);
        }
    }

    public ValueTask DisposeAsync()
    {
        // TODO: Dispose of any resources if needed
        return ValueTask.CompletedTask;
    }
}
