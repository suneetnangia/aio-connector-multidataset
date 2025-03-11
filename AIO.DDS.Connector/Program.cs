using AIO.DDS.Connector;

using Azure.Iot.Operations.Connector;
using Azure.Iot.Operations.Protocol;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection;

IHost host = Host.CreateDefaultBuilder(args)
    .ConfigureServices(services =>
    {
        services.AddSingleton<ApplicationContext>();
        services.AddSingleton(MqttSessionClientFactoryProvider.MqttSessionClientFactory);
        services.AddSingleton(DatasetSamplerFactory.RestDatasetSourceFactoryProvider);
        services.AddSingleton(NoMessageSchemaProvider.NoMessageSchemaProviderFactory);
        services.AddSingleton(AssetMonitorFactoryProvider.AssetMonitorFactory);
        services.AddHostedService<PollingTelemetryConnectorWorker>();
    })
    .Build();

host.Run();