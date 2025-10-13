// lib/models/analysis.dart
class PentestFinding {
  final String id;
  final String title;
  final String severity; // high | medium | low
  final String summary;
  final List<String> evidence;
  final String recommendation;

  PentestFinding({
    required this.id,
    required this.title,
    required this.severity,
    required this.summary,
    required this.evidence,
    required this.recommendation,
  });

  factory PentestFinding.fromJson(Map<String, dynamic> json) => PentestFinding(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        severity: json['severity'] ?? 'info',
        summary: json['summary'] ?? '',
        evidence: List<String>.from(json['evidence'] ?? []),
        recommendation: json['recommendation'] ?? '',
      );
}

class AnomalyDetails {
  final double uncertainty;
  final double voteStd;
  final double novelty;
  final int unseenFeatureCount;
  final int totalFeatureCount;
  final List<String> topFeatures;

  AnomalyDetails({
    required this.uncertainty,
    required this.voteStd,
    required this.novelty,
    required this.unseenFeatureCount,
    required this.totalFeatureCount,
    required this.topFeatures,
  });

  factory AnomalyDetails.fromJson(Map<String, dynamic> json) => AnomalyDetails(
        uncertainty: (json['uncertainty'] ?? 0).toDouble(),
        voteStd: (json['vote_std'] ?? 0).toDouble(),
        novelty: (json['novelty'] ?? 0).toDouble(),
        unseenFeatureCount: json['unseen_feature_count'] ?? 0,
        totalFeatureCount: json['total_feature_count'] ?? 0,
        topFeatures: List<String>.from(json['top_features'] ?? []),
      );
}

class Analysis {
  final String fileName;
  final int fileSize; // bytes
  final String? fileUrl;
  final String status; // pending | processing | completed
  final String? prediction; // benign | malicious | unknown
  final double? confidence; // 0-100
  final double? anomalyScore; // 0-1
  final bool pentestEnabled;
  final bool anomalyEnabled;
  final bool geminiEnabled;
  final List<PentestFinding> pentestFindings;
  final AnomalyDetails? anomalyDetails;
  final String? geminiReport;
  final Map<String, dynamic>? fullResult;
  final String? dateTime;
  final String? id;
  final String? downloadUrl;

  Analysis({
    required this.fileName,
    required this.fileSize,
    this.fileUrl,
    this.status = 'pending',
    this.prediction,
    this.confidence,
    this.anomalyScore,
    this.pentestEnabled = true,
    this.anomalyEnabled = true,
    this.geminiEnabled = false,
    this.pentestFindings = const [],
    this.anomalyDetails,
    this.geminiReport,
    this.fullResult,
    this.dateTime,
    this.id,
    this.downloadUrl,
  });

  factory Analysis.fromJson(Map<String, dynamic> json) => Analysis(
        fileName: json['file_name'] ?? '',
        fileSize: json['file_size'] ?? 0,
        fileUrl: json['file_url'],
        status: json['status'] ?? 'pending',
        prediction: json['prediction'],
        confidence: (json['confidence'] ?? 0).toDouble(),
        anomalyScore: (json['anomaly_score'] ?? 0).toDouble(),
        pentestEnabled: json['pentest_enabled'] ?? true,
        anomalyEnabled: json['anomaly_enabled'] ?? true,
        geminiEnabled: json['gemini_enabled'] ?? false,
        pentestFindings: (json['pentest_findings'] as List?)
                ?.map((e) => PentestFinding.fromJson(e))
                .toList() ??
            [],
        anomalyDetails: json['anomaly_details'] != null
            ? AnomalyDetails.fromJson(json['anomaly_details'])
            : null,
        geminiReport: json['gemini_report'],
        fullResult: json['full_result'] as Map<String, dynamic>?,
        dateTime: json['date_time'],
        id: json['id'],
        downloadUrl: json['download_url'],
      );
}
