# Use the official .NET Core SDK image as the base image
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

# Set the working directory inside the container
WORKDIR /app

# Copy the project files to the container
COPY . .

# Clear NuGet cache to prevent corrupted package issues
RUN dotnet nuget locals all --clear

# Build and publish the project
RUN dotnet publish Aio.Multidataset.Rest.Connector/Aio.Multidataset.Rest.Connector.csproj -c Release -o out

# Use the official .NET Core Runtime image as the base image
FROM mcr.microsoft.com/dotnet/runtime:9.0 AS runtime

# Set the working directory inside the container
WORKDIR /app

# Copy the published output from the build stage to the runtime stage
COPY --from=build /app/out .

# Set the entry point for the container
ENTRYPOINT ["dotnet", "Aio.Multidataset.Rest.Connector.dll"]