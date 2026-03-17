# Lesson 1 — Deployment

> **Goal:** Deploy the echo Logic App to Azure through GitHub Actions using OIDC authentication.

---

## What you'll learn
- How a Bicep subscription-scoped deployment creates a resource group and a Logic App.
- How GitHub Actions OIDC connects to Azure without storing credentials.
- How to trigger and test a Consumption Logic App via its HTTP endpoint.

---

## 1 — Review the infrastructure

Open `infra/main.bicep`. It is a **subscription-scoped** template that:
1. Creates a resource group `rg-<nameToken>-<environment>`.
2. Calls the `resources.bicep` module which deploys the Logic App.

Open `infra/resources.bicep`. It deploys a single **Consumption Logic App** with an HTTP trigger that echoes back whatever you POST.

Open `infra/main.dev.bicepparam`. It pins the parameters for the dev stage:
```
param nameToken = 'rn01'   ← change to YOUR unique token
param environment = 'dev'
param location = 'westeurope'
```

### Action
Edit `main.dev.bicepparam` and change `nameToken` to something unique (e.g. your initials + a digit: `ab01`).

---

## 2 — Review the GitHub Actions workflow

Open `.github/workflows/deploy.yml`.

Key points:
- **Trigger:** `push` to `main` (and manual `workflow_dispatch`).
- **OIDC permissions:** `id-token: write` + `contents: read`.
- **Single job:** `deploy-dev` using GitHub environment `dev`.
- **Steps:** checkout → azure/login (OIDC) → azure/arm-deploy (subscription scope).

---

## 3 — Configure GitHub environment secrets

In your GitHub repo, go to **Settings → Environments → New environment** and create an environment named **`dev`**.

Add these three **variables** to the `dev` environment:

| Variable | Value |
|----------|-------|
| `AZURE_CLIENT_ID` | The Application (client) ID of your Entra app registration |
| `AZURE_TENANT_ID` | Your Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | The target Azure subscription ID |

> Make sure the Entra app has a **federated credential** for your repo with environment `dev`.
>
> **Why variables, not secrets?** During this workshop we use environment variables so values are visible in the UI for easier troubleshooting. In production, use **secrets** instead.

---

## 4 — Deploy

Commit your `nameToken` change and push to `main`:
```bash
git add -A
git commit -m "Set my nameToken"
git push origin main
```

Go to **Actions** in your GitHub repo and watch the `deploy-dev` job run.

### Alternative: deploy via CLI
```bash
az login
az deployment sub create \
  -l westeurope \
  -f infra/main.bicep \
  -p infra/main.dev.bicepparam
```

---

## 5 — Validate

### Check the resource group
In the Azure Portal, search for your resource group (e.g. `rg-ab01-dev`) and confirm it contains:
- ✅ Logic App (`la-ab01-dev`)

### Test the Logic App
1. Open the Logic App in the Portal.
2. Open the **trigger** (`When_a_HTTP_request_is_received`) and copy the **Callback URL**.
3. Send a test request:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"subject":"Buy milk","description":"From the store"}' \
  "<YOUR_CALLBACK_URL>"
```

4. Verify the response:
```json
{
  "message": "Todo received",
  "subject": "Buy milk",
  "description": "From the store"
}
```

---

## Recap
| Done | Item |
|------|------|
| ✅ | Unique `nameToken` set in bicepparam |
| ✅ | GitHub environment `dev` with OIDC secrets |
| ✅ | Pipeline deploys successfully on push to `main` |
| ✅ | Logic App responds to curl with echo |

**Next:** [Lesson 2 — Branching & Stages](lesson-2-branching-and-stages.md)
