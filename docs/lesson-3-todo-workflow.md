# Lesson 3 — TODO Workflow

> **Goal:** Replace the echo workflow with a full CRUD TODO API that persists items in Azure Table Storage, authenticated via managed identity.

---

## What you'll learn
- How to add Azure Storage + Table resources in Bicep.
- How to assign a system-assigned managed identity to a Logic App.
- How to grant least-privilege access (Storage Table Data Contributor) via role assignment.
- How Consumption Logic Apps route on body fields instead of HTTP methods.

---

## 1 — Add storage resources to `resources.bicep`

Open `infra/resources.bicep` and add the following **above** the workflow definition variable.

### 1a — New variables

Add these variables after the existing `logicAppName` var:

```bicep
var storageAccountName = 'stor${replace(nameToken, '-', '')}${environment}'
var tableName = 'todos'

// Built-in role: Storage Table Data Contributor
var storageTableDataContributorRoleId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
```

> The `replace()` strips hyphens so the storage account name stays valid (lowercase alphanumeric, 3-24 chars).

### 1b — Storage account + table

```bicep
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
```

---

## 2 — Replace the workflow definition

Replace the contents of `infra/workflow-definition.json` with the TODO API workflow. Since Consumption Logic Apps can't read the HTTP method from `triggerOutputs()`, we route on a body field `action` with values: `list`, `create`, `update`, `delete`.

```json
{
  "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "storageBaseUrl": {
      "type": "string"
    }
  },
  "triggers": {
    "When_a_HTTP_request_is_received": {
      "type": "Request",
      "kind": "Http",
      "inputs": {
        "schema": {
          "type": "object",
          "properties": {
            "action":      { "type": "string" },
            "id":          { "type": "string" },
            "subject":     { "type": "string" },
            "description": { "type": "string" }
          },
          "required": ["action"]
        }
      }
    }
  },
  "actions": {
    "Switch_on_action": {
      "type": "Switch",
      "expression": "@triggerBody()?['action']",
      "cases": {
        "list": {
          "case": "list",
          "actions": {
            "Query_todos": {
              "type": "Http",
              "inputs": {
                "method": "GET",
                "uri": "@{parameters('storageBaseUrl')}todos()",
                "headers": {
                  "x-ms-version": "2020-12-06",
                  "Accept": "application/json;odata=nometadata"
                },
                "authentication": {
                  "type": "ManagedServiceIdentity",
                  "audience": "https://storage.azure.com/"
                }
              }
            },
            "Response_list": {
              "type": "Response",
              "runAfter": { "Query_todos": ["Succeeded"] },
              "inputs": {
                "statusCode": 200,
                "headers": { "Content-Type": "application/json" },
                "body": "@body('Query_todos')?['value']"
              }
            }
          }
        },
        "create": {
          "case": "create",
          "actions": {
            "Insert_todo": {
              "type": "Http",
              "inputs": {
                "method": "POST",
                "uri": "@{parameters('storageBaseUrl')}todos",
                "headers": {
                  "x-ms-version": "2020-12-06",
                  "Accept": "application/json;odata=nometadata",
                  "Content-Type": "application/json",
                  "Prefer": "return-content"
                },
                "body": {
                  "PartitionKey": "todo",
                  "RowKey": "@{guid()}",
                  "subject": "@{triggerBody()?['subject']}",
                  "description": "@{triggerBody()?['description']}"
                },
                "authentication": {
                  "type": "ManagedServiceIdentity",
                  "audience": "https://storage.azure.com/"
                }
              }
            },
            "Response_create": {
              "type": "Response",
              "runAfter": { "Insert_todo": ["Succeeded"] },
              "inputs": {
                "statusCode": 201,
                "headers": { "Content-Type": "application/json" },
                "body": "@body('Insert_todo')"
              }
            }
          }
        },
        "update": {
          "case": "update",
          "actions": {
            "Update_todo": {
              "type": "Http",
              "inputs": {
                "method": "PUT",
                "uri": "@{parameters('storageBaseUrl')}todos(PartitionKey='todo',RowKey='@{triggerBody()?['id']}')",
                "headers": {
                  "x-ms-version": "2020-12-06",
                  "Accept": "application/json;odata=nometadata",
                  "Content-Type": "application/json",
                  "If-Match": "*"
                },
                "body": {
                  "PartitionKey": "todo",
                  "RowKey": "@{triggerBody()?['id']}",
                  "subject": "@{triggerBody()?['subject']}",
                  "description": "@{triggerBody()?['description']}"
                },
                "authentication": {
                  "type": "ManagedServiceIdentity",
                  "audience": "https://storage.azure.com/"
                }
              }
            },
            "Response_update": {
              "type": "Response",
              "runAfter": { "Update_todo": ["Succeeded"] },
              "inputs": {
                "statusCode": 200,
                "headers": { "Content-Type": "application/json" },
                "body": {
                  "message": "Todo updated",
                  "id": "@{triggerBody()?['id']}"
                }
              }
            }
          }
        },
        "delete": {
          "case": "delete",
          "actions": {
            "Delete_todo": {
              "type": "Http",
              "inputs": {
                "method": "DELETE",
                "uri": "@{parameters('storageBaseUrl')}todos(PartitionKey='todo',RowKey='@{triggerBody()?['id']}')",
                "headers": {
                  "x-ms-version": "2020-12-06",
                  "Accept": "application/json;odata=nometadata",
                  "If-Match": "*"
                },
                "authentication": {
                  "type": "ManagedServiceIdentity",
                  "audience": "https://storage.azure.com/"
                }
              }
            },
            "Response_delete": {
              "type": "Response",
              "runAfter": { "Delete_todo": ["Succeeded"] },
              "inputs": {
                "statusCode": 200,
                "headers": { "Content-Type": "application/json" },
                "body": {
                  "message": "Todo deleted",
                  "id": "@{triggerBody()?['id']}"
                }
              }
            }
          }
        }
      },
      "default": {
        "actions": {
          "Response_invalid_action": {
            "type": "Response",
            "inputs": {
              "statusCode": 400,
              "headers": { "Content-Type": "application/json" },
              "body": { "error": "Invalid action. Use: list, create, update, delete" }
            }
          }
        }
      }
    }
  },
  "outputs": {}
}
```

