asset_endpoint_profile_configuration_json=$(jq -n --arg location "$ARM_LOCATION" --arg extendedLocation "/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/$ARM_RESOURCE_GROUP/providers/microsoft.extendedlocation/customlocations/$ARM_CUSTOM_LOCATION" '{
    "location": $location,
    "extendedLocation": {
        "type": "CustomLocation",
        "name": $extendedLocation
    },
    "properties": {
        "authentication": {
            "method": "UsernamePassword",
            "usernamePasswordCredentials": {
                "usernameSecretName": "aio-dds-connector-aep-creds/username",
                "passwordSecretName": "aio-dds-connector-aep-creds/password"
            }
        },
        "discoveredAssetEndpointProfileRef": "",
        "endpointProfileType": "device-type-001",
        "targetAddress": "dds://127.0.0.1",
        "uuid": "3d83f8be-9874-4f82-8538-84b7fced7f74"
    }
}')

az rest --method put \
    --headers "Content-Type=application/json" \
    --url https://management.azure.com/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/$ARM_RESOURCE_GROUP/providers/Microsoft.DeviceRegistry/assetEndpointProfiles/device-001?api-version=2024-11-01 \
    --body "$asset_endpoint_profile_configuration_json"