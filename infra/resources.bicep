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

// ── Workflow definition (echo POST body) ──
// Workflow definition loaded from separate file — edit workflow-definition.json to change Logic App behaviour.
var workflowDefinition = loadJsonContent('workflow-definition.json')

// ── Consumption Logic App workflow ──
resource workflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  tags: {
    environment: environment
    workshop: 'logicapps-devops'
  }
  properties: {
    state: 'Enabled'
    definition: workflowDefinition
  }
}

// Outputs
output logicAppName string = workflow.name
