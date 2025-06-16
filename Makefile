#! /bin/bash
# Check if environment variables are set

ifndef CONNECTOR_DOCKER_IMAGE_TAG
$(error CONNECTOR_DOCKER_IMAGE_TAG environment variable is undefined)
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
	dotnet publish Aio.Multidataset.Rest.Connector/Aio.Multidataset.Rest.Connector.csproj /t:PublishContainer /p:ContainerImageTag=latest

publish_container: build_container
	docker tag aio-dds-connector:latest $(CONNECTOR_DOCKER_IMAGE_TAG)
	docker push $(CONNECTOR_DOCKER_IMAGE_TAG)

deploy: publish_container
	kubectl apply -f deployment/aio-dds-connector-config.yaml
	kubectl apply -f deployment/aio-dds-connector-aep-creds.yaml
	./deployment/aio-dds-connector-aep.sh
	./deployment/aio-dds-connector-asset-01.sh
	# kubectl apply -f deployment/aio-dds-connector-asset-01.yaml

clean_deploy:
	# TODO: clean up the deployment completely i.e. asset and aep resources as well.
	kubectl delete -f deployment/aio-dds-connector-config.yaml
	kubectl delete -f deployment/aio-dds-connector-aep-creds.yaml
	kubectl delete assets device-001 -n azure-iot-operations
	kubectl delete assetendpointprofile device-001 -n azure-iot-operations
	kubectl scale deployment device-001-deployment --replicas 0 -n azure-iot-operations
	sleep 5
	kubectl delete deployment device-001-deployment -n azure-iot-operations

redeploy: clean_deploy deploy

# Check Asset CRD status
check_crd_status:
	./deployment/scripts/check-crd-status.sh

# Amend Asset CRD to allow multiple datasets
amend_crd:
	./deployment/scripts/amend-asset-crd-multiple-datasets.sh

# Test multiple datasets functionality
test_multiple_datasets:
	./deployment/scripts/test-multiple-datasets.sh

# Full setup: amend CRD first, then deploy
setup: amend_crd deploy

# Full workflow: setup and test
setup_and_test: setup test_multiple_datasets

package:
	helm package Aio.Multidataset.Rest.Connector/helm/http-mqtt-connector

clean:
	dotnet clean Aio.Multidataset.Rest.Connector/Aio.Multidataset.Rest.Connector.csproj

deep_clean: clean
	dotnet nuget locals all --clear