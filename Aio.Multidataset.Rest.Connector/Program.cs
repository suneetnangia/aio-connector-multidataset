using Aio.Multidataset.Rest.Connector;
using Azure.Iot.Operations.Connector;
using Azure.Iot.Operations.Connector.ConnectorConfigurations;
using Azure.Iot.Operations.Protocol;

string connectorClientId = Environment.GetEnvironmentVariable(ConnectorFileMountSettings.ConnectorClientIdEnvVar) ?? throw new InvalidOperationException("No MQTT client Id configured by Akri operator");

IHost host = Host.CreateDefaultBuilder(args)
    .ConfigureServices(services =>
    {
        services.ConfigureOptions<DatasetSamplerConfigureOptions>();
        services.AddSingleton<ApplicationContext>();
        services.AddSingleton(MqttSessionClientFactoryProvider.MqttSessionClientFactory);
        services.AddSingleton<IDatasetSamplerFactory, DatasetSamplerFactory>();
        services.AddSingleton(NoMessageSchemaProvider.NoMessageSchemaProviderFactory);
        services.AddSingleton<IAdrClientWrapper>((services) => new AdrClientWrapper(services.GetService<ApplicationContext>()!, services.GetService<IMqttClient>()!, connectorClientId));
        services.AddHostedService<PollingTelemetryConnectorWorker>();
    })
    .Build();

Console.WriteLine("Starting AIO Multi-Dataset Connector...");

host.Run();
