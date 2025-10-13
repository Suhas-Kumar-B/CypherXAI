// lib/services/api_client.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({required this.baseUrl, this.defaultHeaders = const {}});
  final String baseUrl;
  final Map<String, String> defaultHeaders;
  
  final Dio dio = Dio();
  
  static const ADMIN_API_KEY = "your-secure-admin-key";

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
      final response = await http.post(
        uri,
        headers: _getHeaders(additionalHeaders: headers ?? {}),
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
      '/admin/create-user?username=$username',
      {},
      headers: {'X-Admin-Key': ADMIN_API_KEY},
    );
  }

  // Authentication: Login with API key
  Future<bool> authenticate(String apiKey) async {
    try {
      await getJson('/history', headers: {'Authorization': apiKey});
      return true;
    } catch (_) {
      return false;
    }
  }

  // Scan operations
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
      if (runPentest != null) 'run_pentest': runPentest.toString(),
      if (runAnomaly != null) 'run_anomaly': runAnomaly.toString(),
      if (useGemini) 'use_gemini': useGemini.toString(),
      if (geminiApiKey != null && geminiApiKey.isNotEmpty) 'gemini_api_key': geminiApiKey,
    };

    return await postFormData(
      '/scan',
      formData: formData,
      file: file,
      fileField: 'file',
      headers: {'Authorization': apiKey},
    );
  }

  // Check job status
  Future<Map<String, dynamic>> getStatus(String jobId, String apiKey) async {
    return await getJson('/status/$jobId', 
        headers: {'Authorization': apiKey});
  }

  // Get result
  Future<Map<String, dynamic>> getResult(String jobId, String apiKey) async {
    return await getJson('/result/$jobId', 
        headers: {'Authorization': apiKey});
  }

  // Get history
  Future<List<Map<String, dynamic>>> getHistory(String apiKey) async {
    final response = await getJson('/history', 
        headers: {'Authorization': apiKey});
    return List<Map<String, dynamic>>.from(response['items'] ?? []);
  }

  // Download report
  Future<File?> downloadReport(String jobId, String apiKey, String targetPath) async {
    try {
      final uri = Uri.parse('$baseUrl/download/$jobId');
      final response = await http.get(
        uri,
        headers: {'Authorization': apiKey},
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
      final response = await getJson('/gemini/$jobId', 
          headers: {'Authorization': apiKey});
      return response['gemini_report'] as String?;
    } catch (e) {
      return null;
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  
  @override
  String toString() => message;
}