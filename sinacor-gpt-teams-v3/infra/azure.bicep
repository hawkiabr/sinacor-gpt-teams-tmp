@maxLength(46)
@minLength(4)
@description('Used to generate names for all resources in this file')
param resourceBaseName string

@description('Required when create Azure Bot service')
param botAadAppClientId string

@secure()
@description('Required by Bot Framework package in your bot project')
param botAadAppClientSecret string

@description('Used to make calls from the bot to the app backend')
param appBackendEndpoint string

param webAppSKU string

@maxLength(46)
param botDisplayName string

param appServicePlanName string = 'asp-${resourceBaseName}'
param webAppName string = 'app-${resourceBaseName}'
param botServiceName string = 'bot-${resourceBaseName}'
param storageAccountName string = replace('st${resourceBaseName}', '-', '')
param blobContainerName string = 'state'
param location string = resourceGroup().location

// create azure storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
    name: storageAccountName
    location: location
    kind: 'StorageV2'
    sku: {
        name: 'Standard_LRS'
    }
}

resource storageAccountContainerName 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = {
    name: '${storageAccountName}/default/${blobContainerName}'
    dependsOn: [
        storageAccount
    ]
}

// Compute resources for your Web App
resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
    kind: 'app'
    location: location
    name: appServicePlanName
    sku: {
        name: webAppSKU
    }
}

var blobStorageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'

// Web App that hosts your bot
resource webApp 'Microsoft.Web/sites@2021-02-01' = {
    kind: 'app'
    location: location
    name: webAppName
    properties: {
        serverFarmId: appServicePlan.id
        httpsOnly: true
        siteConfig: {
            alwaysOn: true
            appSettings: [
                {
                    name: 'WEBSITE_RUN_FROM_PACKAGE'
                    value: '1' // Run Azure App Service from a package file
                }
                {
                    name: 'WEBSITE_NODE_DEFAULT_VERSION'
                    value: '~18' // Set NodeJS version to 18.x for your site
                }
                {
                    name: 'RUNNING_ON_AZURE'
                    value: '1'
                }
                {
                    name: 'BOT_ID'
                    value: botAadAppClientId
                }
                {
                    name: 'BOT_PASSWORD'
                    value: botAadAppClientSecret
                }
                {
                    name: 'APP_BACKEND_ENDPOINT'
                    value: appBackendEndpoint
                }
                {
                    name: 'BLOB_STORAGE_CONNECTION_STRING'
                    value: blobStorageConnectionString
                }
                {
                    name: 'BLOB_STORAGE_CONTAINER_NAME'
                    value: blobContainerName
                }
            ]
            ftpsState: 'FtpsOnly'
        }
    }
}

// Register your web service as a bot with the Bot Framework
module azureBotService './botRegistration/azurebot.bicep' = {
    name: 'AzureBotService'
    params: {
        botServiceName: botServiceName
        botAadAppClientId: botAadAppClientId
        botAppDomain: webApp.properties.defaultHostName
        botDisplayName: botDisplayName
    }
}

// The output will be persisted in .env.{envName}. Visit https://aka.ms/teamsfx-actions/arm-deploy for more details.
output BOT_AZURE_APP_SERVICE_RESOURCE_ID string = webApp.id
output BOT_DOMAIN string = webApp.properties.defaultHostName
