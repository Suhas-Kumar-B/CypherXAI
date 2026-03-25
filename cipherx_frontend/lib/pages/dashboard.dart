// lib/pages/dashboard.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../models/analysis.dart';
import '../models/user.dart';
import 'results.dart';
import '../services/auth_service.dart';
import '../services/scan_service.dart';
import '../services/admin_store.dart';
import '../services/api_client.dart';

class DashboardPage extends StatefulWidget {
  final Analysis? analysis;
  const DashboardPage({Key? key, this.analysis}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Checkboxes state
  bool runAnomaly = true;
  bool runPentest = false;
  bool runGemini = false;
  
  final ScanService scanService = ScanService();
  final ApiClient apiClient = ApiClient();
  String? selectedFilePath;
  bool isUploading = false;

  // Derive name from email if user.fullName is empty
  String _displayNameFor(User u) {
    if (u.fullName.trim().isNotEmpty) return u.fullName.trim();
    final local = u.email.split('@').first;
    final tokens = local.replaceAll(RegExp(r'[._]'), ' ').split(' ');
    return tokens.map((t) => t.isEmpty ? '' : '${t[0].toUpperCase()}${t.substring(1)}').join(' ').trim();
  }

  PlatformFile? selectedFile;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['apk'],
        withData: true, // Important: Load bytes for web compatibility
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          selectedFile = result.files.single;
          selectedFilePath = selectedFile!.name; // Use name instead of path for display
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _analyzeApk() async {
    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an APK file first')),
      );
      return;
    }

    final authService = AuthService();
    final apiKey = authService.apiKey;

