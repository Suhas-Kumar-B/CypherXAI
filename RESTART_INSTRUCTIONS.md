# Flutter App Restart Instructions

## Issue

After fixing the Material widget error in ResultsPage, the app needs a **full restart** (not hot reload) to apply the changes.

---

## Solution: Hot Restart the Flutter App

### Method 1: Using Flutter Commands

**Stop the current app:**
```bash
# Press Ctrl+C in the terminal where Flutter is running
```

**Restart the app:**
```bash
cd cipherx_frontend
flutter run -d chrome  # For web
# OR
flutter run            # For desktop/mobile
```

### Method 2: Using IDE (VS Code / Android Studio)

**VS Code:**
1. Press `Ctrl+Shift+P` (Windows) or `Cmd+Shift+P` (Mac)
2. Type "Flutter: Hot Restart"
3. Press Enter

**OR simply:**
1. Press `Shift+R` in the terminal where Flutter is running
2. This does a hot restart

**Android Studio:**
1. Click the Hot Restart button (⚡ with circular arrow)
2. OR press `Ctrl+\` (Windows) or `Cmd+\` (Mac)

### Method 3: Command Line Quick Restart

**While Flutter is running in terminal:**
```bash
# Type 'r' for hot reload
r

# Type 'R' (capital R) for hot restart
R

# Type 'q' to quit
q
```

---

## Why Hot Restart is Needed

**Hot Reload (lowercase 'r')**:
- Updates code changes
- Preserves app state
- ❌ **Does NOT** rebuild widget tree structure

**Hot Restart (uppercase 'R')**:
- Rebuilds entire app
- Resets app state
- ✅ **DOES** rebuild widget tree structure
- **REQUIRED** for Scaffold addition

---

## What to Expect After Restart

### ✅ Dashboard → View Full Result
```
Click "View Full Result" button
→ Should navigate to Results Page
→ Shows tabs: Overview, Pentesting, Anomaly, AI Report, Raw Data
→ NO Material widget error
```

### ✅ Correct Display
```
BENIGN
95%         ← ML Confidence (correct value)
0.060       ← Anomaly Score  
N           ← Security Issues

[Overview] [Pentesting] [Anomaly] [Raw Data]  ← Clickable tabs
```

### ✅ History → View Details
```
Click eye icon on any history item
→ Should navigate to Results Page
→ All tabs work correctly
→ NO Material widget error
```

---

## Troubleshooting

### If error persists after hot restart:

1. **Stop the app completely** (Ctrl+C)
2. **Clean Flutter build**:
   ```bash
   cd cipherx_frontend
   flutter clean
   flutter pub get
   ```
3. **Restart the app**:
   ```bash
   flutter run -d chrome
   ```

### If using web:

1. **Clear browser cache**: Press `Ctrl+Shift+Delete`
2. **Hard refresh**: Press `Ctrl+F5` or `Cmd+Shift+R`
3. **Restart Flutter**:
   ```bash
   flutter run -d chrome --web-renderer html
   ```

---

## Quick Fix Summary

**The fix has been applied to:** `lib/pages/results.dart`

**What was fixed:** Added `Scaffold` wrapper to provide Material context

**What you need to do:** 
1. Stop Flutter app (Ctrl+C)
2. Restart Flutter app (`flutter run`)
3. OR Press `R` (capital R) in terminal for hot restart

---

## Additional Issues Noticed

From your screenshot, I also noticed:

### 1. File Size Shows 0.00 MB
**Possible Issue**: Backend not returning file_size correctly

**Check**: 
```bash
# Verify in backend
sqlite3 backend/cipherx.db "SELECT job_id, file_size FROM jobs WHERE app_name LIKE '%PlayStation%';"
```

### 2. Confidence Shows 1%
**Possible Issue**: Confidence might be stored as 0-1 decimal instead of 0-100 percentage

**Already Fixed**: The frontend now converts: `confidence * 100 if confidence <= 1.0`

After restart, these values should display correctly!

---

## Final Checklist

After restarting:
- [ ] No "Material widget not found" error
- [ ] Results page displays with tabs
- [ ] All tabs are clickable
- [ ] Back button works
- [ ] Confidence shows correct percentage
- [ ] File size shows correct MB value
- [ ] Anomaly score displays
- [ ] Download button works

---

**Status**: Fix applied ✅ | Restart required ⚠️
