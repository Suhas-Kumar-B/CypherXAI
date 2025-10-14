// lib/services/scan_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'api_client.dart';
import '../models/analysis.dart';

class ScanService extends ChangeNotifier {
  static final ScanService _instance = ScanService._internal();
  factory ScanService() => _instance;
  ScanService._internal();

  final ApiClient _apiClient = ApiClient();

  List<Analysis> _history = [];
  Analysis? _currentAnalysis;
  bool _isScanning = false;
  String? _currentJobId;

  List<Analysis> get history => List.unmodifiable(_history);
  Analysis? get currentAnalysis => _currentAnalysis;
  bool get isScanning => _isScanning;

  // Start a new scan with PlatformFile (web-compatible)
  Future<Analysis?> startScanWithFile({
    required String apiKey,
    required PlatformFile file,
    bool runPentest = true,
    bool runAnomaly = true,
    bool useGemini = false,
    String? geminiApiKey,
  }) async {
    try {
      _isScanning = true;
      notifyListeners();

      final response = await _apiClient.scanApkWithFile(
        apiKey: apiKey,
        file: file,
        runPentest: runPentest,
        runAnomaly: runAnomaly,
        useGemini: useGemini,
        geminiApiKey: geminiApiKey,
      );

      _currentJobId = response['job_id'] as String?;
      
      if (_currentJobId != null) {
        // Create the analysis object with initial data
        final analysis = Analysis(
          fileName: file.name,
          fileSize: file.size,
          status: response['status'] ?? 'processing',
          pentestEnabled: runPentest,
          anomalyEnabled: runAnomaly,
          geminiEnabled: useGemini,
        );
        
        _currentAnalysis = analysis;
        notifyListeners();

        // Poll for results
        return await _pollForResults(apiKey, _currentJobId!);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Scan error: $e');
      }
      _isScanning = false;
      notifyListeners();
      return null;
    }
  }

  // Start a new scan (legacy method for backward compatibility)
  Future<Analysis?> startScan({
    required String apiKey,
    required String filePath,
    bool runPentest = true,
    bool runAnomaly = true,
    bool useGemini = false,
    String? geminiApiKey,
  }) async {
    try {
      _isScanning = true;
      notifyListeners();

      final response = await _apiClient.scanApk(
        apiKey: apiKey,
        filePath: filePath,
        runPentest: runPentest,
        runAnomaly: runAnomaly,
        useGemini: useGemini,
        geminiApiKey: geminiApiKey,
      );

      _currentJobId = response['job_id'] as String?;
      
      if (_currentJobId != null) {
        // Create the analysis object with initial data
        final analysis = Analysis(
          fileName: filePath.split('/').last,
          fileSize: await File(filePath).length(),
          status: response['status'] ?? 'processing',
          pentestEnabled: runPentest,
          anomalyEnabled: runAnomaly,
          geminiEnabled: useGemini,
        );
        
        _currentAnalysis = analysis;
        notifyListeners();

        // Poll for results
        return await _pollForResults(apiKey, _currentJobId!);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Scan error: $e');
      }
      _isScanning = false;
      notifyListeners();
      return null;
    }
  }

  // Poll for scan results
  Future<Analysis?> _pollForResults(String apiKey, String jobId) async {
    const maxAttempts = 120; // 10 minutes with 5-second intervals
    int attempts = 0;

    while (attempts < maxAttempts) {
      try {
        // Get status
        final statusResponse = await _apiClient.getStatus(jobId, apiKey);
        final status = statusResponse['status'] as String? ?? 'processing';

        if (status == 'done' || status == 'failed') {
          if (status == 'done') {
            // Get full results
            final resultResponse = await _apiClient.getResult(jobId, apiKey);
            return _parseAnalysisFromResult(resultResponse);
          } else {
            // Scan failed
            _isScanning = false;
            notifyListeners();
            return null;
          }
        }

        // Continue polling
        await Future.delayed(const Duration(seconds: 5));
        attempts++;
      } catch (e) {
        if (kDebugMode) {
          print('Poll error: $e');
        }
        attempts++;
        await Future.delayed(const Duration(seconds: 5));
      }
    }

    _isScanning = false;
    notifyListeners();
    return null;
  }

