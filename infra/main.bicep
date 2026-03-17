// main.bicep — Subscription-scoped entry point
// Creates the resource group, then deploys resources into it via a module.

targetScope = 'subscription'

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

var rgName = 'rg-${nameToken}-${environment}'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgName
  location: location
}

module resources 'resources.bicep' = {
  name: 'resources'
  scope: rg
  params: {
    nameToken: nameToken
    environment: environment
    location: location
  }
}

// Outputs
output resourceGroupName string = rg.name
output logicAppName string = resources.outputs.logicAppName
