# Lesson 4 — Monitoring

> **Goal:** Add custom tracking IDs, tracked properties on every action, a Log Analytics workspace with saved queries, diagnostic settings, and an Azure Workbook for run-level observability.

---

## What you'll learn
- How `correlation.clientTrackingId` tags each Logic App run with a caller-supplied ID.
- How `trackedProperties` on actions surface custom data in diagnostics.
- How to deploy a Log Analytics workspace, saved searches, and an Azure Workbook via Bicep.
- How to wire diagnostic settings so all logs and metrics flow to Log Analytics.

---

## 1 — Add a custom tracking ID to the trigger

In `infra/resources.bicep`, update the trigger inside the `workflowDefinition` JSON. Add a `trackingId` property to the schema and a `correlation` block:

```jsonc
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
          "description": { "type": "string" },
          "trackingId":  { "type": "string" }       // ← NEW
        },
        "required": ["action"]
      }
    },
    "correlation": {                                  // ← NEW BLOCK
      "clientTrackingId": "@{coalesce(triggerBody()?['trackingId'], guid())}"
    }
  }
}
```

This means:
- If the caller sends `"trackingId": "order-42"`, the run is tagged with `order-42`.
- If omitted, a GUID is auto-generated.

---

## 2 — Add tracked properties to each action

Add a `trackedProperties` object to every HTTP and Response action inside the Switch cases. Example for the **create** case:

```jsonc
"Insert_todo": {
  "type": "Http",
  "inputs": { ... },
  "trackedProperties": {
    "action": "create",
    "subject": "@{triggerBody()?['subject']}",
    "description": "@{triggerBody()?['description']}"
  }
},
"Response_create": {
  "type": "Response",
  "runAfter": { "Insert_todo": ["Succeeded"] },
  "inputs": { ... },
  "trackedProperties": {
    "action": "create",
    "statusCode": "201"
  }
}
```

Repeat for all cases:

| Case | Action | trackedProperties |
|------|--------|-------------------|
| **list** | `Query_todos` | `"action": "list"` |
| **list** | `Response_list` | `"action": "list", "statusCode": "200"` |
| **create** | `Insert_todo` | `"action": "create", "subject": "@{triggerBody()?['subject']}", "description": "@{triggerBody()?['description']}"` |
| **create** | `Response_create` | `"action": "create", "statusCode": "201"` |
| **update** | `Update_todo` | `"action": "update", "todoId": "@{triggerBody()?['id']}"` |
| **update** | `Response_update` | `"action": "update", "statusCode": "200"` |
| **delete** | `Delete_todo` | `"action": "delete", "todoId": "@{triggerBody()?['id']}"` |
| **delete** | `Response_delete` | `"action": "delete", "statusCode": "200"` |
| **default** | `Response_invalid_action` | `"action": "invalid", "statusCode": "400"` |

---

## 3 — Add Log Analytics workspace

Add the following resources to `resources.bicep` (after the storage resources, before the workflow definition):

### 3a — Variables

Add these name variables at the top alongside the existing ones:

```bicep
var laWorkspaceName = 'law-${nameToken}-${environment}'
var diagName = 'diag-${logicAppName}'
var workbookName = guid(resourceGroup().id, 'todo-monitoring')
```

### 3b — Log Analytics workspace

```bicep
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
```

---

## 4 — Add saved searches

```bicep
resource savedSearchRuns 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  name: 'TodoApiRuns'
  parent: law
  properties: {
    category: 'Logic Apps'
    displayName: 'TODO API – Workflow Runs'
    query: 'AzureDiagnostics | where ResourceProvider == "MICROSOFT.LOGIC" | where OperationName == "Microsoft.Logic/workflows/workflowRunCompleted" | extend RunId = resource_runId_s | extend TrackingId = coalesce(correlation_clientTrackingId_s, "N/A") | extend DurationMs = datetime_diff("millisecond", endTime_t, startTime_t) | project TimeGenerated, RunId, TrackingId, Status = status_s, DurationMs | order by TimeGenerated desc'
    version: 2
  }
}

resource savedSearchActions 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  name: 'TodoApiActions'
  parent: law
  properties: {
    category: 'Logic Apps'
    displayName: 'TODO API – Action Details'
    query: 'AzureDiagnostics | where ResourceProvider == "MICROSOFT.LOGIC" | where OperationName contains "workflowAction" | extend Action = resource_actionName_s | extend TrackedAction = column_ifexists("trackedProperties_action_s", "") | extend TrackedSubject = column_ifexists("trackedProperties_subject_s", "") | extend DurationMs = datetime_diff("millisecond", endTime_t, startTime_t) | project TimeGenerated, RunId = resource_runId_s, Action, Status = status_s, TrackedAction, TrackedSubject, DurationMs | order by TimeGenerated desc'
    version: 2
  }
}
```

---

## 5 — Add diagnostic settings

After the `roleAssignment` resource, add:

```bicep
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
```

---

## 6 — Add the Azure Workbook

Add this workbook resource. It creates a monitoring dashboard with:
- A **time range** filter.
- A **Runs Overview** table showing each run's ID and client tracking ID. Click a row to select it.
- A **Run Details** table showing tracked properties for the selected run.