> **Note:** The workflow definition lives in a separate `workflow-definition.json` file and is loaded via `loadJsonContent()` in `resources.bicep`. This keeps the Bicep file clean and the workflow definition easy to edit.

---

## 3 — Add managed identity and storage parameter to the Logic App

Replace the existing `workflow` resource block:

```bicep
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
```

Key changes:
- **`identity.type: 'SystemAssigned'`** — gives the Logic App its own managed identity.
- **`parameters.storageBaseUrl`** — injects the storage table endpoint (cloud-agnostic, no hardcoded URLs).

---

## 4 — Add the role assignment

After the `workflow` resource, add:

```bicep
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
```

This grants the Logic App's managed identity **Storage Table Data Contributor** on the storage account — the minimum permission to read/write table entities.

---

## 5 — Update outputs

Add a storage account output at the bottom of `resources.bicep`:

```bicep
output storageAccountName string = storageAccount.name
```

---

## 6 — Deploy to dev

Commit and push to `develop`:
```bash
git add -A
git commit -m "Lesson 3: TODO API with Table Storage"
git push origin develop
```

Wait for the `deploy-dev` job to complete.

---

## 7 — Validate

Get the Logic App callback URL from the Azure Portal and test each operation:

### Create a todo
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"action":"create","subject":"Buy milk","description":"From the store"}' \
  "<CALLBACK_URL>"
```
Expected: `201` with the created entity (including `RowKey`).

### List all todos
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"action":"list"}' \
  "<CALLBACK_URL>"
```

### Update a todo
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"action":"update","id":"<ROWKEY>","subject":"Buy oat milk","description":"Organic only"}' \
  "<CALLBACK_URL>"
```

### Delete a todo
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"action":"delete","id":"<ROWKEY>"}' \
  "<CALLBACK_URL>"
```

---

## 8 — Promote to prod

1. Create a **Pull Request** from `develop` into `main`.
2. Merge the PR.
3. Confirm `deploy-prod` succeeds and the prod Logic App also works.

---

## Recap
| Done | Item |
|------|------|
| ✅ | Storage account + `todos` table deployed |
| ✅ | Logic App has system-assigned managed identity |
| ✅ | Role assignment grants table access |
| ✅ | CRUD operations work (create, list, update, delete) |
| ✅ | Deployed to dev, then promoted to prod via PR |

**Next:** [Lesson 4 — Monitoring](lesson-4-monitoring.md)
