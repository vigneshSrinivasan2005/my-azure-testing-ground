from flask import Flask, jsonify, render_template, request

app = Flask(__name__)


@app.route("/")
def home():
    return render_template("index.html")


@app.route("/api/agent", methods=["POST"])
def agent_response():
    data = request.get_json() or {}
    user_prompt = data.get("prompt", "")

    # Placeholder AI Agent logic (e.g., call OpenAI / Azure OpenAI / LangChain)
    agent_reply = (
        f"AI Agent Echo: '{user_prompt}'"
        if user_prompt
        else "Hello! How can I assist you today?"
    )

    return jsonify({"status": "success", "response": agent_reply})


@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)