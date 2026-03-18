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

var storageAccountName = 'stor${replace(nameToken, '-', '')}${environment}'
var tableName = 'todos'

// Built-in role: Storage Table Data Contributor
var storageTableDataContributorRoleId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'


resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
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

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = {
  name: 'default'
  parent: storageAccount
}

resource table 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-05-01' = {
  name: tableName
  parent: tableService
}
// ── Workflow definition (echo POST body) ──
// Workflow definition loaded from separate file — edit workflow-definition.json to change Logic App behaviour.
var workflowDefinition = loadJsonContent('workflow-definition.json')

// ── Consumption Logic App workflow ──
resource workflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: {
    environment: environment
    workshop: 'logicapps-devops'
  }
  properties: {
    state: 'Enabled'
    definition: workflowDefinition
    parameters: {
      storageBaseUrl: {
        value: storageAccount.properties.primaryEndpoints.table
      }
    }
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, workflow.id, storageTableDataContributorRoleId)
  scope: storageAccount
  properties: {
    principalId: workflow.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageTableDataContributorRoleId
    )
  }
}

// Outputs
output storageAccountName string = storageAccount.name
