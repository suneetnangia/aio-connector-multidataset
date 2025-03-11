#! /bin/bash

#! /bin/bash

# Default target
all: publish_container

build_container:
	dotnet publish /t:PublishContainer

publish_container: build_container
	docker tag aio-dds-connector:latest suneetnangia/aio-dds-connector:latest
	docker push suneetnangia/aio-dds-connector

package:
	helm package AIO.DDS.Connector/helm/http-mqtt-connector
test:
	dotnet test AIO.DDS.Connector.Tests/AIO.DDS.Connector.Tests.csproj --configuration Release --no-build --verbosity normal

clean:
	dotnet clean AIO.DDS.Connector/AIO.DDS.Connector.csproj	
	dotnet clean AIO.DDS.Connector.Tests/AIO.DDS.Connector.Tests.csproj	

deep_clean: clean
	dotnet nuget locals all --clear