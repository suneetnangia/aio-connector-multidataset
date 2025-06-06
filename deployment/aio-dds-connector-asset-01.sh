asset_configuration_json=$(jq -n --arg location "$ARM_LOCATION" --arg extendedLocation "/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/$ARM_RESOURCE_GROUP/providers/microsoft.extendedlocation/customlocations/$ARM_CUSTOM_LOCATION" '{
    "location": $location,
    "extendedLocation": {
        "type": "CustomLocation",
        "name": $extendedLocation
    },
    "properties": {
        "displayName": "Device 001",
        "description": "Device 001 with REST protocol endpoint",
        "assetEndpointProfileRef": "azure-iot-operations/device-001",
        "defaultDatasetsConfiguration": "{ \"samplingInterval\": 2000 }",
        "defaultTopic": {
            "path": "azure-iot-operations/data/device-001",
            "retain": "Keep"
        },
        "datasets": [
        {
            "name": "thermodynamics",
            "dataPoints": [
            {
                "dataSource": "/piwebapi/assetservers/F1RSCf1onAl8tkuTYgE2NfIPFQQVZFVkFQSQ/assetdatabases",
                "name": "currentAmbientTemperature",
                "dataPointConfiguration": "{}"
            }]
        },
         {
            "name": "pneumatics",
            "dataPoints": [
            {
                "dataSource": "/piwebapi/assetdatabases/F1RDCf1onAl8tkuTYgE2NfIPFQNp0AsaE7302XMsysUw2j2gQVZFVkFQSVxERUZBVUxUVVNFUkRC/elements",
                "name": "currentAmbientTemperature",
                "dataPointConfiguration": "{}"
            }]
        }
        ]
    }
}')

az rest --method put \
    --headers "Content-Type=application/json" \
    --url https://management.azure.com/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/$ARM_RESOURCE_GROUP/providers/Microsoft.DeviceRegistry/assets/device-001?api-version=2024-11-01 \
    --body "$asset_configuration_json"