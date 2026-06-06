import requests

domains = ["auth0.openai.com", "auth.openai.com"]
paths = ["/oauth/device/code", "/oauth/device_authorization", "/device/code"]
client_id = "app_EMoamEEZ73f0CkXaXp7hrann"

for d in domains:
    for p in paths:
        url = f"https://{d}{p}"
        try:
            resp = requests.post(url, data={"client_id": client_id, "scope": "offline_access"}, headers={"User-Agent": "Mimir/1.0"})
            print(f"{url} -> {resp.status_code}")
        except Exception as e:
            print(f"{url} -> {e}")

