#! /bin/bash
# Check if environment variables are set

ifndef DOCKER_IMAGE_TAG
$(error DOCKER_IMAGE_TAG environment variable is undefined)
endif

ifndef SUBSCRIPTION_ID
$(error SUBSCRIPTION_ID environment variable is undefined)
endif

ifndef RESOURCE_GROUP
$(error RESOURCE_GROUP environment variable is undefined)
endif

ifndef LOCATION
$(error LOCATION environment variable is undefined)
endif

ifndef CUSTOM_LOCATION
$(error CUSTOM_LOCATION environment variable is undefined)
endif

# Default target
all: publish_container

build_container:
	dotnet publish /t:PublishContainer

publish_container: build_container
	docker tag aio-dds-connector:latest suneetnangia/aio-dds-connector:latest
	docker push suneetnangia/aio-dds-connector

deploy: publish_container
	helm upgrade --install akri-operator oci://akripreview.azurecr.io/helm/microsoft-managed-akri-operator --version 0.1.5-preview --namespace "azure-iot-operations" --wait
	kubectl apply -f deployment/aio-dds-connector-config.yaml
	kubectl apply -f deployment/aio-dds-connector-aep-creds.yaml	
	./deployment/aio-dds-connector-aep.sh
	./deployment/aio-dds-connector-asset-01.sh

package:
	helm package AIO.DDS.Connector/helm/http-mqtt-connector
test:
	dotnet test AIO.DDS.Connector.Tests/AIO.DDS.Connector.Tests.csproj --configuration Release --no-build --verbosity normal

clean:
	dotnet clean AIO.DDS.Connector/AIO.DDS.Connector.csproj	
	dotnet clean AIO.DDS.Connector.Tests/AIO.DDS.Connector.Tests.csproj	

deep_clean: clean
	dotnet nuget locals all --clear