# Lesson 2 — Branching & Stages

> **Goal:** Introduce a `develop` branch as the default branch and add a `prod` deployment stage so that `develop` deploys to dev and `main` deploys to prod.

---

## What you'll learn
- How to structure a branch-per-stage deployment model.
- How to add a second GitHub environment with its own OIDC credentials.
- How to gate production deployments behind branch protection and environment approvals.

---

## 1 — Create the `develop` branch

```bash
git checkout -b develop
git push -u origin develop
```

In your GitHub repo, go to **Settings → General → Default branch** and change it to **`develop`**.

---

## 2 — Create `main.prod.bicepparam`

Create a new file `infra/main.prod.bicepparam`:

```bicep
using './main.bicep'

param nameToken = '<YOUR_TOKEN>'   // same token as dev
param environment = 'prod'
param location = 'westeurope'
```

Use the same `nameToken` you chose in Lesson 1. The `environment = 'prod'` will create a separate resource group (`rg-<token>-prod`) and Logic App (`la-<token>-prod`).

---

## 3 — Configure the `prod` GitHub environment

In **Settings → Environments**, create a new environment named **`prod`**.

Add the same three variables (they can point to the same Entra app or a separate one for production):

| Variable | Value |
|----------|-------|
| `AZURE_CLIENT_ID` | Application (client) ID |
| `AZURE_TENANT_ID` | Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID |

> **Important:** If you use the same Entra app registration, add a second **federated credential** for environment `prod`.

**Optional:** Enable **Required reviewers** on the `prod` environment to gate production deployments.

---

## 4 — Update `deploy.yml`

Replace the contents of `.github/workflows/deploy.yml` with:

```yaml
name: Deploy Logic App (Consumption) via Bicep

on:
  push:
    branches:
      - main
      - develop
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  deploy-dev:
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment: dev
    steps:
      - uses: actions/checkout@v4

      - name: Azure login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy DEV
        uses: azure/arm-deploy@v2
        with:
          scope: subscription
          region: westeurope
          template: infra/main.bicep
          parameters: infra/main.dev.bicepparam

  deploy-prod:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: prod
    steps:
      - uses: actions/checkout@v4

      - name: Azure login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy PROD
        uses: azure/arm-deploy@v2
        with:
          scope: subscription
          region: westeurope
          template: infra/main.bicep
          parameters: infra/main.prod.bicepparam
```

Key changes from Lesson 1:
- **Triggers** on both `main` and `develop`.
- **`deploy-dev`** runs only on pushes to `develop`.
- **`deploy-prod`** runs only on pushes to `main` using environment `prod`.

---

## 5 — Deploy to dev

Commit and push to `develop`:
```bash
git add -A
git commit -m "Lesson 2: add prod stage and branching"
git push origin develop
```

Watch the `deploy-dev` job in **Actions**. The `deploy-prod` job should be skipped.

---

## 6 — Deploy to prod via Pull Request

1. Go to your GitHub repo and create a **Pull Request** from `develop` into `main`.
2. Merge the PR.
3. The merge push to `main` triggers `deploy-prod`.
4. If you configured approval on the `prod` environment, approve the deployment.

---

## 7 — Validate

### Dev stage
- Resource group `rg-<token>-dev` contains `la-<token>-dev` ✅

### Prod stage
- Resource group `rg-<token>-prod` contains `la-<token>-prod` ✅
- Both Logic Apps return the echo response when triggered ✅

### Pipeline behaviour
- Push to `develop` → only `deploy-dev` runs ✅
- Push/merge to `main` → only `deploy-prod` runs ✅

---

## Recap
| Done | Item |
|------|------|
| ✅ | `develop` branch created and set as default |
| ✅ | `main.prod.bicepparam` created |
| ✅ | `prod` GitHub environment with OIDC secrets |
| ✅ | `deploy.yml` routes branches to stages |
| ✅ | Dev deploys on `develop`, prod deploys on `main` |

**Next:** [Lesson 3 — TODO Workflow](lesson-3-todo-workflow.md)
