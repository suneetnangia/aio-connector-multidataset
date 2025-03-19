using AIO.DDS.Connector;

using Azure.Iot.Operations.Connector;
using Azure.Iot.Operations.Protocol;

IHost host = Host.CreateDefaultBuilder(args)
    .ConfigureServices(services =>
    {
        services.AddSingleton<ApplicationContext>();
        services.AddSingleton(MqttSessionClientFactoryProvider.MqttSessionClientFactory);
        services.AddSingleton(DatasetSamplerFactory.DatasetSourceFactoryProvider);
        services.AddSingleton(NoMessageSchemaProvider.NoMessageSchemaProviderFactory);
        services.AddSingleton(AssetMonitorFactoryProvider.AssetMonitorFactory);
        services.AddHostedService<StreamingTelemetryConnectorWorker>();
    })
    .Build();

host.Run();