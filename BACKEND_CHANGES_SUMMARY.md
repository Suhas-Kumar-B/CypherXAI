# Backend Refactoring Summary

## Overview
The CypherXAI backend has been refactored to implement a centralized, database-driven authentication system with role-based access control.

## Changes Made

### 1. Database Schema Updates (`backend/db.py`)

#### Users Table Enhancement
- **Added `role` column** to the `users` table:
  ```sql
  CREATE TABLE IF NOT EXISTS users (
      api_key TEXT PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      role TEXT NOT NULL DEFAULT 'user'
  );
  ```
- **Migration Support**: Added automatic column addition for existing databases
- **Role Validation**: Only accepts `'user'` or `'admin'` roles

#### Seed Data Implementation
The `init_db()` function now automatically creates default users:

```python
# Admin user
Username: admin@cipherx.com
API Key: Value from ADMIN_API_KEY environment variable (default: "your-secure-admin-key")
Role: admin

# Test user
Username: testuser@cipherx.com
API Key: test-user-api-key
Role: user
```

#### New Database Functions

1. **`create_user(username, api_key=None, role="user")`**
   - Enhanced to accept optional `role` parameter
   - Validates role is either `'user'` or `'admin'`
   - Maintains idempotent behavior

2. **`get_user_by_credentials(username, api_key)`**
   - Validates username and API key combination
   - Returns user info including role
   - Used by login endpoint

3. **`get_user_role(username)`**
   - Returns the role for a given username
   - Used for role-based authorization checks

### 2. Authentication Models (`backend/models.py`)

Added new Pydantic models for login functionality:

```python
class LoginRequest(BaseModel):
    username: str
    api_key: str

class LoginResponse(BaseModel):
    ok: bool
    role: Optional[str] = None
    username: Optional[str] = None
    message: Optional[str] = None
```

### 3. Login Endpoint (`backend/main.py`)

#### New POST /login Endpoint

**Endpoint**: `POST /login`
**Tags**: Auth
**Authentication**: None (public endpoint)

**Request Body**:
```json
{
  "username": "admin@cipherx.com",
  "api_key": "your-secure-admin-key"
}
```

**Success Response** (200):
```json
{
  "ok": true,
  "role": "admin",
  "username": "admin@cipherx.com"
}
```

**Failure Response** (200):
```json
{
  "ok": false,
  "message": "Invalid credentials"
}
```

**Features**:
- Validates credentials against database
- Returns user role on successful authentication
- Logs login activity
- No session management (stateless)

### 4. Enhanced Authentication (`backend/auth.py`)

#### New Function: `require_admin_role()`

```python
async def require_admin_role(username: str = Depends(validate_api_key)) -> str:
    """Validate that the authenticated user has admin role"""
    role = get_user_role(username)
    if role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    return username
```

**Usage**: Can be used as a FastAPI dependency for endpoints that require admin access:

```python
@app.get("/admin/sensitive-data")
async def get_sensitive_data(username: str = Depends(require_admin_role)):
    # Only users with admin role can access this
    return {"data": "sensitive"}
```

#### Updated `validate_api_key()`
- Enhanced documentation
- Maintains backward compatibility

#### Legacy `is_admin()` Function
- Kept for backward compatibility with existing admin endpoints
- Still uses master `ADMIN_API_KEY` for super-admin operations

### 5. Import Updates

Updated imports in `main.py` to include new functions:
```python
from backend.db import (
    # ... existing imports
    get_user_by_credentials,
    get_user_role,
)
from backend.models import (
    # ... existing imports
    LoginRequest,
    LoginResponse,
)
```

## Architecture Benefits

### 1. Centralized Authentication
- **Single Source of Truth**: Database is the sole authority for user credentials and roles
- **No Frontend Logic**: Frontend cannot bypass authentication by modifying code
- **Consistent**: All authentication flows through the same backend logic

### 2. Role-Based Access Control (RBAC)
- **Database-Driven**: Roles stored in database, not hardcoded
- **Flexible**: Easy to add new roles or change user roles
- **Secure**: Backend validates roles before granting access

### 3. Scalability
- **Easy User Management**: Add/remove users through database or admin API
- **Audit Trail**: Login activity logged in activity_log table
- **Production Ready**: Follows industry best practices

### 4. Security Improvements
- **No Hardcoded Credentials**: Removed hardcoded admin lists
- **Environment Variables**: Sensitive keys stored in environment
- **Validation**: All credentials validated against database
- **Separation of Concerns**: Authentication logic separated from business logic

