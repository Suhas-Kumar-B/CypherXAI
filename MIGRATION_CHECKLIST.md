# CypherXAI Authentication Refactoring - Migration Checklist

## Overview
This checklist guides you through migrating from the old frontend-based authentication to the new centralized backend authentication system.

---

## ✅ Backend Migration (COMPLETED)

### Database Changes
- [x] Added `role` column to `users` table
- [x] Added migration support for existing databases
- [x] Implemented seed data for default users
- [x] Created `get_user_by_credentials()` function
- [x] Created `get_user_role()` function
- [x] Updated `create_user()` to accept role parameter

### API Changes
- [x] Created `LoginRequest` and `LoginResponse` models
- [x] Implemented `POST /login` endpoint
- [x] Added activity logging for login events
- [x] Updated imports in `main.py`

### Authentication Changes
- [x] Created `require_admin_role()` dependency
- [x] Enhanced `validate_api_key()` documentation
- [x] Maintained backward compatibility with existing endpoints

### Documentation
- [x] Created `BACKEND_CHANGES_SUMMARY.md`
- [x] Created `FRONTEND_REFACTORING_GUIDE.md`
- [x] Created `CREDENTIALS.md`
- [x] Created this migration checklist

---

## 📱 Frontend Migration (TODO)

### File: `lib/services/api_client.dart`
- [ ] Add `login(String username, String apiKey)` method
- [ ] Ensure proper error handling for network failures
- [ ] Test API client with both success and failure cases

### File: `lib/services/auth_service.dart`
- [ ] Remove `_admins` list of hardcoded admin emails
- [ ] Remove hardcoded `dummy@gmail.com` user check
- [ ] Remove any frontend-only role determination logic
- [ ] Refactor `login()` method to call backend endpoint
- [ ] Store `_currentRole` from backend response
- [ ] Update `isAdmin` getter to check `_currentRole`
- [ ] Ensure `logout()` clears all stored credentials
- [ ] Test with both admin and regular user credentials

### File: `lib/pages/login.dart`
- [ ] Update `_submit()` to use refactored `AuthService.login()`
- [ ] Update navigation logic based on backend-returned role
- [ ] Change password field label to "API Key"
- [ ] Update help dialog with new credentials
- [ ] Add proper error message display
- [ ] Test loading states and error handling
- [ ] Verify navigation to correct dashboard

### File: `lib/admin/admin_app_layout.dart` (if applicable)
- [ ] Verify admin checks use `AuthService.isAdmin`
- [ ] Remove any hardcoded admin email checks
- [ ] Test admin-only features are properly protected

### File: `lib/app_layout.dart` (if applicable)
- [ ] Verify user checks use `AuthService` properly
- [ ] Remove any hardcoded credential checks
- [ ] Test regular user features work correctly

---

## 🧪 Testing Checklist

### Backend Testing
- [ ] Start backend server successfully
- [ ] Verify database is created with seed users
- [ ] Test admin login via cURL/Postman
  ```bash
  curl -X POST http://localhost:8000/login \
    -H "Content-Type: application/json" \
    -d '{"username": "admin@cipherx.com", "api_key": "your-secure-admin-key"}'
  ```
- [ ] Test regular user login via cURL/Postman
  ```bash
  curl -X POST http://localhost:8000/login \
    -H "Content-Type: application/json" \
    -d '{"username": "testuser@cipherx.com", "api_key": "test-user-api-key"}'
  ```
- [ ] Test invalid credentials return proper error
- [ ] Verify login activity is logged
- [ ] Test existing API endpoints still work

### Frontend Testing
- [ ] Login with admin credentials
  - [ ] Verify successful authentication
  - [ ] Verify navigation to admin dashboard
  - [ ] Verify admin features are accessible
- [ ] Login with regular user credentials
  - [ ] Verify successful authentication
  - [ ] Verify navigation to user dashboard
  - [ ] Verify admin features are NOT accessible
- [ ] Test invalid credentials
  - [ ] Verify error message is displayed
  - [ ] Verify no navigation occurs
- [ ] Test network failure scenarios
  - [ ] Verify appropriate error handling
  - [ ] Verify app doesn't crash
- [ ] Test logout functionality
  - [ ] Verify credentials are cleared
  - [ ] Verify navigation to login screen

### Integration Testing
- [ ] Complete end-to-end flow as admin
  1. Login as admin
  2. Access admin dashboard
  3. Perform admin operations
  4. Logout
- [ ] Complete end-to-end flow as user
  1. Login as regular user
  2. Access user dashboard
  3. Perform user operations (e.g., scan APK)
  4. Logout
- [ ] Test role-based access control
  - [ ] Regular user cannot access admin endpoints
  - [ ] Admin can access all features
- [ ] Test session persistence (if implemented)
  - [ ] Close and reopen app
  - [ ] Verify user remains logged in (or is logged out)

---

## 🔒 Security Verification

### Environment Configuration
- [ ] Set `ADMIN_API_KEY` environment variable
- [ ] Verify admin key is not hardcoded in source
- [ ] Configure `CORS_ALLOW_ORIGINS` appropriately
- [ ] Ensure `.env` file is in `.gitignore`

