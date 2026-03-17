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
var workflowDefinition = json('''
{
  "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {},
  "triggers": {
    "When_a_HTTP_request_is_received": {
      "type": "Request",
      "kind": "Http",
      "inputs": {
        "method": "POST",
        "schema": {
          "type": "object",
          "properties": {
            "subject":     { "type": "string" },
            "description": { "type": "string" }
          },
          "required": ["subject"]
        }
      }
    }
  },
  "actions": {
    "Echo_response": {
      "type": "Response",
      "inputs": {
        "statusCode": 200,
        "headers": { "Content-Type": "application/json" },
        "body": {
          "message": "Todo received",
          "subject": "@{triggerBody()?['subject']}",
          "description": "@{triggerBody()?['description']}"
        }
      }
    }
  },
  "outputs": {}
}
''')

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
