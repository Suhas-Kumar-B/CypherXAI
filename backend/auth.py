from fastapi import Security, HTTPException, status
from fastapi.security import APIKeyHeader

# Extract Authorization header without auto error to validate manually
api_key_header = APIKeyHeader(name="Authorization", auto_error=False)

# Example in-memory mapping of API keys to usernames — replace with real data source as needed
VALID_API_KEYS = {
    "cHTwg0kVjYIo-f0istmqKLLR8P6E9TR03TLIXBcuBfg": "user123",
    "anotherkey5678": "user456",
}

async def validate_api_key(api_key_header_value: str = Security(api_key_header)) -> str:
    """
    Validates that the Authorization header contains only the API key string.
    Returns the username mapped to the API key.
    Raises HTTP 401 if header is missing, 403 if key is invalid.
    """
    if not api_key_header_value:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header."
        )

    api_key = api_key_header_value.strip()

    username = VALID_API_KEYS.get(api_key)
    if not username:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": {
                    "code": "INVALID_KEY",
                    "message": "API key is invalid or revoked.",
                }
            },
        )
    return username

# Admin API key for admin endpoint protection
ADMIN_API_KEY = "your-secure-admin-key"

def is_admin(admin_key: str):
    if admin_key != ADMIN_API_KEY:
        raise HTTPException(status_code=403, detail="Forbidden: Invalid admin key")
    return True
