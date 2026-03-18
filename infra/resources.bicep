// resources.bicep — Resource-group-scoped resources

@description('Short token used to build globally unique-ish names. Example: rn01')
param nameToken string

@description('Deployment environment label (dev|prod)')
@allowed([
  'dev'
  'prod'
])
param environment string

@description('Azure location for resources')
param location string

var logicAppName = 'la-${nameToken}-${environment}'
var appServicePlanName = 'asp-${nameToken}-${environment}'
var logicAppStorageName = 'stla${replace(nameToken, '-', '')}${environment}'

// ── App Service Plan (Workflow Standard) ──
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
  }
  kind: 'elastic'
  properties: {}
}

// ── Storage account for Logic App Standard runtime ──
resource logicAppStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: logicAppStorageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

// ── Standard Logic App ──
resource logicApp 'Microsoft.Web/sites@2023-12-01' = {
  name: logicAppName
  location: location
  kind: 'functionapp,workflowapp'
  tags: {
    environment: environment
    workshop: 'logicapps-devops'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        { name: 'APP_KIND', value: 'workflowApp' }
        { name: 'AzureFunctionsJobHost__extensionBundle__id', value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows' }
        { name: 'AzureFunctionsJobHost__extensionBundle__version', value: '[1.*, 2.0.0)' }
        { name: 'AzureWebJobsStorage', value: 'DefaultEndpointsProtocol=https;AccountName=${logicAppStorage.name};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${logicAppStorage.listKeys().keys[0].value}' }
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'node' }
        { name: 'WEBSITE_NODE_DEFAULT_VERSION', value: '~18' }
      ]
    }
  }
}

// Outputs
output logicAppName string = logicApp.name
