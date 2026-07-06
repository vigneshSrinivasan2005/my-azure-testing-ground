# PavBot — LLM Chatbot on Azure AI Foundry (UI-based CI/CD)

Flask chatbot powered by an **Azure AI Foundry** model deployment (Mistral Small 2503, serverless), containerized with Docker, deployed to **Azure Web App for Containers** using a **UI-created Azure Pipeline**.

Flow: **GitHub → Azure Repos (import) → Azure Pipelines (Docker build + push to ACR) → Web App for Containers → Azure AI Foundry model**

---

## 0a. Set up the model in Azure AI Foundry (UI)

1. Go to **ai.azure.com** (Azure AI Foundry portal) → sign in with the same subscription.
2. **Create a project** (this also creates an Azure OpenAI / AI Services resource in your resource group — put it in `rg-pavbot`).
3. Left menu → **Model catalog** → pick **mistral-small-2503** → **Deploy** → Deployment type: **Global Standard** → keep the deployment name `mistral-small-2503` → Deploy.
4. Go to **My assets → Models + endpoints** → click your deployment. Copy three things:
   - **Target URI / Endpoint** → the part up to `.openai.azure.com/` (e.g. `https://myresource.openai.azure.com/`)
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

With Docker (env vars are passed at run time, not baked into the image):

```bash
docker build -t pavbot .
docker run -p 8000:8000 \
  -e AZURE_AI_ENDPOINT="https://<your-resource>.services.ai.azure.com/models" \
  -e AZURE_AI_API_KEY="<key>" \
  -e AZURE_AI_MODEL="mistral-small-2503" \
  pavbot
```

---

## 1. Push to GitHub

```bash
cd chatbot-app
git init
git add .
git commit -m "Initial commit: Flask chatbot with Dockerfile"
git branch -M main
git remote add origin https://github.com/<your-username>/pavbot.git
git push -u origin main
```

---

## 2. Import into Azure Repos (UI)

1. Go to **dev.azure.com** → your organization → **New project** → name it `pavbot` → Create.
2. Left menu → **Repos** → **Import a repository** (or click **Import** under "Import a repository").
3. Clone URL: `https://github.com/<your-username>/pavbot.git` → **Import**.
   - If the GitHub repo is private, tick **Requires authentication** and paste a GitHub PAT.

---

## 3. Create Azure Container Registry (Azure Portal)

1. Portal → **Create a resource** → search **Container Registry** → Create.
2. Resource group: `rg-pavbot` (create new) · Registry name: `pavbotacr<unique>` · SKU: **Basic**.
3. Review + Create. After deployment, open the registry → **Settings → Access keys** → enable **Admin user** (needed later for App Service pull).

---

## 4. Build pipeline via the Azure DevOps UI wizard

1. Azure DevOps → **Pipelines → Create Pipeline**.
2. **Where is your code?** → **Azure Repos Git** → select `pavbot`.
3. **Configure your pipeline** → choose **Docker — Build and push an image to Azure Container Registry**.
4. Select your **Azure subscription** → Continue (sign in if prompted).
5. Select the **Container registry** you created, keep image name (e.g. `pavbot`), Dockerfile path `$(Build.SourcesDirectory)/Dockerfile`.
6. Click **Validate and configure** — the wizard generates `azure-pipelines.yml` for you.
7. Click **Save and run** → Commit directly to `main`.
8. Watch the run: it builds the Docker image and pushes it to ACR tagged with the build ID.
   - First run may ask you to **authorize** the auto-created service connection — click Permit.
   - Free-tier note: if you see "No hosted parallelism", request the free grant at aka.ms/azpipelines-parallelism-request.

Verify: Portal → your ACR → **Repositories** → you should see `pavbot` with a tag.

---

## 5. Create the Web App for Containers (Azure Portal)

1. Portal → **Create a resource** → **Web App**.
2. Resource group `rg-pavbot` · Name `pavbot-app-<unique>` · **Publish: Container** · OS: **Linux** · Plan: **B1** (or F1 Free).
3. **Container tab**: Image source → **Azure Container Registry** → pick your registry, image `pavbot`, tag (latest build number).
4. Review + Create.
5. After deployment: Web App → **Settings → Environment variables** → add all four → Save (app restarts):

   | Name | Value |
   |---|---|
   | `WEBSITES_PORT` | `8000` |
   | `AZURE_AI_ENDPOINT` | `https://<your-resource>.services.ai.azure.com/models` |
   | `AZURE_AI_API_KEY` | your Foundry key |
   | `AZURE_AI_MODEL` | `mistral-small-2503` |

   (Better practice for later: store the key in **Key Vault** and use a Key Vault reference `@Microsoft.KeyVault(SecretUri=...)` as the value.)
6. Browse to `https://pavbot-app-<unique>.azurewebsites.net` — the chatbot should load and answer via the Foundry model.
7. Quick check: open `/health` — it returns `"foundry_configured": true` when the env vars are picked up.

---

## 6. Continuous deployment (UI, zero YAML)

Option A — **Portal CD toggle (simplest)**:
1. Web App → **Deployment Center** → Source shows Container Registry.
2. Turn **Continuous deployment: On** → Save. This creates an ACR **webhook**: every time the pipeline pushes a new image tag/`latest`, App Service pulls and restarts automatically.
   - Tip: in the pipeline YAML tags section, add `latest` under `tags:` so the webhook always fires on the same tag.

Option B — **Release pipeline (classic UI)**:
1. Azure DevOps → **Pipelines → Releases → New pipeline** → template **Azure App Service deployment**.
2. Add artifact → source: your Build pipeline → enable the **continuous deployment trigger** (lightning bolt).
3. In Stage 1 task: pick subscription, App type **Web App for Containers (Linux)**, your app name, registry/image/tag `$(Build.BuildId)`.
4. Save → Create release. Every successful build now triggers a release to App Service.

---

## 7. Test the full loop

1. Edit `app.py` — e.g. change a bot reply.
2. Commit + push to Azure Repos `main` (or edit directly in the Repos web UI).
3. Pipeline triggers automatically → new image in ACR → App Service pulls the new container.
4. Refresh the site (allow ~1–2 min for restart).

---

## Endpoints

| Route | Purpose |
|---|---|
| `/` | Chat UI |
| `/api/chat` (POST) | `{"message": "..."}` → `{"reply": "..."}` |
| `/health` | Health probe for App Service |

## Cleanup

Delete the resource group `rg-pavbot` to remove everything (ACR + App Plan + Web App) in one shot.
