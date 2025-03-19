#! /bin/bash
# Check if environment variables are set

ifndef CONNECTOR_DOCKER_IMAGE_TAG
$(error CONNECTOR_DOCKER_IMAGE_TAG environment variable is undefined)
endif

ifndef PUBLISHER_DOCKER_IMAGE_TAG
$(error PUBLISHER_DOCKER_IMAGE_TAG environment variable is undefined)
endif

ifndef ARM_SUBSCRIPTION_ID
$(error SUBSCRIPTION_ID environment variable is undefined)
endif

ifndef ARM_RESOURCE_GROUP
$(error RESOURCE_GROUP environment variable is undefined)
endif

ifndef ARM_LOCATION
$(error LOCATION environment variable is undefined)
endif

ifndef ARM_CUSTOM_LOCATION
$(error CUSTOM_LOCATION environment variable is undefined)
endif

# Default target
all: publish_container

build_container:
	dotnet publish AIO.DDS.Connector/AIO.DDS.Connector.csproj /t:PublishContainer /p:ContainerImageTag=latest
	dotnet publish AIO.DDS.Publisher/AIO.DDS.Publisher.csproj /t:PublishContainer /p:ContainerImageTag=latest

publish_container: build_container
	docker tag aio-dds-connector:latest $(CONNECTOR_DOCKER_IMAGE_TAG)
	docker tag aio-dds-publisher:latest $(PUBLISHER_DOCKER_IMAGE_TAG)
	docker push $(CONNECTOR_DOCKER_IMAGE_TAG)	
	docker push $(PUBLISHER_DOCKER_IMAGE_TAG)

deploy: publish_container
	helm upgrade --install akri-operator oci://akripreview.azurecr.io/helm/microsoft-managed-akri-operator --version 0.1.5-preview --namespace "azure-iot-operations" --wait
	kubectl apply -f deployment/aio-dds-publisher.yaml
	kubectl apply -f deployment/aio-dds-connector-config.yaml
	kubectl apply -f deployment/aio-dds-connector-aep-creds.yaml	
	./deployment/aio-dds-connector-aep.sh
	./deployment/aio-dds-connector-asset-01.sh

clean_deploy:
	# TODO: clean up the deployment completely i.e. asset and aep resources as well.
	kubectl delete -f deployment/aio-dds-connector-config.yaml
	kubectl delete -f deployment/aio-dds-connector-aep-creds.yaml	
	kubectl delete -f deployment/aio-dds-publisher.yaml
	sleep 5

redeploy: clean_deploy deploy	

package:
	helm package AIO.DDS.Connector/helm/http-mqtt-connector
test:
	dotnet test AIO.DDS.Connector.Tests/AIO.DDS.Connector.Tests.csproj --configuration Release --no-build --verbosity normal

clean:
	dotnet clean AIO.DDS.Connector/AIO.DDS.Connector.csproj
	dotnet clean AIO.DDS.Connector/AIO.DDS.Publisher.csproj
	dotnet clean AIO.DDS.Connector.Tests/AIO.DDS.Connector.Tests.csproj	

deep_clean: clean
	dotnet nuget locals all --clear