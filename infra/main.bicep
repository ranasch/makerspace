// main.bicep — Workshop infrastructure
// Deploys: Resource Group contents: Log Analytics workspace, Consumption Logic App workflow, diagnostic settings.

targetScope = 'resourceGroup'

@description('Short token used to build globally unique-ish names. Example: rn01')
param nameToken string

@description('Deployment environment label (dev|prod)')
@allowed([
  'dev'
  'prod'
])
param environment string

@description('Azure location for resources')
param location string = resourceGroup().location

@description('Upstream URL called by the workflow HTTP action')
param upstreamUrl string

// Names
var laWorkspaceName = 'law-${nameToken}-${environment}'
var logicAppName = 'la-${nameToken}-${environment}'
var diagName = 'diag-${logicAppName}'

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: laWorkspaceName
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

// Consumption Logic App workflow (multi-tenant)
resource workflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  tags: {
    environment: environment
    workshop: 'logicapps-devops'
  }
  properties: {
    state: 'Enabled'
    definition: {
      // NOTE: This is a workshop sample definition (Request trigger -> HTTP -> Response)
      // Keep it minimal to avoid connector auth setup.
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        upstreamUrl: {
          type: 'string'
          defaultValue: upstreamUrl
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                message: {
                  type: 'string'
                }
              }
              required: [
                'message'
              ]
            }
          }
        }
      }
      actions: {
        correlationId: {
          type: 'Compose'
          inputs: "@{guid()}"
        }
        call_upstream: {
          type: 'Http'
          runAfter: {
            correlationId: [
              'Succeeded'
            ]
          }
          inputs: {
            method: 'GET'
            uri: "@parameters('upstreamUrl')"
          }
        }
        response: {
          type: 'Response'
          runAfter: {
            call_upstream: [
              'Succeeded'
            ]
          }
          inputs: {
            statusCode: 200
            body: {
              message: "@triggerBody()?['message']"
              correlationId: "@outputs('correlationId')"
              upstreamStatusCode: "@outputs('call_upstream')?['statusCode']"
              utcNow: "@utcNow()"
            }
          }
        }
      }
      outputs: {}
    }
  }
}

// Diagnostic settings: ship logs + metrics to Log Analytics workspace
// See Microsoft.Insights/diagnosticSettings resource type and Bicep extension resource model.
resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagName
  scope: workflow
  properties: {
    workspaceId: law.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Outputs (useful for participants)
output logicAppName string = workflow.name
output logAnalyticsWorkspaceName string = law.name
