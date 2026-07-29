import pytest
from app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "healthy"
    assert "cloud_services" in data
    assert "azure_sql" in data["cloud_services"]
    assert "azure_ai_foundry" in data["cloud_services"]


def test_agent_endpoint(client):
    response = client.post("/api/agent", json={"prompt": "How do I update my 401(k)?"})
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "success"
    assert "AI HelpDesk Agent" in data["response"]