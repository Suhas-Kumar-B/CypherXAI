# Fix: Web File Upload Error

## Problem

When uploading APK files on Flutter Web, you're getting this error:
```
Error picking file:
On web `path` is unavailable and accessing it causes this exception.
You should access `bytes` property instead
```

## Root Cause

The `file_picker` package behaves differently on web platforms:
- **Mobile/Desktop**: Files have a `path` property pointing to the file location
- **Web**: Files don't have a `path` (browser security), only `bytes` property

## Solution

You need to update your file upload code to handle both platforms correctly.

---

## Step 1: Update Scan Service

Find the file upload code in your scan service (likely `lib/services/scan_service.dart` or `lib/services/api_client.dart`).

### Before (Broken on Web):
```dart
Future<void> uploadApk(PlatformFile file) async {
  var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/scan'));
  
  // ❌ This fails on web - path is null
  request.files.add(await http.MultipartFile.fromPath(
    'file',
    file.path!,  // <-- ERROR: path is null on web
    filename: file.name,
  ));
  
  var response = await request.send();
}
```

### After (Works on All Platforms):
```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> uploadApk(PlatformFile file) async {
  var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/scan'));
  
  // ✅ Handle web and mobile/desktop differently
  if (kIsWeb) {
    // On web, use bytes
    if (file.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ));
    } else {
      throw Exception('File bytes are null');
    }
  } else {
    // On mobile/desktop, use path
    if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path!,
        filename: file.name,
      ));
    } else {
      throw Exception('File path is null');
    }
  }
  
  var response = await request.send();
}
```

---

## Step 2: Update File Picker Code

Find where you're picking the APK file (likely in `lib/pages/dashboard.dart`).

### Recommended File Picker Setup:
```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> _pickAndUploadApk() async {
  try {
    // Pick file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
      withData: kIsWeb, // Important: Load bytes on web
      withReadStream: !kIsWeb, // Use stream on mobile for large files
    );

    if (result != null && result.files.isNotEmpty) {
      PlatformFile file = result.files.first;
      
      // Validate file
      if (!file.name.toLowerCase().endsWith('.apk')) {
        _showError('Please select an APK file');
        return;
      }
      
      // Upload file
      await _uploadApk(file);
    }
  } catch (e) {
    _showError('Error picking file: $e');
  }
}

Future<void> _uploadApk(PlatformFile file) async {
  setState(() => _isUploading = true);
  
  try {
    // Call your API service
    await _apiClient.uploadApk(file);
    _showSuccess('APK uploaded successfully');
  } catch (e) {
    _showError('Upload failed: $e');
  } finally {
    setState(() => _isUploading = false);
  }
}
```

---

## Step 3: Complete API Client Example

Here's a complete example of an API client method that handles file uploads on all platforms:

```dart
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiClient {
  final String baseUrl;
  final String apiKey;

  ApiClient(this.baseUrl, this.apiKey);

  Future<Map<String, dynamic>> scanApk({
    required PlatformFile file,
    bool runPentest = true,
    bool runAnomaly = true,
    bool useGemini = false,
    String? geminiApiKey,
  }) async {
    try {
      // Build URL with query parameters
      final uri = Uri.parse('$baseUrl/scan').replace(queryParameters: {
        'run_pentest': runPentest.toString(),
        'run_anomaly': runAnomaly.toString(),
        'use_gemini': useGemini.toString(),
        if (geminiApiKey != null) 'gemini_api_key': geminiApiKey,
      });

      // Create multipart request
      var request = http.MultipartRequest('POST', uri);
      
      // Add authorization header
      request.headers['Authorization'] = apiKey;

      // Add file - platform-specific handling
      if (kIsWeb) {
        // Web: Use bytes
        if (file.bytes == null) {
          throw Exception('File bytes are null. Make sure to use withData: true when picking files on web.');
        }
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
        ));
      } else {
        // Mobile/Desktop: Use path
        if (file.path == null) {
          throw Exception('File path is null');
        }
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
        ));
      }

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error uploading APK: $e');
    }
  }
}
```

---

## Step 4: Update pubspec.yaml