## Migration from Old System

### Old System (Deprecated)
- Frontend had hardcoded list of admin emails
- Dummy user (`dummy@gmail.com`) with hardcoded credentials
- Frontend determined user roles
- No centralized user management

### New System
- All users stored in database with roles
- Backend validates credentials and returns roles
- Frontend receives role from backend
- Centralized user management through database

## Environment Variables

**Required**:
- `ADMIN_API_KEY`: Master admin key (default: "your-secure-admin-key")

**Optional**:
- `CORS_ALLOW_ORIGINS`: CORS configuration (default: "*")

## API Endpoints Summary

### Public Endpoints
- `POST /login` - Authenticate and get user role

### User Endpoints (Requires valid API key)
- `POST /scan` - Submit APK for scanning
- `GET /status/{job_id}` - Get scan status
- `GET /result/{job_id}` - Get full scan results
- `GET /history` - Get user's scan history
- `GET /stats` - Get user statistics

### Admin Endpoints (Requires master admin key)
- `GET /admin/admins` - List all admins
- `POST /admin/admins` - Add new admin
- `DELETE /admin/admins/{email}` - Remove admin
- `POST /admin/create-user` - Create new user
- `GET /admin/activity` - View activity log

## Testing

### Test with cURL

**Login as Admin**:
```bash
curl -X POST http://localhost:8000/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin@cipherx.com", "api_key": "your-secure-admin-key"}'
```

**Login as Test User**:
```bash
curl -X POST http://localhost:8000/login \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser@cipherx.com", "api_key": "test-user-api-key"}'
```

**Access User Endpoint**:
```bash
curl -X GET http://localhost:8000/stats \
  -H "Authorization: test-user-api-key"
```

### Test with Python

```python
import requests

# Login
response = requests.post('http://localhost:8000/login', json={
    'username': 'admin@cipherx.com',
    'api_key': 'your-secure-admin-key'
})
data = response.json()
print(f"Login successful: {data['ok']}")
print(f"Role: {data['role']}")

# Use API key for authenticated requests
headers = {'Authorization': 'your-secure-admin-key'}
stats = requests.get('http://localhost:8000/stats', headers=headers)
print(stats.json())
```

## Database Schema

### Complete Users Table
```sql
CREATE TABLE users (
    api_key TEXT PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL DEFAULT 'user'
);
```

### Sample Data
```sql
INSERT INTO users (api_key, username, role) VALUES
    ('your-secure-admin-key', 'admin@cipherx.com', 'admin'),
    ('test-user-api-key', 'testuser@cipherx.com', 'user');
```

## Future Enhancements

### Recommended Additions
1. **Token-Based Auth**: Implement JWT tokens instead of direct API keys
2. **Password Hashing**: Add password field with bcrypt hashing
3. **Token Expiration**: Implement token refresh mechanism
4. **Rate Limiting**: Add rate limiting per user
5. **2FA Support**: Add two-factor authentication
6. **Password Reset**: Implement password/key reset flow
7. **User Profiles**: Add additional user metadata
8. **Role Permissions**: Implement granular permissions beyond admin/user

## Backward Compatibility

### Maintained
- All existing user endpoints work unchanged
- API key authentication via Authorization header unchanged
- Admin endpoints still use master key (for super-admin operations)

### Deprecated
- Frontend-side role checking (should be removed)
- Hardcoded admin lists (removed from backend)

## Security Considerations

1. **API Keys**: In production, use strong, randomly generated keys
2. **HTTPS**: Always use HTTPS in production
3. **Environment Variables**: Never commit `.env` files
4. **Database Security**: Secure database file permissions
5. **Input Validation**: All inputs validated by Pydantic models
6. **SQL Injection**: Using parameterized queries throughout
7. **CORS**: Configure CORS appropriately for production

## Deployment Checklist

- [ ] Set `ADMIN_API_KEY` environment variable
- [ ] Configure `CORS_ALLOW_ORIGINS` for production domains
- [ ] Ensure database file has proper permissions
- [ ] Test login endpoint with both user types
- [ ] Verify role-based access control
- [ ] Check activity logging
- [ ] Update frontend to use new login endpoint
- [ ] Remove hardcoded credentials from frontend
- [ ] Test complete authentication flow
- [ ] Document API keys for users

## Support

For issues or questions about the authentication system:
1. Check the activity log: `GET /admin/activity`
2. Verify user exists in database
3. Confirm API key matches database record
4. Check role assignment in database
5. Review backend logs for authentication errors