  // Parse backend response into Analysis object
  Analysis _parseAnalysisFromResult(Map<String, dynamic> result, {String? jobId}) {
    final resultData = result['result'] as Map<String, dynamic>? ?? {};

    final anomaly = resultData['anomaly_detection'] as Map<String, dynamic>?;
    final double anomalyScore = anomaly != null
        ? (anomaly['score'] is num ? (anomaly['score'] as num).toDouble() : 0.0)
        : 0.0;

    final double confidence = (() {
      final c = resultData['confidence_score'] ?? resultData['confidence'];
      if (c is num) return c.toDouble();
      return 0.0;
    })();

    return Analysis(
      fileName: (resultData['file_name'] ?? 'Unknown').toString(),
      fileSize: (resultData['file_size'] ?? 0) as int,
      status: 'completed',
      prediction: resultData['prediction']?.toString(),
      confidence: confidence,
      anomalyScore: anomalyScore,
      pentestFindings: _parsePentestFindings(resultData),
      anomalyDetails: _parseAnomalyDetails(resultData),
      geminiReport: resultData['gemini_report']?.toString(),
      fullResult: resultData,
      dateTime: DateTime.now().toString(),
      id: jobId ?? _currentJobId,
    );
  }

  // Fetch a completed result for a given job id
  Future<Analysis?> fetchResultByJobId({required String apiKey, required String jobId}) async {
    try {
      final resultResponse = await _apiClient.getResult(jobId, apiKey);
      final analysis = _parseAnalysisFromResult(resultResponse, jobId: jobId);
      _currentAnalysis = analysis;
      notifyListeners();
      return analysis;
    } catch (_) {
      return null;
    }
  }

  List<PentestFinding> _parsePentestFindings(Map<String, dynamic> data) {
    try {
      final findings = data['pentest_findings'] as List? ?? [];
      return findings.map((finding) {
        return PentestFinding.fromJson(Map<String, dynamic>.from(finding));
      }).toList();
    } catch (e) {
      return [];
    }
  }

  AnomalyDetails? _parseAnomalyDetails(Map<String, dynamic> data) {
    try {
      final anomaly = data['anomaly_detection'] as Map<String, dynamic>?;
      if (anomaly != null) {
        final components = anomaly['components'] as Map<String, dynamic>?;
        if (components != null) {
          return AnomalyDetails.fromJson(components);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing anomaly details: $e');
      }
      return null;
    }
  }

  // Get scan history
  Future<List<Analysis>> loadHistory(String apiKey) async {
    try {
      final historyData = await _apiClient.getHistory(apiKey);
      _history = historyData.map((item) {
        // Parse confidence if available
        double? confidence;
        final confValue = item['confidence'] ?? item['confidence_score'];
        if (confValue != null && confValue is num) {
          confidence = confValue.toDouble();
        }
        
        return Analysis(
          fileName: (item['name'] ?? item['app_name'] ?? 'Unknown').toString(),
          fileSize: (item['file_size'] ?? 0) as int,
          status: _mapStatus(item['status']),
          prediction: item['prediction']?.toString(),
          confidence: confidence,
          dateTime: item['date_time']?.toString() ?? item['created_at']?.toString(),
          id: item['id']?.toString() ?? item['job_id']?.toString(),
          downloadUrl: item['download']?.toString() ?? (item['job_id'] != null ? '/download/${item['job_id']}' : null),
        );
      }).toList();
      
      notifyListeners();
      return _history;
    } catch (e) {
      if (kDebugMode) {
        print('Load history error: $e');
      }
      return [];
    }
  }

  String _mapStatus(dynamic status) {
    if (status == null) return 'pending';
    final statusStr = status.toString().toLowerCase();
    switch (statusStr) {
      case 'processing':
        return 'processing';
      case 'done':
        return 'completed';  // Map 'done' to 'completed' for display
      case 'completed':
        return 'completed';
      case 'failed':
      case 'not_found':
        return 'failed';
      default:
        return 'pending';
    }
  }

  // Download report
  Future<File?> downloadReport(String jobId, String apiKey, String targetPath) async {
    try {
      return await _apiClient.downloadReport(jobId, apiKey, targetPath);
    } catch (e) {
      if (kDebugMode) {
        print('Download error: $e');
      }
      return null;
    }
  }

  // Get Gemini report
  Future<String?> getGeminiReport(String jobId, String apiKey) async {
    try {
      return await _apiClient.getGeminiReport(jobId, apiKey);
    } catch (e) {
      if (kDebugMode) {
        print('Gemini report error: $e');
      }
      return null;
    }
  }

  // Reset current scan
  void resetCurrentScan() {
    _currentAnalysis = null;
    _currentJobId = null;
    _isScanning = false;
    notifyListeners();
  }
}