Ensure you have the correct dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  file_picker: ^6.0.0  # Or latest version
```

---

## Step 5: Platform Detection Helper (Optional)

Create a helper file for platform-specific code:

```dart
// lib/utils/platform_helper.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class PlatformHelper {
  /// Pick file with appropriate settings for current platform
  static Future<FilePickerResult?> pickApkFile() async {
    return await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
      withData: kIsWeb,        // Load bytes on web
      withReadStream: !kIsWeb, // Use stream on mobile
    );
  }

  /// Create multipart file from PlatformFile for current platform
  static Future<http.MultipartFile> createMultipartFile(
    String fieldName,
    PlatformFile file,
  ) async {
    if (kIsWeb) {
      // Web: Use bytes
      if (file.bytes == null) {
        throw Exception('File bytes are null on web');
      }
      return http.MultipartFile.fromBytes(
        fieldName,
        file.bytes!,
        filename: file.name,
      );
    } else {
      // Mobile/Desktop: Use path
      if (file.path == null) {
        throw Exception('File path is null');
      }
      return await http.MultipartFile.fromPath(
        fieldName,
        file.path!,
        filename: file.name,
      );
    }
  }
}
```

Then use it in your code:

```dart
// Pick file
final result = await PlatformHelper.pickApkFile();
if (result != null && result.files.isNotEmpty) {
  final file = result.files.first;
  
  // Upload file
  var request = http.MultipartRequest('POST', uri);
  request.files.add(await PlatformHelper.createMultipartFile('file', file));
  // ... rest of upload code
}
```

---

## Quick Fix Checklist

- [ ] Import `kIsWeb` from `package:flutter/foundation.dart`
- [ ] Update file picker to use `withData: kIsWeb`
- [ ] Check if `kIsWeb` before accessing `file.path`
- [ ] Use `file.bytes` on web, `file.path` on mobile/desktop
- [ ] Use `MultipartFile.fromBytes()` on web
- [ ] Use `MultipartFile.fromPath()` on mobile/desktop
- [ ] Test on web browser
- [ ] Test on mobile/desktop (if applicable)

---

## Testing

### Test on Web:
```bash
cd cipherx_frontend
flutter run -d chrome
```

### Test on Desktop:
```bash
flutter run -d windows  # or macos, linux
```

### Test on Mobile:
```bash
flutter run -d android  # or ios
```

---

## Common Pitfalls

### ❌ Don't Do This:
```dart
// This will crash on web
request.files.add(await http.MultipartFile.fromPath('file', file.path!));
```

### ✅ Do This Instead:
```dart
// This works on all platforms
if (kIsWeb) {
  request.files.add(http.MultipartFile.fromBytes('file', file.bytes!));
} else {
  request.files.add(await http.MultipartFile.fromPath('file', file.path!));
}
```

---

## Additional Resources

- [file_picker FAQ](https://github.com/miguelpruivo/flutter_file_picker/wiki/FAQ)
- [Flutter Web File Upload Guide](https://docs.flutter.dev/platform-integration/web/file-handling)
- [http package documentation](https://pub.dev/packages/http)

---

## Example: Complete Dashboard Upload Widget

```dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';

class ApkUploadWidget extends StatefulWidget {
  @override
  _ApkUploadWidgetState createState() => _ApkUploadWidgetState();
}

class _ApkUploadWidgetState extends State<ApkUploadWidget> {
  bool _isUploading = false;
  String? _fileName;

  Future<void> _pickAndUploadFile() async {
    try {
      // Pick file with platform-specific settings
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['apk'],
        withData: kIsWeb,        // Important for web!
        withReadStream: !kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.first;
        
        setState(() {
          _fileName = file.name;
          _isUploading = true;
        });

        // Upload the file
        await _uploadFile(file);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload successful!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadFile(PlatformFile file) async {
    // Your upload logic here using the platform-aware code above
    await Future.delayed(Duration(seconds: 2)); // Simulate upload
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _pickAndUploadFile,
          icon: Icon(Icons.upload_file),
          label: Text(_isUploading ? 'Uploading...' : 'Upload APK'),
        ),
        if (_fileName != null)
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Selected: $_fileName'),
          ),
        if (_isUploading)
          CircularProgressIndicator(),
      ],
    );
  }
}
```

---

## Summary

The key to fixing this error is:

1. **Detect platform**: Use `kIsWeb` from `flutter/foundation.dart`
2. **Pick files correctly**: Use `withData: kIsWeb` when picking files
3. **Upload correctly**: Use `bytes` on web, `path` on mobile/desktop
4. **Use appropriate MultipartFile method**: `fromBytes()` for web, `fromPath()` for others

Apply these changes to your file upload code and the error will be resolved!
