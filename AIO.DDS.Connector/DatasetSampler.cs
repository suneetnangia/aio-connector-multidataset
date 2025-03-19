namespace AIO.DDS.Connector;

using OpenDDSharp;
using OpenDDSharp.DDS;
using OpenDDSharp.OpenDDS.DCPS;
using Azure.Iot.Operations.Connector;
using Azure.Iot.Operations.Services.Assets;
using System.Text;
using System.Text.Json;

internal class DatasetSampler : IDatasetSampler, IAsyncDisposable
{
    private readonly ILogger<DatasetSampler> _logger;
    private readonly string _assetName;
    private readonly AssetEndpointProfileCredentials? _credentials;
    private readonly DomainParticipantFactory _domainParticipantFactory;
    // private readonly DomainParticipant _domainParticipant;

    public DatasetSampler(ILogger<DatasetSampler> logger, string assetName, AssetEndpointProfileCredentials? credentials)
    {
        logger.LogInformation("Instantiating Data Sampler Instance {0}", this.GetHashCode());

        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _assetName = assetName ?? throw new ArgumentNullException(nameof(assetName));
        _credentials = credentials;
        
        Ace.Init();

        if (!File.Exists("rtps.ini"))
        {
            throw new FileNotFoundException("The required configuration file 'rtps.ini' is missing.");
        }

        _domainParticipantFactory = ParticipantService.Instance.GetDomainParticipantFactory(
            "-DCPSConfigFile",
            "rtps.ini",
            "-DCPSDebugLevel",
            "10",
            "-ORBLogFile",
            "LogFile.log",
            "-ORBDebugLevel",
            "10");
    }

    public async Task<byte[]> SampleDatasetAsync(Dataset dataset, CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation("Initiating sampling of dataset with name {0} in asset with name {1}", dataset.Name, _assetName);

            if (dataset.DataPointsDictionary == null)
            {
                throw new InvalidOperationException($"Dataset with name {dataset.Name} in asset with name {_assetName} has no data points");
            }

            // Get the topic from the DataPointConfiguration for DDS.
            var currentAmbientTemperatureDataPoint = dataset.DataPointsDictionary!["currentAmbientTemperature"];
            var currentAmbientTemperatureTopic = currentAmbientTemperatureDataPoint.DataSource!;

            AmbientTemperature.MessageTypeSupport support = new();
            var domainParticipant = _domainParticipantFactory.CreateParticipant(42) ?? throw new Exception("Could not create the domain participant");
            ReturnCode result = support.RegisterType(domainParticipant, support.GetTypeName());
            if (result != ReturnCode.Ok)
            {
                throw new Exception("Could not register type: " + result.ToString());
            }

            var topic = domainParticipant.CreateTopic(currentAmbientTemperatureTopic, support.GetTypeName()) ?? throw new Exception("Could not create the message topic");
            var subscriber = domainParticipant.CreateSubscriber() ?? throw new Exception("Could not create the subscriber");
            var reader = subscriber.CreateDataReader(topic) ?? throw new Exception("Could not create the message data reader");

            AmbientTemperature.MessageDataReader messageReader = new(reader);

            List<AmbientTemperature.Message> receivedData = new();
            while (true)
            {
                _logger.LogInformation("Waiting for data on Data Sampler Instance {0}", this.GetHashCode());
                var mask = messageReader.StatusChanges;
                if ((mask & StatusKind.DataAvailableStatus) != 0)
                {
                    List<SampleInfo> receivedInfo = new();
                    result = messageReader.Take(receivedData, receivedInfo);

                    if (result == ReturnCode.Ok)
                    {
                        bool messageReceived = false;
                        for (int i = 0; i < receivedData.Count; i++)
                        {
                            if (receivedInfo[i].ValidData)
                            {
                                _logger.LogInformation("Received data on Data Sampler Instance {0}: {1}", this.GetHashCode(), receivedData[i].Content);
                            }
                        }

                        if (messageReceived)
                            break;
                    }
                }

                // Wait for a while before checking again
                await Task.Delay(1000);
            }

            domainParticipant.DeleteContainedEntities();
            _domainParticipantFactory.DeleteParticipant(domainParticipant);

            var jsonString = JsonSerializer.Serialize(receivedData);
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
        ParticipantService.Instance.Shutdown();
        Ace.Fini();

        return ValueTask.CompletedTask;
    }
}
