asset_configuration_json=$(jq -n --arg location "$LOCATION" --arg extendedLocation "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/microsoft.extendedlocation/customlocations/$CUSTOM_LOCATION" '{
    "location": $location,
    "extendedLocation": {
        "type": "CustomLocation",
        "name": $extendedLocation
    },
    "properties": {
        "displayName": "Device 001",
        "description": "Device 001 with DDS protocol endpoint",
        "assetEndpointProfileRef": "azure-iot-operations/device-001",
        "defaultDatasetsConfiguration": "{ \"samplingInterval\": 4000 }",
        "defaultTopic": {
            "path": "azure-iot-operations/data/device-001",
            "retain": "Keep"
        },
        "datasets": [
        {
            "name": "thermodynamics",
            "dataPoints": [
            {
                "dataSource": "/ambient",
                "name": "ambientTemperature",
                "dataPointConfiguration": "{}",
            }]
        }]
    }
}')

az rest --method put \
    --headers "Content-Type=application/json" \
    --url https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DeviceRegistry/assets/device-001?api-version=2024-11-01 \
    --body "$asset_configuration_json"