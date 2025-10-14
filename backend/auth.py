# backend/auth.py
from fastapi import Security, HTTPException, status, Depends
from fastapi.security import APIKeyHeader
from backend.db import get_username_for_api_key, is_admin_user, get_user_role
import os

api_key_header = APIKeyHeader(name="Authorization", auto_error=False)

# Admin API key for admin endpoint protection (configured via env)
ADMIN_API_KEY = os.environ.get("ADMIN_API_KEY", "your-secure-admin-key")

async def validate_api_key(api_key_header_value: str = Security(api_key_header)) -> str:
    """Validate API key and return username"""
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

async def require_admin_role(username: str = Depends(validate_api_key)) -> str:
    """Validate that the authenticated user has admin role"""
    role = get_user_role(username)
    if role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    return username

def is_admin(admin_key: str, admin_email: str | None = None):
    """Legacy admin check using master key"""
    if not (ADMIN_API_KEY and admin_key == ADMIN_API_KEY):
        return False
    # Optional email check against admins table if provided
    if admin_email:
        return is_admin_user(admin_email)
    return True
