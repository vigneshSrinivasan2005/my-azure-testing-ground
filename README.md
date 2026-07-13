# PavBot — LLM Chatbot on Azure AI Foundry (ClickOps CI/CD, no Docker)

Flask chatbot powered by an **Azure AI Foundry** model deployment (Mistral Small 2503, serverless), deployed as **code** (no containers) to **Azure App Service**, with CI/CD wired up entirely through the **Azure Portal UI** (Deployment Center).

Flow: **GitHub → Azure App Service Deployment Center (portal ClickOps) → auto-generated CI/CD → App Service builds & runs the app → Azure AI Foundry model**

---

## 0a. Set up the model in Azure AI Foundry (UI)

1. Go to **ai.azure.com** (Azure AI Foundry portal) → sign in with the same subscription.
2. **Create a project** (this also creates an Azure OpenAI / AI Services resource in your resource group — put it in `rg-pavbot`).
3. Left menu → **Model catalog** → pick **mistral-small-2503** → **Deploy** → Deployment type: **Global Standard** → keep the deployment name `mistral-small-2503` → Deploy.
4. Go to **My assets → Models + endpoints** → click your deployment. Copy three things:
   - **Target URI / Endpoint**
   - **Key**
   - **Deployment name** (e.g. `mistral-small-2503`)

These become environment variables — never hardcode them or commit them to the repo:

| Variable | Value |
|---|---|
| `AZURE_AI_ENDPOINT` | `https://<your-resource>.services.ai.azure.com/models` |
| `AZURE_AI_API_KEY` | key from step 4 |
| `AZURE_AI_MODEL` | your deployment name |

## 0b. Run locally first

```bash
pip install -r requirements.txt

# Windows (PowerShell)
$env:AZURE_AI_ENDPOINT="https://<your-resource>.services.ai.azure.com/models"
$env:AZURE_AI_API_KEY="<key>"
$env:AZURE_AI_MODEL="mistral-small-2503"

# Linux/macOS
export AZURE_AI_ENDPOINT="https://<your-resource>.services.ai.azure.com/models"
export AZURE_AI_API_KEY="<key>"
export AZURE_AI_MODEL="mistral-small-2503"

python app.py            # http://localhost:8000
```

---

## 1. Push to GitHub

```bash
cd chatbot-app
git init
git add .
git commit -m "Initial commit: Flask chatbot"
git branch -M main
git remote add origin https://github.com/<your-username>/pavbot.git
git push -u origin main
```

---

## 2. Create the Web App (Azure Portal — code, not container)

1. Portal → **Create a resource** → **Web App**.
2. Basics tab:
   - Resource group: `rg-pavbot` (create new)
   - Name: `pavbot-app-<unique>`
   - **Publish: Code** ← (not Container)
   - **Runtime stack: Python 3.12** · OS: **Linux**
   - Plan: **B1** (or F1 Free)
3. **Review + Create** → Create.

---

## 3. Wire up CI/CD in the portal (Deployment Center — zero YAML written by you)

1. Open the Web App → **Deployment → Deployment Center**.
2. **Source: GitHub** → sign in / authorize Azure to access your GitHub account.
3. Pick your **organization**, **repository** (`pavbot`), and **branch** (`main`).
4. Authentication: keep the default (**User-assigned identity** or basic auth — the portal handles it).
5. Click **Save**.

That's it — the portal auto-commits a GitHub Actions workflow (`.github/workflows/...`) to your repo and kicks off the first deployment. App Service's build engine (**Oryx**) detects `requirements.txt`, installs dependencies, and serves the Flask app with gunicorn automatically.

Watch progress under **Deployment Center → Logs** (or the **Actions** tab in GitHub).

---

## 4. Configure environment variables (Azure Portal)

Web App → **Settings → Environment variables** → **App settings** → add → **Apply** (app restarts):

| Name | Value |
|---|---|
| `AZURE_AI_ENDPOINT` | `https://<your-resource>.services.ai.azure.com/models` |
| `AZURE_AI_API_KEY` | your Foundry key |
| `AZURE_AI_MODEL` | `mistral-small-2503` |
| `SCM_DO_BUILD_DURING_DEPLOYMENT` | `true` (usually set automatically) |

(Better practice for later: store the key in **Key Vault** and use a Key Vault reference `@Microsoft.KeyVault(SecretUri=...)` as the value.)

### Startup command

Web App → **Settings → Configuration → General settings → Startup Command**:

```
gunicorn --bind=0.0.0.0:8000 --workers 2 app:app
```

(Optional — App Service auto-detects `app:app` for Flask, but setting it explicitly avoids surprises.) Note: with a startup command, App Service routes traffic to the port you bind; leaving the field empty also works since Oryx defaults to gunicorn.

---

## 5. Verify

1. Browse to `https://pavbot-app-<unique>.azurewebsites.net` — the chatbot should load and answer via the Foundry model.
2. Quick check: open `/health` — it returns `"foundry_configured": true` when the env vars are picked up.
3. If the site shows the default page, check **Deployment Center → Logs** and **Monitoring → Log stream**.

---

## 6. Test the full CI/CD loop

1. Edit `app.py` — e.g. change a bot reply.
2. Commit + push to GitHub `main` (or edit directly in the GitHub web UI).
3. The workflow triggers automatically → builds → deploys to App Service.
4. Refresh the site (allow ~1–2 min for restart).

---

## Endpoints

| Route | Purpose |
|---|---|
| `/` | Chat UI |
| `/api/chat` (POST) | `{"message": "..."}` → `{"reply": "..."}` |
| `/health` | Health probe for App Service |

## Cleanup

Delete the resource group `rg-pavbot` to remove everything (App Plan + Web App) in one shot. Also delete the auto-created workflow file from the repo if you disconnect Deployment Center.