### Database Security
- [ ] Verify `cipherx.db` has proper file permissions
- [ ] Confirm database file is in `.gitignore`
- [ ] Test that SQL injection is prevented
- [ ] Verify parameterized queries are used

### API Security
- [ ] Test that invalid API keys are rejected
- [ ] Verify role-based access control works
- [ ] Ensure sensitive data is not exposed in errors
- [ ] Test rate limiting (if implemented)

### Frontend Security
- [ ] Verify no hardcoded credentials remain
- [ ] Ensure API keys are not logged
- [ ] Consider implementing secure storage for keys
- [ ] Verify HTTPS is used in production

---

## 📊 Database Verification

### Check Seed Users
```bash
sqlite3 backend/cipherx.db "SELECT username, role FROM users;"
```
Expected output:
```
admin@cipherx.com|admin
testuser@cipherx.com|user
```

### Verify Schema
```bash
sqlite3 backend/cipherx.db "PRAGMA table_info(users);"
```
Should show `role` column exists.

### Check Activity Log
```bash
sqlite3 backend/cipherx.db "SELECT * FROM activity_log ORDER BY timestamp DESC LIMIT 5;"
```
Should show login activities after testing.

---

## 🚀 Deployment Checklist

### Pre-Deployment
- [ ] All tests passing
- [ ] No hardcoded credentials in code
- [ ] Environment variables documented
- [ ] Database migrations tested
- [ ] Backup existing database (if applicable)

### Production Configuration
- [ ] Generate strong, random `ADMIN_API_KEY`
- [ ] Configure production `CORS_ALLOW_ORIGINS`
- [ ] Set up HTTPS/SSL certificates
- [ ] Configure secure database storage
- [ ] Set up monitoring and logging

### Post-Deployment
- [ ] Verify backend is accessible
- [ ] Test login with production credentials
- [ ] Monitor error logs
- [ ] Verify role-based access control
- [ ] Test frontend-backend integration
- [ ] Create production admin users
- [ ] Document production credentials securely

---

## 🔄 Rollback Plan

If issues occur, follow these steps:

### Backend Rollback
1. Stop the backend server
2. Restore previous version from git:
   ```bash
   git checkout HEAD~1 backend/
   ```
3. Restore database backup (if needed)
4. Restart backend server

### Frontend Rollback
1. Restore previous version from git:
   ```bash
   git checkout HEAD~1 cipherx_frontend/lib/
   ```
2. Rebuild frontend application
3. Test with old authentication flow

### Database Rollback
```bash
# Backup current database
cp backend/cipherx.db backend/cipherx.db.backup

# Remove role column (if needed)
sqlite3 backend/cipherx.db "ALTER TABLE users DROP COLUMN role;"
```

---

## 📝 Post-Migration Tasks

### Documentation
- [ ] Update README with new authentication flow
- [ ] Document new API endpoints
- [ ] Update user guides with new credentials
- [ ] Create admin user management guide

### User Communication
- [ ] Notify users of authentication changes
- [ ] Provide new login credentials
- [ ] Offer support for migration issues
- [ ] Schedule training session (if needed)

### Monitoring
- [ ] Set up authentication failure alerts
- [ ] Monitor login activity
- [ ] Track API usage by role
- [ ] Review security logs regularly

### Future Enhancements
- [ ] Plan JWT token implementation
- [ ] Design password reset flow
- [ ] Consider 2FA implementation
- [ ] Plan API key rotation strategy

---

## 🆘 Troubleshooting

### Common Issues

**Issue**: Backend fails to start
- Check `ADMIN_API_KEY` is set
- Verify database file permissions
- Check for port conflicts

**Issue**: Login fails with valid credentials
- Verify user exists in database
- Check API key matches exactly
- Review backend logs for errors

**Issue**: Frontend cannot connect to backend
- Verify backend URL is correct
- Check CORS configuration
- Ensure backend is running

**Issue**: Role-based access not working
- Verify role is set correctly in database
- Check `get_user_role()` returns correct role
- Test with fresh login

---

## ✅ Sign-Off

### Backend Developer
- [ ] All backend changes implemented
- [ ] All backend tests passing
- [ ] Documentation complete
- [ ] Code reviewed

**Signed**: _________________ **Date**: _________

### Frontend Developer
- [ ] All frontend changes implemented
- [ ] All frontend tests passing
- [ ] Integration tested
- [ ] Code reviewed

**Signed**: _________________ **Date**: _________

### QA/Testing
- [ ] All test cases executed
- [ ] No critical bugs found
- [ ] Performance acceptable
- [ ] Security verified

**Signed**: _________________ **Date**: _________

### Project Manager
- [ ] All requirements met
- [ ] Documentation complete
- [ ] Ready for deployment
- [ ] Stakeholders informed

**Signed**: _________________ **Date**: _________

---

## 📚 Reference Documents

- `BACKEND_CHANGES_SUMMARY.md` - Detailed backend changes
- `FRONTEND_REFACTORING_GUIDE.md` - Frontend implementation guide
- `CREDENTIALS.md` - Test credentials and examples
- Backend API documentation: http://localhost:8000/docs

---

**Migration Status**: Backend Complete ✅ | Frontend Pending ⏳

**Last Updated**: 2025-10-13
