import json
import sys
from urllib.request import Request, urlopen

BASE = "http://127.0.0.1:8000"
ADMIN_KEY = "your-secure-admin-key"

def create_user(username: str) -> str:
    url = f"{BASE}/admin/create-user?username={username}"
    req = Request(url, method="POST", headers={"X-Admin-Key": ADMIN_KEY})
    with urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data["api_key"]

def get_history(api_key: str) -> dict:
    req = Request(f"{BASE}/history", headers={"Authorization": api_key})
    with urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))

if __name__ == "__main__":
    api = create_user("alice")
    print("API:", api)
    hist = get_history(api)
    print(json.dumps(hist, indent=2))

