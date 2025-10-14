// lib/constants/api_endpoints.dart
class ApiEndpoints {
  // Base paths
  static const String admin = '/admin';
  static const String user = '';
  
  // Admin endpoints
  static const String createUser = '$admin/create-user';
  
  // User endpoints
  static const String scan = '/scan';
  static const String stats = '/stats';
  static const String history = '/history';
  static const String download = '/download';
  
  // Dynamic endpoints (require parameters)
  static String status(String jobId) => '/status/$jobId';
  static String result(String jobId) => '/result/$jobId';
  static String pentest(String jobId) => '/pentest/$jobId';
  static String anomaly(String jobId) => '/anomaly/$jobId';
  static String gemini(String jobId) => '/gemini/$jobId';
  static String downloadFile(String jobId) => '$download/$jobId';
  
  // Query parameters
  static const String runPentestParam = 'run_pentest';
  static const String runAnomalyParam = 'run_anomaly';
  static const String useGeminiParam = 'use_gemini';
  static const String geminiApiKeyParam = 'gemini_api_key';
  static const String usernameParam = 'username';
  
  // Headers
  static const String authorizationHeader = 'Authorization';
  static const String adminKeyHeader = 'X-Admin-Key';
}

