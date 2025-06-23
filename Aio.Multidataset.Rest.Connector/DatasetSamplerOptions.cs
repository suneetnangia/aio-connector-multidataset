using Microsoft.Extensions.Options;

namespace Aio.Multidataset.Rest.Connector;

public class DatasetSamplerOptions
{
    public int DefaultSamplingIntervalInMs { get; set; } = 5000;
}

public class DatasetSamplerConfigureOptions : IConfigureOptions<DatasetSamplerOptions>
{
    private const string DatasetSamplerSectionName = "DatasetSampler";
    private readonly IConfiguration _configuration;

    public DatasetSamplerConfigureOptions(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public void Configure(DatasetSamplerOptions options)
    {
        _configuration.GetSection(DatasetSamplerSectionName).Bind(options);
    }
}
