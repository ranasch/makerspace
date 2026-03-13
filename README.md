# Logic Apps — Problem → Production with DevOps (Consumption)

This repo is a **hands-on** workshop starter for deploying an **Azure Logic App (Consumption)** via **Bicep** and **GitHub Actions (OIDC)**, then validating logs in **Log Analytics**.

## What you’ll deploy
- Log Analytics workspace
- Consumption Logic App with a **Request** trigger and an **HTTP** action
- Diagnostic Settings to send logs/metrics to the workspace

> References:
> - Consumption Logic App via Bicep quickstart: https://learn.microsoft.com/en-us/azure/logic-apps/quickstart-create-deploy-bicep
> - Deploy Bicep with GitHub Actions (OIDC): https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-github-actions
> - GitHub Actions OIDC to Azure: https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect

---

## Prerequisites
### VS Code extensions
Install:
- **Azure Logic Apps (Consumption)** — `ms-azuretools.vscode-logicapps`
- **Bicep** — `ms-azuretools.vscode-bicep`
- **GitHub Actions** — `github.vscode-github-actions`
Optional:
- **Azure CLI Tools** — `ms-vscode.azurecli`

### GitHub Actions OIDC secrets
Configure these secrets (repo or environment secrets):
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Also ensure the Entra app (or MI) has a federated credential trust for this repo/environment and Contributor permission.

---

## How to run the deployment
### Option A: GitHub Actions (recommended)
1. Push to `main` to deploy **dev**.
2. Run **workflow_dispatch** to deploy **prod** (with environment approval gate if configured).

### Option B: local CLI (trainer fallback)
```bash
az group create -n rg-<nameToken>-dev -l <location>
az deployment group create   -g rg-<nameToken>-dev   -f infra/main.bicep   -p infra/main.dev.bicepparam
```

---

## Trigger the Logic App with curl
After deployment, open the Logic App in Azure Portal and get the **Callback URL** for the `manual` trigger.

### Example: call the workflow
```bash
curl -X POST   -H "Content-Type: application/json"   -d '{"message":"hello from workshop"}'   "<PASTE_TRIGGER_CALLBACK_URL_HERE>"
```

### Expected response shape
```json
{
  "message": "hello from workshop",
  "correlationId": "<guid>",
  "upstreamStatusCode": 200,
  "utcNow": "2026-02-27T...Z"
}
```

---

## Monitoring
- Open the **Log Analytics workspace** created by the deployment.
- Validate diagnostic settings exist on the Logic App.

> Note: Log table names can vary depending on how diagnostics are configured in your tenant.

