# Frontend Refactoring Guide

## Overview
This guide provides step-by-step instructions for refactoring the Flutter frontend to work with the new centralized authentication system.

## Backend Changes Summary

The backend has been updated with:
1. **Database Schema**: Added `role` column to `users` table (values: `'user'` or `'admin'`)
2. **Seed Users**: Automatically creates two users on startup:
   - **Admin**: `admin@cipherx.com` with API key from `ADMIN_API_KEY` env variable (default: `your-secure-admin-key`)
   - **Test User**: `testuser@cipherx.com` with API key `test-user-api-key`
3. **New Login Endpoint**: `POST /login` accepts username and API key, returns role
4. **Role-Based Auth**: Backend validates user roles for admin-only operations

## Frontend Changes Required

### 1. Update API Client (`lib/services/api_client.dart`)

Add a new login method to communicate with the backend:

```dart
Future<Map<String, dynamic>> login(String username, String apiKey) async {
  final response = await http.post(
    Uri.parse('$baseUrl/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'username': username,
      'api_key': apiKey,
    }),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Login failed: ${response.statusCode}');
  }
}
```

### 2. Update Authentication Service (`lib/services/auth_service.dart`)

#### Remove Hardcoded Logic:
- **Delete** the `_admins` list of hardcoded admin emails
- **Delete** the hardcoded check for `dummy@gmail.com` user
- **Delete** any frontend-only role determination logic

#### Refactor the Login Method:

```dart
class AuthService {
  final ApiClient _apiClient;
  String? _currentUser;
  String? _currentRole;
  String? _currentApiKey;

  AuthService(this._apiClient);

  String? get currentUser => _currentUser;
  String? get currentRole => _currentRole;
  bool get isAdmin => _currentRole == 'admin';

  Future<LoginResult> login(String email, String apiKey) async {
    try {
      // Call the backend login endpoint
      final response = await _apiClient.login(email, apiKey);
      
      if (response['ok'] == true) {
        // Store user information from backend response
        _currentUser = response['username'];
        _currentRole = response['role'];
        _currentApiKey = apiKey;
        
        return LoginResult(
          success: true,
          isAdmin: _currentRole == 'admin',
          username: _currentUser!,
        );
      } else {
        return LoginResult(
          success: false,
          errorMessage: response['message'] ?? 'Invalid credentials',
        );
      }
    } catch (e) {
      return LoginResult(
        success: false,
        errorMessage: 'Login failed: $e',
      );
    }
  }

  void logout() {
    _currentUser = null;
    _currentRole = null;
    _currentApiKey = null;
  }
}

class LoginResult {
  final bool success;
  final bool isAdmin;
  final String? username;
  final String? errorMessage;

  LoginResult({
    required this.success,
    this.isAdmin = false,
    this.username,
    this.errorMessage,
  });
}
```

### 3. Update Login Page (`lib/pages/login.dart`)

#### Simplify the Submit Logic:

```dart
Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    final result = await _authService.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (result.success) {
      // Navigate based on role returned by backend
      if (result.isAdmin) {
        Navigator.of(context).pushReplacementNamed('/admin');
      } else {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } else {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Login failed')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}
```

#### Update Help Dialog:

Replace the help text to reflect the new unified login system:

```dart
void _showHelpDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Login Help'),
      content: const Text(
        'Enter your username (email) and API key to access CypherX.\n\n'
        'Test Credentials:\n'
        '• Admin: admin@cipherx.com / your-secure-admin-key\n'
        '• User: testuser@cipherx.com / test-user-api-key\n\n'
        'Contact your administrator for access credentials.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
```

### 4. Update Form Labels

Change the password field label to reflect that it accepts an API key:

```dart
TextFormField(
  controller: _passwordController,
  decoration: const InputDecoration(
    labelText: 'API Key',
    hintText: 'Enter your API key',
    prefixIcon: Icon(Icons.key),
  ),
  obscureText: true,
  // ... rest of the field configuration
)
```

## Testing the Changes

### Test Credentials:

1. **Admin User**:
   - Username: `admin@cipherx.com`
   - API Key: `your-secure-admin-key` (or value of `ADMIN_API_KEY` environment variable)
   - Expected: Should navigate to Admin Dashboard

2. **Regular User**:
   - Username: `testuser@cipherx.com`
   - API Key: `test-user-api-key`
   - Expected: Should navigate to User Dashboard

### Verification Steps:

1. Start the backend server
2. Ensure the database is initialized (users are seeded automatically)
3. Run the Flutter app
4. Test login with both admin and regular user credentials
5. Verify navigation to correct dashboard based on role
6. Verify that admin-only features are accessible only to admin users

## Environment Variables

Make sure to set the `ADMIN_API_KEY` environment variable before starting the backend:

```bash
# Windows PowerShell
$env:ADMIN_API_KEY="your-secure-admin-key"

# Linux/Mac
export ADMIN_API_KEY="your-secure-admin-key"
```

## Security Notes

1. **No Hardcoded Credentials**: All authentication is now handled by the backend
2. **Role-Based Access**: User roles are determined by the database, not frontend logic
3. **API Key Storage**: Consider using secure storage (e.g., `flutter_secure_storage`) for storing API keys
4. **HTTPS**: In production, ensure all API calls use HTTPS
5. **Token Expiration**: Consider implementing token expiration and refresh mechanisms for production

## Migration Checklist

- [ ] Update `api_client.dart` with login method
- [ ] Refactor `auth_service.dart` to remove hardcoded logic
- [ ] Update `login.dart` submit handler
- [ ] Update login form labels and help text
- [ ] Test admin login flow
- [ ] Test regular user login flow
- [ ] Verify role-based navigation
- [ ] Verify admin-only features are protected
- [ ] Update any other components that check user roles

## Additional Recommendations

1. **Persistent Login**: Implement secure storage to persist login state across app restarts
2. **Error Handling**: Add comprehensive error handling for network failures
3. **Loading States**: Show appropriate loading indicators during authentication
4. **Session Management**: Consider implementing session timeout and automatic logout
5. **Password Reset**: Plan for API key regeneration workflow for production use
