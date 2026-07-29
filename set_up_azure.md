# Complete Setup Guide: Connecting GitHub Actions to Azure via OIDC

Here is a step-by-step setup guide for configuring secretless **OpenID Connect (OIDC)** authentication between your GitHub repository (`vigneshSrinivasan2005/my-azure-testing-ground`) and your **Microsoft Azure** subscription.

---

## Phase 1: GitHub Repository & Environment Configuration

First, set up your target **Environment** and repository secrets within GitHub.

### 1.1 Create the GitHub Environment

1. Go to your repository: `vigneshSrinivasan2005/my-azure-testing-ground` on GitHub.
2. Click **Settings** $\rightarrow$ **Environments** $\rightarrow$ **New environment**.
3. Set the name to **`production`**.
4. *(Optional)* Under **Deployment branches and tags**, restrict deployments to `Selected branches` (e.g., `main`).
5. *(Optional)* Check **Required reviewers** and add designated team members.
6. Click **Save protection rules**.

---

## Phase 2: Provisioning Azure Identity & OIDC Federation

Run these commands in your local terminal using the **Azure CLI** (`az login`).

### 2.1 Authenticate and Set Active Subscription

```bash
# Log in to Azure
az login

# Get active Tenant and Subscription IDs
export TENANT_ID=$(az account show --query "tenantId" -o tsv)
export SUB_ID=$(az account show --query "id" -o tsv)

echo "Tenant ID: $TENANT_ID"
echo "Subscription ID: $SUB_ID"

```

### 2.2 Register Microsoft Entra ID Application & Service Principal

```bash
# 1. Create App Registration
export APP_NAME="github-actions-azure-testing"
az ad app create --display-name "$APP_NAME"

# 2. Retrieve Client ID (App ID)
export APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)

# 3. Create Enterprise Service Principal
az ad sp create --id $APP_ID

```

### 2.3 Create OIDC Federated Identity Credential

Bind the Azure App Registration directly to your GitHub environment context:

```bash
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-actions-production-env",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:vigneshSrinivasan2005/my-azure-testing-ground:environment:production",
    "description": "GitHub Actions OIDC Trust for production environment",
    "audiences": ["api://AzureADTokenExchange"]
  }'

```

### 2.4 Grant Subscription Access (RBAC)

Assign the `Contributor` role to the Service Principal over your Azure subscription scope:

```bash
az role assignment create \
  --assignee $APP_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUB_ID"

```

---

## Phase 3: Populating GitHub Environment Secrets

1. Navigate back to **Settings** $\rightarrow$ **Environments** $\rightarrow$ **`production`** in your GitHub repository.
2. Under **Environment secrets**, add the following three secrets:

| Secret Name | Value | Command / Source |
| --- | --- | --- |
| `AZURE_CLIENT_ID` | Your `$APP_ID` | `echo $APP_ID` |
| `AZURE_TENANT_ID` | Your `$TENANT_ID` | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | Your `$SUB_ID` | `az account show --query id -o tsv` |

---

## Phase 4: GitHub Actions Workflow Verification

To test the integration, create or update `.github/workflows/provision-infra.yml` in your repository:

```yaml
name: Deploy Infrastructure to Azure

on:
  push:
    branches:
      - main

permissions:
  id-token: write  # Required for requesting the JWT token via OIDC
  contents: read

jobs:
  deploy:
    name: Provision Azure Resources
    runs-on: ubuntu-latest
    environment: production  # Must match the federated credential subject claim

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Azure Login via OIDC
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Verify Azure Authentication
        run: |
          az account show
          az group list --output table

```

---

## Verification & Workflow Lifecycle

```
┌──────────────────────────────────────┐
│  Developer Pushes Code to 'main'     │
└──────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│  GitHub Actions Workflow Triggered   │
│  (Requests JWT ID Token from GitHub) │
└──────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│  Azure Entra ID Validates JWT        │
│  Claim: repo:...:environment:production
└──────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│  Short-Lived Access Token Granted    │
│  (Azure CLI commands execute)        │
└──────────────────────────────────────┘

```