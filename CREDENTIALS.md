# CypherXAI Test Credentials

## Default User Accounts

These accounts are automatically created when the backend starts for the first time.

---

### 👨‍💼 Admin User

**Username**: `admin@cipherx.com`  
**API Key**: `your-secure-admin-key` (or value from `ADMIN_API_KEY` environment variable)  
**Role**: `admin`

**Permissions**:
- Full access to all user features
- Access to admin dashboard
- User management capabilities
- Activity log viewing
- System administration

---

### 👤 Test User

**Username**: `testuser@cipherx.com`  
**API Key**: `test-user-api-key`  
**Role**: `user`

**Permissions**:
- APK scanning and analysis
- View own scan history
- Download scan reports
- View personal statistics
- No admin access

---

## Setting Custom Admin Key

### Before Starting Backend

**Windows PowerShell**:
```powershell
$env:ADMIN_API_KEY="your-custom-secure-key"
python -m uvicorn backend.main:app --reload
```

**Linux/Mac**:
```bash
export ADMIN_API_KEY="your-custom-secure-key"
python -m uvicorn backend.main:app --reload
```

### Permanent Configuration

Create a `.env` file in the project root:
```env
ADMIN_API_KEY=your-custom-secure-key
CORS_ALLOW_ORIGINS=http://localhost:3000,http://localhost:8080
```

Then use a package like `python-dotenv` to load it:
```python
from dotenv import load_dotenv
load_dotenv()
```

---

## Login Examples

### Using cURL

**Admin Login**:
```bash
curl -X POST http://localhost:8000/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin@cipherx.com",
    "api_key": "your-secure-admin-key"
  }'
```

**Test User Login**:
```bash
curl -X POST http://localhost:8000/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser@cipherx.com",
    "api_key": "test-user-api-key"
  }'
```

### Using Python Requests

```python
import requests

# Admin login
response = requests.post('http://localhost:8000/login', json={
    'username': 'admin@cipherx.com',
    'api_key': 'your-secure-admin-key'
})

result = response.json()
print(f"Success: {result['ok']}")
print(f"Role: {result['role']}")
print(f"Username: {result['username']}")
```

### Using Flutter/Dart

```dart
final response = await http.post(
  Uri.parse('http://localhost:8000/login'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'username': 'admin@cipherx.com',
    'api_key': 'your-secure-admin-key',
  }),
);

final data = jsonDecode(response.body);
if (data['ok'] == true) {
  print('Logged in as ${data['role']}');
}
```

---

## Creating Additional Users

### Via Admin API

**Using cURL**:
```bash
curl -X POST http://localhost:8000/admin/create-user \
  -H "X-Admin-Key: your-secure-admin-key" \
  -H "X-Admin-Email: admin@cipherx.com" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "newuser@example.com",
    "api_key": "custom-api-key-123",
    "role": "user"
  }'
```

### Via Database

**Using SQLite CLI**:
```bash
sqlite3 backend/cipherx.db

INSERT INTO users (api_key, username, role) 
VALUES ('new-api-key', 'newuser@example.com', 'user');

.exit
```

**Using Python**:
```python
from backend.db import create_user

# Create regular user
api_key = create_user('newuser@example.com', role='user')
print(f"Created user with API key: {api_key}")

# Create admin user
admin_key = create_user('newadmin@example.com', 
                        api_key='custom-admin-key', 
                        role='admin')
print(f"Created admin with API key: {admin_key}")
```

---

## Security Best Practices

### ⚠️ Important Notes

1. **Change Default Keys**: Always change the default admin key in production
2. **Strong Keys**: Use long, randomly generated keys (32+ characters)
3. **Environment Variables**: Never hardcode keys in source code
4. **HTTPS Only**: Use HTTPS in production to protect keys in transit
5. **Key Rotation**: Regularly rotate API keys
6. **Access Control**: Limit admin access to trusted personnel only

### Generating Secure Keys

**Python**:
```python
import secrets
secure_key = secrets.token_urlsafe(32)
print(secure_key)
```

**PowerShell**:
```powershell
$bytes = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
[Convert]::ToBase64String($bytes)
```

**Linux/Mac**:
```bash
openssl rand -base64 32
```

---

## Troubleshooting

### Login Fails

1. **Check credentials**: Verify username and API key are correct
2. **Check database**: Ensure user exists in database
   ```bash
   sqlite3 backend/cipherx.db "SELECT * FROM users;"
   ```
3. **Check backend logs**: Look for authentication errors
4. **Verify backend is running**: Ensure backend server is accessible

### Admin Access Denied

1. **Verify role**: Check user has 'admin' role in database
   ```bash
   sqlite3 backend/cipherx.db "SELECT username, role FROM users WHERE username='admin@cipherx.com';"
   ```
2. **Check master key**: Verify `ADMIN_API_KEY` environment variable is set correctly
3. **Check headers**: Ensure `X-Admin-Key` header is included in admin requests

### Database Issues

**Reset database** (⚠️ destroys all data):
```bash
rm backend/cipherx.db
python -c "from backend.db import init_db; init_db()"
```

**View all users**:
```bash
sqlite3 backend/cipherx.db "SELECT username, role FROM users;"
```

**Update user role**:
```bash
sqlite3 backend/cipherx.db "UPDATE users SET role='admin' WHERE username='user@example.com';"
```

---

## Quick Start

1. **Set admin key** (optional):
   ```bash
   export ADMIN_API_KEY="my-secure-admin-key"
   ```

2. **Start backend**:
   ```bash
   cd backend
   python -m uvicorn main:app --reload
   ```

3. **Test login**:
   ```bash
   curl -X POST http://localhost:8000/login \
     -H "Content-Type: application/json" \
     -d '{"username": "admin@cipherx.com", "api_key": "your-secure-admin-key"}'
   ```

4. **Start frontend** and login with credentials above

---

## Support

For additional help:
- Check `BACKEND_CHANGES_SUMMARY.md` for technical details
- Check `FRONTEND_REFACTORING_GUIDE.md` for frontend integration
- Review backend logs for error messages
- Verify database state using SQLite CLI
