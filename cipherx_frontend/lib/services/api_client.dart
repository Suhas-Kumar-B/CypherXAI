// lib/services/api_client.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../constants/api_endpoints.dart';

class ApiClient {
  ApiClient()
      : baseUrl = const String.fromEnvironment('BASE_URL', defaultValue: 'http://127.0.0.1:8000'),
        defaultHeaders = const {};
  
  final String baseUrl;
  final Map<String, String> defaultHeaders;
  
  final Dio dio = Dio();
  
  // Use the same default admin key as the backend
  static const ADMIN_API_KEY = String.fromEnvironment('ADMIN_API_KEY', defaultValue: 'your-secure-admin-key');

  // Helper to make API calls
  Map<String, String> _getHeaders({Map<String, String>? additionalHeaders}) {
    return {...defaultHeaders, ...?additionalHeaders};
  }

  // GET request
  Future<Map<String, dynamic>> getJson(String path,
      {Map<String, String>? headers, Map<String, String>? query}) async {
    try {
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
      final response = await http.get(uri, headers: _getHeaders(additionalHeaders: headers));
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiException('GET $path failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  // POST JSON
  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body,
      {Map<String, String>? headers}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final allHeaders = {
        'Content-Type': 'application/json',
        ..._getHeaders(additionalHeaders: headers ?? {}),
      };
      final response = await http.post(
        uri,
        headers: allHeaders,
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiException('POST $path failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  // POST with file upload (multipart)
  Future<Map<String, dynamic>> postFormData(String path, 
      {Map<String, String>? formData, File? file, String? fileField, Map<String, String>? headers}) async {
    try {
      final dio = Dio();
      final formDataToSend = FormData();

      // Add form fields
      if (formData != null) {
        formData.forEach((key, value) {
          formDataToSend.fields.add(MapEntry(key, value));
        });
      }

      // Add file if provided
      if (file != null && fileField != null) {
        formDataToSend.files.add(
          MapEntry(
            fileField,
            await MultipartFile.fromFile(
              file.path,
              filename: file.path.split('/').last,
            ),
          ),
        );
      }

      final allHeaders = {..._getHeaders(), ...?headers};
      final response = await dio.post(
        '$baseUrl$path',
        data: formDataToSend,
        options: Options(
          headers: allHeaders,
          contentType: 'multipart/form-data',
        ),
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 200 && statusCode < 300) {
        return response.data as Map<String, dynamic>;
      }
      throw ApiException('POST $path failed: $statusCode');
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  // Admin: Create user (POST)
  Future<Map<String, dynamic>> createUser(String username) async {
    // Endpoint expects POST with header X-Admin-Key and query param username
    return await postJson(
      '${ApiEndpoints.createUser}?${ApiEndpoints.usernameParam}=$username',
      {},
      headers: {
        ApiEndpoints.adminKeyHeader: ADMIN_API_KEY,
        'X-Admin-Email': 'admin@cipherx.com',
      },
    );
  }

  // Admin: Create user with provided API key (POST JSON)
  Future<Map<String, dynamic>> createUserWithKey({
    required String username,
    required String apiKey,
  }) async {
    return await postJson(
      ApiEndpoints.createUser,
      { 'username': username, 'api_key': apiKey },
      headers: {
        ApiEndpoints.adminKeyHeader: ADMIN_API_KEY,
        'X-Admin-Email': 'admin@cipherx.com',
      },
    );
  }

  // Authentication: Login with API key
  Future<bool> authenticate(String apiKey) async {
    try {
      await getJson(ApiEndpoints.history, headers: {ApiEndpoints.authorizationHeader: apiKey});
      return true;
    } catch (_) {
      return false;
    }
  }

  // Scan operations with PlatformFile (web-compatible)
  Future<Map<String, dynamic>> scanApkWithFile({
    required String apiKey,
    required PlatformFile file,
    bool runPentest = true,
    bool runAnomaly = true,
    bool useGemini = false,
    String? geminiApiKey,
  }) async {
    try {
      final dio = Dio();
      final formData = FormData();

      // Add file - platform-specific handling
      if (kIsWeb) {
        // Web: Use bytes
        if (file.bytes == null) {
          throw ApiException('File bytes are null. This should not happen with withData: true');
        }
        formData.files.add(MapEntry(
          'file',
          MultipartFile.fromBytes(
            file.bytes!,
            filename: file.name,
          ),
        ));
      } else {
        // Mobile/Desktop: Use path
        if (file.path == null) {
          throw ApiException('File path is null on non-web platform');
        }
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(
            file.path!,
            filename: file.name,
          ),
        ));
      }

      // Build URL with query parameters
      final queryParams = {
        if (runPentest) ApiEndpoints.runPentestParam: runPentest.toString(),
        if (runAnomaly) ApiEndpoints.runAnomalyParam: runAnomaly.toString(),
        if (useGemini) ApiEndpoints.useGeminiParam: useGemini.toString(),
        if (geminiApiKey != null && geminiApiKey.isNotEmpty) 
          ApiEndpoints.geminiApiKeyParam: geminiApiKey,
      };

      final uri = Uri.parse('$baseUrl${ApiEndpoints.scan}').replace(queryParameters: queryParams);

      final response = await dio.post(
        uri.toString(),
        data: formData,
        options: Options(
          headers: {
            ApiEndpoints.authorizationHeader: apiKey,
          },
          contentType: 'multipart/form-data',
        ),
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 200 && statusCode < 300) {
        return response.data as Map<String, dynamic>;
      }
      throw ApiException('Scan failed: $statusCode');
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  // Scan operations (legacy method for backward compatibility)
  Future<Map<String, dynamic>> scanApk({
    required String apiKey,
    required String filePath,
    bool runPentest = true,
    bool runAnomaly = true,
    bool useGemini = false,
    String? geminiApiKey,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ApiException('File not found: $filePath');
    }

    final Map<String, String> formData = {
      if (runPentest != null) ApiEndpoints.runPentestParam: runPentest.toString(),
      if (runAnomaly != null) ApiEndpoints.runAnomalyParam: runAnomaly.toString(),
      if (useGemini) ApiEndpoints.useGeminiParam: useGemini.toString(),
      if (geminiApiKey != null && geminiApiKey.isNotEmpty) ApiEndpoints.geminiApiKeyParam: geminiApiKey,
    };

    return await postFormData(
      ApiEndpoints.scan,
      formData: formData,
      file: file,
      fileField: 'file',
      headers: {ApiEndpoints.authorizationHeader: apiKey},
    );
  }

  // Check job status
  Future<Map<String, dynamic>> getStatus(String jobId, String apiKey) async {
    return await getJson(ApiEndpoints.status(jobId), 
        headers: {ApiEndpoints.authorizationHeader: apiKey});
  }

  // Get result
  Future<Map<String, dynamic>> getResult(String jobId, String apiKey) async {
    return await getJson(ApiEndpoints.result(jobId), 
        headers: {ApiEndpoints.authorizationHeader: apiKey});
  }

  // Get history
  Future<List<Map<String, dynamic>>> getHistory(String apiKey) async {
    final response = await getJson(ApiEndpoints.history, 
        headers: {ApiEndpoints.authorizationHeader: apiKey});
    return List<Map<String, dynamic>>.from(response['items'] ?? []);
  }

  // Download report
  Future<File?> downloadReport(String jobId, String apiKey, String targetPath) async {
    try {
      final uri = Uri.parse('$baseUrl${ApiEndpoints.downloadFile(jobId)}');
      final response = await http.get(
        uri,
        headers: {ApiEndpoints.authorizationHeader: apiKey},
      );

      if (response.statusCode == 200) {
        final file = File(targetPath);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get Gemini report
  Future<String?> getGeminiReport(String jobId, String apiKey) async {
    try {
      final response = await getJson(ApiEndpoints.gemini(jobId), 
          headers: {ApiEndpoints.authorizationHeader: apiKey});
      return response['gemini_report'] as String?;
    } catch (e) {
      return null;
    }
  }

  // Get dashboard statistics
  Future<Map<String, dynamic>> getStats(String apiKey) async {
    return await getJson(ApiEndpoints.stats, headers: {ApiEndpoints.authorizationHeader: apiKey});
  }

  // ----- Admin endpoints -----
  Future<List<String>> getAdmins() async {
    final res = await getJson('/admin/admins', headers: {
      ApiEndpoints.adminKeyHeader: ADMIN_API_KEY,
      'X-Admin-Email': 'admin@cipherx.com',
    });
    final list = (res['admins'] as List?) ?? [];
    return List<String>.from(list);
  }

  Future<void> addAdminEmail(String email) async {
    await postJson('/admin/admins', { 'email': email }, headers: {
      ApiEndpoints.adminKeyHeader: ADMIN_API_KEY,
      'X-Admin-Email': 'admin@cipherx.com',
    });
  }

  Future<void> removeAdminEmail(String email) async {
    // Simple DELETE via http since postJson is JSON-only; we can extend if needed
    final uri = Uri.parse('$baseUrl/admin/admins/$email');
    final resp = await http.delete(uri, headers: _getHeaders(additionalHeaders: {
      ApiEndpoints.adminKeyHeader: ADMIN_API_KEY,
      'X-Admin-Email': 'admin@cipherx.com',
    }));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException('Failed to remove admin: ${resp.statusCode} ${resp.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getActivityLog() async {
    final res = await getJson('/admin/activity', headers: {
      ApiEndpoints.adminKeyHeader: ADMIN_API_KEY,
      'X-Admin-Email': 'admin@cipherx.com',
    });
    return List<Map<String, dynamic>>.from((res['items'] as List?) ?? []);
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  
  @override
  String toString() => message;
}