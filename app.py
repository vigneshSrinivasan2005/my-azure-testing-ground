import os

from flask import Flask, jsonify, render_template, request
from azure.ai.inference import ChatCompletionsClient
from azure.ai.inference.models import AssistantMessage, SystemMessage, UserMessage
from azure.core.credentials import AzureKeyCredential

app = Flask(__name__)

# --- Azure AI Foundry configuration (set these as App Service env vars) ---
# AZURE_AI_ENDPOINT    e.g. https://<your-resource>.services.ai.azure.com/models
# AZURE_AI_API_KEY     key from Foundry portal -> your deployment -> Keys
# AZURE_AI_MODEL       the deployment name (e.g. mistral-small-2503)
ENDPOINT = os.environ.get("AZURE_AI_ENDPOINT", "")
API_KEY = os.environ.get("AZURE_AI_API_KEY", "")
MODEL = os.environ.get("AZURE_AI_MODEL", "mistral-small-2503")

SYSTEM_PROMPT = (
    "You are PavBot, a concise and friendly assistant powered by Mistral on Azure AI Foundry, "
    "deployed to Azure App Service with CI/CD set up through the Azure Portal. "
    "Keep answers short and practical."
)

client = None
if ENDPOINT and API_KEY:
    client = ChatCompletionsClient(
        endpoint=ENDPOINT,
        credential=AzureKeyCredential(API_KEY),
    )


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/chat", methods=["POST"])
def chat():
    data = request.get_json(silent=True) or {}
    message = (data.get("message") or "").strip()
    history = data.get("history") or []  # [{role, content}, ...] from the browser

    if not message:
        return jsonify({"reply": "Say something first!"}), 400

    if client is None:
        return jsonify({
            "reply": "Azure AI Foundry is not configured. Set AZURE_AI_ENDPOINT, "
                     "AZURE_AI_API_KEY and AZURE_AI_MODEL."
        }), 500

    # Keep only the last 10 turns to bound token usage
    messages = [SystemMessage(content=SYSTEM_PROMPT)]
    for turn in history[-10:]:
        role, content = turn.get("role"), turn.get("content")
        if not content:
            continue
        if role == "user":
            messages.append(UserMessage(content=content))
        elif role == "assistant":
            messages.append(AssistantMessage(content=content))
    messages.append(UserMessage(content=message))

    try:
        response = client.complete(
            model=MODEL,
            messages=messages,
            max_tokens=500,
            temperature=0.7,
        )
        reply = response.choices[0].message.content
        return jsonify({"reply": reply})
    except Exception as e:
        app.logger.error(f"Foundry call failed: {e}")
        return jsonify({"reply": "Something went wrong talking to the model. Check App Service logs."}), 502


@app.route("/health")
def health():
    return jsonify({"status": "ok", "foundry_configured": client is not None})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
