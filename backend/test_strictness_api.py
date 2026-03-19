import asyncio
import httpx
from datetime import datetime
import json

BASE_URL = "http://localhost:8000/api"

async def test_api():
    # 1. Register a test user
    email = f"test_{int(datetime.now().timestamp())}@example.com"
    register_data = {
        "name": "Integration Test",
        "email": email,
        "password": "testpassword123"
    }
    
    async with httpx.AsyncClient() as client:
        print("Registering user...")
        resp = await client.post(f"{BASE_URL}/auth/register", json=register_data)
        assert resp.status_code == 201, f"Failed to register: {resp.text}"
        data = resp.json()
        token = data["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # 2. Get initial strictness status
        print("\nFetching initial strictness status...")
        resp = await client.get(f"{BASE_URL}/strictness/status", headers=headers)
        assert resp.status_code == 200
        status_data = resp.json()
        print(f"Status: {json.dumps(status_data, indent=2)}")
        assert status_data["warnings"] == 0
        assert status_data["strictness_level"] == "NORMAL"
        
        # 3. Evaluate Strictness (Should give us Warning 1 because no focus time today)
        print("\nEvaluating today's strictness...")
        today = datetime.now().strftime("%Y-%m-%d")
        resp = await client.post(f"{BASE_URL}/strictness/evaluate", headers=headers, json={"date": today})
        assert resp.status_code == 200
        eval_data = resp.json()
        print(f"Result: {json.dumps(eval_data, indent=2)}")
        assert eval_data["warnings"] == 1
        assert eval_data["strictness_level"] == "WARNING_1"
        assert len(eval_data["active_penalties"]) > 0
        
        print("\nAll API integration tests passed!")

if __name__ == "__main__":
    asyncio.run(test_api())