```bicep
var workbookContent = '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 9,
      "content": {
        "version": "KqlParameterItem/1.0",
        "parameters": [
          {
            "id": "a1b2c3d4-0001-0000-0000-000000000001",
            "version": "KqlParameterItem/1.0",
            "name": "TimeRange",
            "label": "Time Range",
            "type": 4,
            "isRequired": true,
            "value": { "durationMs": 86400000 },
            "typeSettings": {
              "selectableValues": [
                { "durationMs": 300000 },
                { "durationMs": 900000 },
                { "durationMs": 3600000 },
                { "durationMs": 14400000 },
                { "durationMs": 43200000 },
                { "durationMs": 86400000 },
                { "durationMs": 259200000 },
                { "durationMs": 604800000 }
              ],
              "allowCustom": true
            }
          }
        ]
      },
      "name": "TimeRangeParameter"
    },
    {
      "type": 1,
      "content": {
        "json": "## Workflow Runs\nSelect a row to see tracked properties for that run."
      },
      "name": "HeaderRuns"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "AzureDiagnostics\n| where ResourceProvider == \"MICROSOFT.LOGIC\"\n| where OperationName == \"Microsoft.Logic/workflows/workflowRunCompleted\"\n| extend RunId = resource_runId_s\n| extend TrackingId = coalesce(correlation_clientTrackingId_s, \"N/A\")\n| extend DurationMs = datetime_diff(\"millisecond\", endTime_t, startTime_t)\n| project TimeGenerated, RunId, TrackingId, Status = status_s, DurationMs\n| order by TimeGenerated desc",
        "size": 0,
        "timeContextFromParameter": "TimeRange",
        "exportFieldName": "RunId",
        "exportParameterName": "SelectedRunId",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "name": "RunOverview"
    },
    {
      "type": 1,
      "content": {
        "json": "## Run Details — {SelectedRunId}"
      },
      "conditionalVisibility": {
        "parameterName": "SelectedRunId",
        "comparison": "isNotEqualTo",
        "value": ""
      },
      "name": "HeaderDetails"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "AzureDiagnostics\n| where ResourceProvider == \"MICROSOFT.LOGIC\"\n| where resource_runId_s == \"{SelectedRunId}\"\n| where OperationName contains \"workflowAction\"\n| extend Action = resource_actionName_s\n| extend TrackedAction = column_ifexists('trackedProperties_action_s', '')\n| extend TrackedSubject = column_ifexists('trackedProperties_subject_s', '')\n| extend TrackedDescription = column_ifexists('trackedProperties_description_s', '')\n| extend TrackedTodoId = column_ifexists('trackedProperties_todoId_s', '')\n| extend TrackedStatusCode = column_ifexists('trackedProperties_statusCode_s', '')\n| extend DurationMs = datetime_diff(\"millisecond\", endTime_t, startTime_t)\n| project TimeGenerated, Action, Status = status_s, TrackedAction, TrackedSubject, TrackedDescription, TrackedTodoId, TrackedStatusCode, DurationMs\n| order by TimeGenerated asc",
        "size": 0,
        "timeContextFromParameter": "TimeRange",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "conditionalVisibility": {
        "parameterName": "SelectedRunId",
        "comparison": "isNotEqualTo",
        "value": ""
      },
      "name": "RunDetails"
    }
  ],
  "fallbackResourceIds": []
}
'''

resource workbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: workbookName
  location: location
  kind: 'shared'
  properties: {
    displayName: 'TODO API Monitoring'
    category: 'workbook'
    serializedData: workbookContent
    sourceId: law.id
  }
}
```

---

## 7 — Update outputs

Add the Log Analytics workspace name output if not already present:

```bicep
output logAnalyticsWorkspaceName string = law.name
```

And update `main.bicep` to forward it:

```bicep
output logAnalyticsWorkspaceName string = resources.outputs.logAnalyticsWorkspaceName
```

---

## 8 — Deploy to dev

```bash
git add -A
git commit -m "Lesson 4: monitoring with tracking, LAW, workbook"
git push origin develop
```

---

## 9 — Validate

### 9a — Send tracked requests

```bash
# With explicit tracking ID
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"action":"create","subject":"Buy milk","description":"From the store","trackingId":"test-001"}' \
  "<CALLBACK_URL>"

# Another request
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"action":"list","trackingId":"test-002"}' \
  "<CALLBACK_URL>"
```

### 9b — Check Log Analytics (wait ~5 min for ingestion)

In the Azure Portal, open the Log Analytics workspace and run the saved query **"TODO API – Workflow Runs"**.

You should see your runs with the `TrackingId` column showing `test-001`, `test-002`, etc.

Click a run and run **"TODO API – Action Details"** filtered to that `RunId` to see the tracked properties.

### 9c — Open the Workbook

In the Azure Portal:
1. Open the Log Analytics workspace.
2. Go to **Workbooks**.
3. Open **TODO API Monitoring**.
4. Select a time range. The master grid shows all runs with tracking IDs.
5. Click a row. The detail grid appears showing every action's tracked properties for that run.

---

## 10 — Promote to prod

1. Create a PR from `develop` into `main`.
2. Merge and confirm `deploy-prod` succeeds.
3. Verify the prod workbook and diagnostic settings.

---

## Recap
| Done | Item |
|------|------|
| ✅ | `trackingId` in trigger with `correlation.clientTrackingId` |
| ✅ | `trackedProperties` on every action |
| ✅ | Log Analytics workspace deployed |
| ✅ | Saved queries for runs and action details |
| ✅ | Azure Workbook with time filter, run selector, detail drill-down |
| ✅ | Diagnostic settings wiring logs + metrics |
| ✅ | Deployed and validated in both dev and prod |

**Congratulations!** You've taken a Logic App from a simple echo endpoint to a production-grade TODO API with full observability. 🎉
