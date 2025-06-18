#!/bin/bash

set -o errexit # fail if any command fails

SCRIPT_DIR=$(dirname $(readlink -f $0))

# Define versions
cert_manager_version="v1.16"
broker_version="1.0.0-dev"
adr_version="0.20.0-alpha.3"
akri_version="0.8.0-20250610.1-release"


if [ "$INSTALL_AIO" = "true" ]; then
    # ==========================================================
    echo "Installing AIO"
    # ==========================================================

    # Install Jetstack helm repository
    helm repo add jetstack https://charts.jetstack.io --force-update

    # install cert-manager
    helm upgrade cert-manager jetstack/cert-manager --install --create-namespace -n cert-manager --version $cert_manager_version --set crds.enabled=true --set fullnameOverride=aio-cert-manager --set extraArgs={--enable-certificate-owner-ref=true} --wait

    # install trust-manager
    helm upgrade trust-manager jetstack/trust-manager --install --create-namespace -n cert-manager --set nameOverride=aio-trust-manager --wait

    # install MQTT broker
    helm uninstall broker -n azure-iot-operations --ignore-not-found
    helm install broker --atomic --create-namespace -n azure-iot-operations --version $broker_version oci://mqbuilds.azurecr.io/helm/aio-broker --wait

    # output helm status
    helm list

    # Setup the broker, helm doesn't install one by default
    kubectl apply -f $SCRIPT_DIR/yaml/broker.yml
fi

if [ "$INSTALL_AKRI" = "true" ] && [ "$AKRI" = "2501" ]; then

    echo "Installing AKRI 2501"

    # install ADR
    helm uninstall adr -n azure-iot-operations --ignore-not-found
    helm install adr --version 1.0.0 oci://mcr.microsoft.com/azureiotoperations/helm/adr/assets-arc-extension

    # install Akri service, port 18883
    #The meta operator should deploy the resourceId field (currently hardcoded to "dev=adr-namesapce-res-id"), but we aren't seeing it yet. Should be removed later
    helm uninstall akri -n azure-iot-operations --ignore-not-found
    helm install akri oci://mcr.microsoft.com/azureiotoperations/helm/microsoft-managed-akri --version 0.6.1 \
        --set agent.extensionService.mqttBroker.useTls=true \
        --set agent.extensionService.mqttBroker.caCertConfigMapRef=azure-iot-operations-aio-ca-trust-bundle \
        --set agent.extensionService.mqttBroker.authenticationMethod=serviceAccountToken \
        --set agent.extensionService.mqttBroker.hostName=aio-broker \
        --set adrNamespaceRef.resourceId="dev-adr-namespace-res-id" \
        --set agent.extensionService.mqttBroker.port=18883 \
        -n azure-iot-operations

    # install the Akri operator
    helm uninstall akri-operator -n azure-iot-operations --ignore-not-found
    helm install akri-operator oci://akripreview.azurecr.io/helm/microsoft-managed-akri-operator --version 0.1.5-preview -n azure-iot-operations

elif [ "$INSTALL_AKRI" = "true" ] && [ "$AKRI" = "2504" ]; then

    # https://msazure.visualstudio.com/One/_git/akri?path=/scripts/akri-install/akri-install.sh
    echo "Installing AKRI 2504"

    # install ADR
    helm uninstall adr-crds-namespace --ignore-not-found
    helm install adr-crds-namespace oci://azureadr.azurecr.io/helm/adr/common/adr-crds-prp --version $adr_version --wait

    # Install AKRI
    # (The meta operator should deploy the resourceId field (currently hardcoded to "dev=adr-namespace-res-id"), but we aren't seeing it yet. Should be removed later)
    helm uninstall akri --ignore-not-found
    helm install akri oci://akribuilds.azurecr.io/helm/microsoft-managed-akri --version $akri_version -n azure-iot-operations \
        --set jobs.preUpgrade="false" \
        --set jobs.upgradeStatus="false" \
        --set adrNamespaceRef.resourceId="dev-adr-namespace-res-id" \
        --wait \
        --timeout 10m0s # default timeout is 5 minutes, but this has frequently timed out recently

fi