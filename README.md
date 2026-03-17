# Logic Apps — From Problem to Production with DevOps

A hands-on workshop that takes you from a bare **Azure Logic App (Consumption)** deployment all the way to a production-grade TODO API with multi-stage pipelines, storage persistence, and monitoring.

---

## Lesson Roadmap

| # | Lesson | What you'll do |
|---|--------|----------------|
| 1 | [Deployment](docs/lesson-1-deployment.md) | Deploy a simple echo Logic App to Azure via GitHub Actions (OIDC). Single branch, single stage. |
| 2 | [Branching & Stages](docs/lesson-2-branching-and-stages.md) | Introduce `develop` as default branch. Add a `prod` stage so `develop` → dev, `main` → prod. |
| 3 | [TODO Workflow](docs/lesson-3-todo-workflow.md) | Replace the echo workflow with a full CRUD TODO API backed by Azure Table Storage and managed identity. |
| 4 | [Monitoring](docs/lesson-4-monitoring.md) | Add custom tracking IDs, tracked properties, Log Analytics workspace, diagnostic settings, saved queries, and an Azure Workbook. |

---

## Prerequisites

### Tools
| Tool | Install |
|------|---------|
| VS Code | https://code.visualstudio.com/ |
| Bicep extension | `ms-azuretools.vscode-bicep` |
| GitHub Actions extension | `github.vscode-github-actions` |
| Azure CLI | https://learn.microsoft.com/cli/azure/install-azure-cli |

### Azure
- An Azure subscription with **Contributor** access.
- An **Entra ID app registration** (or user-assigned managed identity) with:
  - A **federated credential** trusting your GitHub repo (environment: `dev`).
  - **Owner** role on the subscription (needed for role assignments in Lesson 3).

### GitHub
- A GitHub repository (fork or copy of this starter).
- Repository **variables** configured on the `dev` environment:
  - `AZURE_CLIENT_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`

> **Note:** This workshop uses environment **variables** (`vars.*`) instead of secrets so values are visible in the UI for easier troubleshooting. In real-world scenarios, use **environment secrets** (`secrets.*`) to keep credentials hidden.

> **Tip:** Each participant should choose a unique `nameToken` (e.g. their initials + a digit: `ab01`) and update it in `infra/main.dev.bicepparam` before their first deployment.

---

## Quick Reference

### Deploy via CLI (trainer fallback)
```bash
az deployment sub create \
  -l westeurope \
  -f infra/main.bicep \
  -p infra/main.dev.bicepparam
```

### Current state (Lesson 1 start)
- **Workflow:** Echo — accepts a POST with `subject` + `description`, returns them back.
- **Pipeline:** Single branch (`main`) → `dev` environment.
- **Resources:** Resource group + Logic App only.

---

## References
- [Consumption Logic App via Bicep quickstart](https://learn.microsoft.com/azure/logic-apps/quickstart-create-deploy-bicep)
- [Deploy Bicep with GitHub Actions (OIDC)](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-github-actions)
- [GitHub Actions OIDC to Azure](https://learn.microsoft.com/azure/developer/github/connect-from-azure-openid-connect)

