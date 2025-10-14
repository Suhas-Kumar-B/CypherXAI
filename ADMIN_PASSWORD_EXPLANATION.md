# Admin Password & Authentication ✅

## How Admin Login Works

### 🔑 ALL Admins Share the SAME Master Key

**Important**: There is NO individual password per admin. All admins use the same master admin key.

```
Master Admin Key: your-secure-admin-key
```

This is set in:
- **Backend**: `backend/auth.py` → `ADMIN_API_KEY` environment variable
- **Frontend**: `lib/services/api_client.dart` → `ADMIN_API_KEY` constant

---

## Adding New Admins

### What Happens When You Add an Admin

1. **Backend**: Email is added to the `admins` table in the database
2. **Frontend**: Admin list is fetched from backend during login

### How to Login as New Admin

**Email**: `suhas@cipher.com` (or any email you added)  
**Password**: `your-secure-admin-key` (the SAME key for all admins)

---

## Step-by-Step Process

### 1. Add New Admin via Admin Panel
```
Admin Panel → Manage Admins
Email: suhas@cipher.com
Click "Add User"
✅ Email added to backend database
```

### 2. Logout
```
Click Logout button
```

### 3. Login with New Admin
```
Email: suhas@cipher.com
Password: your-secure-admin-key  ← Same master key
✅ Frontend fetches admin list from backend
✅ Verifies email is in the list
✅ Login successful
```

---

## Authentication Flow

```
┌─────────────────────────────────────────────────┐
│ User enters email & password on login page      │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│ Is password == "your-secure-admin-key"?         │
└──────────────────┬──────────────────────────────┘
                   │
           ┌───────┴────────┐
           │                │
          YES              NO
           │                │
           ▼                ▼
┌──────────────────┐  ┌─────────────────────┐
│ Fetch admin list │  │ Try as regular user │
│ from backend     │  │ with API key        │
└────────┬─────────┘  └─────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│ Is email in backend's admin list?                │
└────────┬─────────────────────────────────────────┘
         │
    ┌────┴─────┐
    │          │
   YES        NO
    │          │
    ▼          ▼
┌────────┐  ┌──────────────┐
│ Admin  │  │ Login failed │
│ Login  │  │              │
└────────┘  └──────────────┘
```

---

## Examples

### Example 1: Default Admin
```
Email: admin@cipherx.com
Password: your-secure-admin-key
Result: ✅ Login successful (default admin)
```

### Example 2: Newly Added Admin
```
1. Add admin: suhas@cipher.com
2. Login with:
   Email: suhas@cipher.com
   Password: your-secure-admin-key  ← SAME key!
Result: ✅ Login successful
```

### Example 3: Non-Admin Email
```
Email: randomuser@gmail.com
Password: your-secure-admin-key
Result: ❌ Login failed (email not in admin list)
```

---

## Technical Details

### Backend (`backend/auth.py`)

```python
def is_admin(admin_key: str, admin_email: str | None = None):
    # Check master key
    if not (ADMIN_API_KEY and admin_key == ADMIN_API_KEY):
        return False
    # Check if email is in admins table
    if admin_email:
        return is_admin_user(admin_email)
    return True
```

### Frontend (`lib/services/auth_service.dart`)

```dart
Future<AuthResult> login(String email, String passwordOrKey) async {
  // Check if attempting admin login
  if (passwordOrKey == ApiClient.ADMIN_API_KEY) {
    // Fetch latest admin list from backend
    await _fetchAdminList();
    
    // Check if email is in admin list
    if (_admins.contains(email)) {
      _role = AuthRole.admin;
      return const AuthResult(ok: true, role: AuthRole.admin);
    }
  }
  // ... try as regular user
}
```

---

## Security Notes

### ⚠️ Production Deployment

**Never use the default admin key in production!**

Set a custom admin key using environment variables:

**Backend**:
```bash
export ADMIN_API_KEY="your-super-secret-production-key-here"
python -m uvicorn backend.main:app
```

**Frontend**:
```bash
flutter run -d chrome --dart-define=ADMIN_API_KEY="your-super-secret-production-key-here"
```

### Why One Master Key?

- **Simplicity**: Easy to manage and rotate
- **Backend Control**: Backend controls who is an admin via database
- **No Password Storage**: No need to store/hash individual admin passwords
- **Easy Rotation**: Change one key to rotate all admin access

### Adding/Removing Admins

- ✅ **Adding**: Just add email to database, no password needed
- ✅ **Removing**: Remove email from database, immediately revokes access
- ✅ **Key Rotation**: Change master key to force all admins to re-login

---

## Troubleshooting

### Issue: "Login failed" for new admin

**Cause**: Email not in backend's admin list

**Solution**:
1. Login as existing admin (e.g., `admin@cipherx.com`)
2. Go to "Manage Admins"
3. Add the email
4. Logout
5. Login with new admin email using the master key

### Issue: "Login failed" even with correct email

**Cause**: Master key mismatch between frontend and backend

**Solution**:
```bash
# Check backend key
echo $ADMIN_API_KEY  # Should match frontend

# Or use default
Backend: "your-secure-admin-key"
Frontend: "your-secure-admin-key"
```

---

## Summary

✅ **All admins share ONE master key**: `your-secure-admin-key`  
✅ **No individual passwords**: Email list controls who can login  
✅ **Dynamic admin list**: Fetched from backend on login  
✅ **Easy management**: Add/remove emails without password hassle  

**New Admin Login**:
- Email: `[any-email-you-added]`
- Password: `your-secure-admin-key` (always the same!)

🎉 **Your new admin `suhas@cipher.com` should now be able to login with the master admin key!**
