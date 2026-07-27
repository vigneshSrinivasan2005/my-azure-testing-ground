import os
from flask import Flask, jsonify, render_template, request

app = Flask(__name__)


@app.route("/")
def home():
    return render_template("index.html")


@app.route("/api/agent", methods=["POST"])
def agent_response():
    data = request.get_json() or {}
    user_prompt = data.get("prompt", "")

    # Check for Azure AI Foundry config
    ai_endpoint = os.getenv("AZURE_AI_ENDPOINT")
    ai_model = os.getenv("AZURE_AI_MODEL", "mistral-small-2503")

    agent_reply = (
        f"AI HelpDesk Agent ({ai_model}): Echoing prompt '{user_prompt}'"
        if user_prompt
        else "Hello! How can I assist you with HR inquiries today?"
    )

    return jsonify({
        "status": "success",
        "response": agent_reply,
        "ai_configured": bool(ai_endpoint),
    })


@app.route("/health")
def health():
    sql_host = os.getenv("AZURE_SQL_HOST")
    storage_acc = os.getenv("AZURE_STORAGE_ACCOUNT")
    ai_endpoint = os.getenv("AZURE_AI_ENDPOINT")
    app_insights_key = os.getenv("APPINSIGHTS_INSTRUMENTATIONKEY")

    cloud_status = {
        "azure_sql": "configured" if sql_host else "local_sqlite_fallback",
        "azure_storage": "configured" if storage_acc else "local_blob_fallback",
        "azure_ai_foundry": "configured" if ai_endpoint else "local_nlp_fallback",
        "app_insights": "enabled" if app_insights_key else "disabled",
    }

    return jsonify({
        "status": "healthy",
        "service": "Intelligent HR HelpDesk API",
        "cloud_services": cloud_status,
    }), 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=True)