    if (apiKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated with backend')),
      );
      return;
    }

    setState(() {
      isUploading = true;
    });

    try {
      final analysis = await scanService.startScanWithFile(
        apiKey: apiKey,
        file: selectedFile!,
        runAnomaly: runAnomaly,
        runPentest: runPentest,
        useGemini: runGemini,
        geminiApiKey: runGemini ? "your-gemini-api-key" : null,
      );

      if (analysis != null) {
        // Analysis completed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis completed: ${analysis.prediction?.toUpperCase()}')),
        );

        // Update parent layout to show the result
        // This would ideally navigate to a results page or refresh the dashboard
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analysis failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analysis error: $e')),
      );
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  Future<List<Analysis>> _loadRecentAnalyses() async {
    final authService = AuthService();
    final apiKey = authService.apiKey;
    
    if (apiKey == null) return [];
    
    try {
      return await scanService.loadHistory(apiKey);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _loadStats() async {
    final authService = AuthService();
    final apiKey = authService.apiKey;
    
    if (apiKey == null) return null;
    
    try {
      return await apiClient.getStats(apiKey);
    } catch (e) {
      return null;
    }
  }

  Future<Analysis?> _getLatestAnalysis() async {
    // First check if widget has analysis
    if (widget.analysis != null) {
      return widget.analysis;
    }
    
    // Otherwise, get the most recent from history
    final authService = AuthService();
    final apiKey = authService.apiKey;
    
    if (apiKey == null) return null;
    
    try {
      final history = await scanService.loadHistory(apiKey);
      if (history.isNotEmpty) {
        // Return the first (most recent) analysis
        return history.first;
      }
    } catch (e) {
      // Ignore errors
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF0F1620);
    final lastLogin = DateFormat('MMM d, y, h:mm:ss a').format(DateTime.now());

    Widget stat(String title, String value, IconData icon) {
      return Card(
        color: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF192330),
                child: Icon(icon, color: Colors.cyanAccent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget uploadCard() {
      return Card(
        color: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFF1E2D40),
                  child: Icon(Icons.shield, color: Colors.cyanAccent),
                ),
                SizedBox(width: 10),
                Text('Upload APK for Analysis',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 16),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF121A23),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: selectedFilePath == null
                    ? InkWell(
                        onTap: _pickFile,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(radius: 26, backgroundColor: Color(0xFF1F2A38), child: Icon(Icons.upload, color: Colors.white)),
                            SizedBox(height: 12),
                            Text('Drop your APK file here', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            SizedBox(height: 6),
                            Text('Or click to browse files', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            selectedFilePath!.split('/').last,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          const Text('APK file selected', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                selectedFilePath = null;
                              });
                            },
                            child: const Text('Remove file'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),

              // Two checkboxes in the requested order
              Row(
                children: [
                  Checkbox(
                    value: runAnomaly,
                    onChanged: (v) => setState(() => runAnomaly = v ?? false),
                    checkColor: Colors.black,
                    activeColor: Colors.cyanAccent,
                  ),
                  const Text('Run Anomaly Detection', style: TextStyle(color: Colors.white)),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                    value: runPentest,
                    onChanged: (v) => setState(() => runPentest = v ?? false),
                    checkColor: Colors.black,
                    activeColor: Colors.cyanAccent,
                  ),
                  const Text('Run Penetration Test', style: TextStyle(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedFilePath != null && !isUploading ? _analyzeApk : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: const Color(0xFF1E88E5),
                  ),
                  child: isUploading 
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 8),
                            Text('Analyzing...'),
                          ],
                        )
                      : Text(selectedFilePath == null ? 'Select APK first' : 'Analyze Now'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget recentAnalyses() {
      return FutureBuilder<List<Analysis>>(
        future: _loadRecentAnalyses(),
        builder: (context, snapshot) {
          final analyses = snapshot.data ?? [];
          
          Widget row(Analysis analysis) {
            final tag = analysis.prediction?.toUpperCase() ?? 'PENDING';
            final tagColor = tag == 'BENIGN' ? Colors.greenAccent : 
                           tag == 'MALICIOUS' ? Colors.redAccent : 
                           Colors.orangeAccent;
            final date = analysis.dateTime != null ? 
                analysis.dateTime!.split(' ').first :
                DateFormat('MMM d').format(DateTime.now());
            final time = analysis.dateTime != null ? 
                analysis.dateTime!.split(' ').length > 1 ? 
                analysis.dateTime!.split(' ')[1].split(':').take(2).join(':') : '00:00' :
                DateFormat('HH:mm').format(DateTime.now());

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Row(
                children: [
                  Icon(tag == 'BENIGN' ? Icons.check_circle : tag == 'MALICIOUS' ? Icons.error : Icons.hourglass_bottom,
                      color: tagColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(analysis.fileName, style: const TextStyle(color: Colors.white, fontSize: 13))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: tagColor.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                    child: Text(tag, style: TextStyle(color: tagColor, fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  Text(date, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(width: 8),
                  Text(time, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            );
          }

          return Card(
            color: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.history, color: Colors.cyanAccent),
                    SizedBox(width: 8),
                    Text('Recent Analyses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  if (analyses.isEmpty)
                    const Text('No recent analyses', style: TextStyle(color: Colors.grey, fontSize: 13))
                  else
                    ...analyses.take(3).map((analysis) => row(analysis)).toList(),
                ],
              ),
            ),
          );
        },
      );
    }

    Widget latestAnalysisCard(Analysis a) {
      final progress = (a.anomalyDetails == null || a.anomalyDetails!.totalFeatureCount == 0)
          ? (a.anomalyScore ?? 0.0)
          : ((a.anomalyDetails!.totalFeatureCount - a.anomalyDetails!.unseenFeatureCount) / a.anomalyDetails!.totalFeatureCount);

      return Card(
        color: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                const Icon(Icons.verified_user, color: Colors.greenAccent),
                const SizedBox(width: 10),
                const Text('Latest Analysis', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(a.status, style: const TextStyle(color: Colors.greenAccent)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Prediction
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Prediction', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (a.prediction?.toLowerCase() == 'benign' ? Colors.green : Colors.red).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24)
                      ),
                      child: Text(
                        (a.prediction ?? 'UNKNOWN').toUpperCase(),
                        style: TextStyle(
                          color: a.prediction?.toLowerCase() == 'benign' ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.w700
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('File Name', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    Text(a.fileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    const Text('Scanned', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    Text(a.dateTime ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 12),
                    const Text('Time', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    const Text('11:38', style: TextStyle(color: Colors.white)),
                  ]),
                ),
              ],
            ),
            if (a.anomalyScore != null) ...[
              const SizedBox(height: 16),
              const Text('Anomaly Score', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.white12,
                  color: Colors.greenAccent,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text((a.anomalyScore ?? 0).toStringAsFixed(3),
                    style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: 220,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final authService = AuthService();
                  final apiKey = authService.apiKey;
                  if (apiKey == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Not authenticated')),
                    );
                    return;
                  }
                  
                  // Show loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Loading analysis...')),
                  );
                  
                  // Always fetch the latest analysis
                  Analysis? analysisToShow = a;
                  
                  // If we have an ID, fetch full details
                  if (a.id != null) {
                    final fullAnalysis = await scanService.fetchResultByJobId(
                      apiKey: apiKey,
                      jobId: a.id!,
                    );
                    if (fullAnalysis != null) {
                      analysisToShow = fullAnalysis;
                    }
                  }
                  
                  // Navigate to results page
                  if (analysisToShow != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ResultsPage(analysis: analysisToShow),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to load analysis details')),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new, color: Colors.cyanAccent),
                label: const Text('View Full Result', style: TextStyle(color: Colors.cyanAccent)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.cyanAccent)),
              ),
            ),
          ]),
        ),
      );
    }


    return FutureBuilder<User>(
      future: User.me(),
      builder: (context, snapshot) {
        final userName = snapshot.hasData ? _displayNameFor(snapshot.data!) : 'Analyst';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header with "Welcome back, <userName>"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Security Dashboard', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Welcome back, $userName', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 2),
                    Text('Last login: $lastLogin', style: const TextStyle(color: Colors.cyanAccent)),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: const Row(children: [
                      Icon(Icons.show_chart, color: Colors.greenAccent, size: 16),
                      SizedBox(width: 6),
                      Text('System Online', style: TextStyle(color: Colors.greenAccent)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              FutureBuilder<Map<String, dynamic>?>(
                future: _loadStats(),
                builder: (context, snapshot) {
                  final stats = snapshot.data;
                  return Row(
                    children: [
                      Expanded(child: stat('Total Scans', '${stats?['total_scans'] ?? 0}', Icons.shield_outlined)),
                      const SizedBox(width: 12),
                      Expanded(child: stat('Threats Detected', '${stats?['threats_detected'] ?? 0}', Icons.warning_amber)),
                      const SizedBox(width: 12),
                      Expanded(child: stat('Processing Time', stats?['avg_processing_time'] ?? '<30s', Icons.access_time)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: uploadCard()),
                  const SizedBox(width: 16),
                  SizedBox(width: 340, child: recentAnalyses()),
                ],
              ),
              const SizedBox(height: 18),

              // Always show latest analysis - either from widget or from history
              FutureBuilder<Analysis?>(
                future: _getLatestAnalysis(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return latestAnalysisCard(snapshot.data!);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}