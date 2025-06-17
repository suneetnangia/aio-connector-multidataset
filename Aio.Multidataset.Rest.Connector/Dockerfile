# Use the official .NET Core SDK image as the base image
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

# Set the working directory inside the container
WORKDIR /app

# Copy the project files to the container
COPY . .

# Clear all NuGet caches
RUN dotnet nuget locals all --clear

# Add the Azure DevOps NuGet source for the IoT Operations packages
RUN dotnet nuget add source https://pkgs.dev.azure.com/azure-iot-sdks/iot-operations/_packaging/preview/nuget/v3/index.json --name "Azure IoT Operations"

# Restore dependencies
RUN dotnet restore Aio.Multidataset.Rest.Connector/Aio.Multidataset.Rest.Connector.csproj

# Build the project
RUN dotnet build Aio.Multidataset.Rest.Connector/Aio.Multidataset.Rest.Connector.csproj -c Release -o out

# Use the official .NET Core Runtime image as the base image
FROM mcr.microsoft.com/dotnet/runtime:9.0 AS runtime

# Set the working directory inside the container
WORKDIR /app

# Copy the published output from the build stage to the runtime stage
COPY --from=build /app/out .

# Set the entry point for the container
ENTRYPOINT ["dotnet", "Aio.Multidataset.Rest.Connector.dll"]