Step 1: Configure the Environment in GitHub
Go to your repository on GitHub (vigneshSrinivasan2005/my-azure-testing-ground).

Click Settings > Environments > New environment.

Name it production (or azure-infra).

AZURE_CLIENT_ID: Your $APP_ID

AZURE_TENANT_ID: Your Azure Directory/Tenant ID (az account show --query tenantId -o tsv)

AZURE_SUBSCRIPTION_ID: Your Azure Subscription ID ($SUB_ID)

Check Required reviewers.

Add yourself (and/or teammates) as designated reviewers.

Click Save protection rules.

Step 2: az login
Step 3: az ad app create --display-name "github-actions-azure-testing"
Step 4: APP_ID=$(az ad app list --display-name "github-actions-azure-testing" --query "[0].appId" -o tsv)
Step 5:az ad sp create --id $APP_ID
Step 6:az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-actions-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:vigneshSrinivasan2005/my-azure-testing-ground:environment:production"
    "description": "GitHub Actions OIDC Trust",
    "audiences": ["api://AzureADTokenExchange"]
  }'
Step 7:SUB_ID=$(az account show --query "id" -o tsv)

az role assignment create \
  --assignee $APP_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUB_ID"

