# backend/auth.py
from fastapi import Security, HTTPException, status
from fastapi.security import APIKeyHeader
from backend.db import get_username_for_api_key

api_key_header = APIKeyHeader(name="Authorization", auto_error=False)

# Admin API key for admin endpoint protection (set via env in prod)
ADMIN_API_KEY = "your-secure-admin-key"

async def validate_api_key(api_key_header_value: str = Security(api_key_header)) -> str:
    if not api_key_header_value:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header."
        )
    api_key = api_key_header_value.strip()
    username = get_username_for_api_key(api_key)
    if not username:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return username

def is_admin(admin_key: str):
    return admin_key == ADMIN_API_KEY
