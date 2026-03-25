// lib/pages/history.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/analysis.dart';
import '../services/scan_service.dart';
import '../services/auth_service.dart';
import '../theme_provider.dart';
import '../utils/download_helper.dart';
import 'results.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String filterPrediction = 'All Predictions';
  String filterTime = 'All Time';
  List<Analysis> analyses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalyses();
  }

  Future<void> _loadAnalyses() async {
    setState(() {
      isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      final apiKey = authService.apiKey;

      if (apiKey != null) {
        final scanService = context.read<ScanService>();
        final history = await scanService.loadHistory(apiKey);
        setState(() {
          analyses = history;
          isLoading = false;
        });
      } else {
        setState(() {
          analyses = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        analyses = [];
        isLoading = false;
      });
    }
  }

  List<Analysis> get _filteredAnalyses {
    List<Analysis> filtered = analyses;

    // Filter by prediction
    if (filterPrediction != 'All Predictions') {
      filtered = filtered.where((analysis) {
        final prediction = analysis.prediction?.toUpperCase();
        if (filterPrediction == 'BENIGN') return prediction == 'BENIGN';
        if (filterPrediction == 'MALICIOUS') return prediction == 'MALICIOUS';
        return true;
      }).toList();
    }

    // TODO: Add time filtering based on analysis.dateTime

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF0F1620);

    Widget stat(String title, String value) => Card(
          color: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(color: Colors.white70)),
            ]),
          ),
        );

    Widget pill(String text, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
          child: Text(text, style: TextStyle(color: color, fontSize: 12)),
        );

    Widget _getPredictionPill(Analysis analysis) {
      final prediction = analysis.prediction?.toUpperCase() ?? 'UNKNOWN';
      final color = prediction == 'BENIGN' 
          ? Colors.greenAccent 
          : prediction == 'MALICIOUS' 
              ? Colors.redAccent 
              : Colors.orangeAccent;
      return pill(prediction, color);
    }

    Widget _getStatusPill(String status) {
      final color = status == 'completed' || status == 'done' 
          ? Colors.greenAccent 
          : Colors.orangeAccent;
      return pill(status, color);
    }

    // Calculate stats
    final completedAnalyses = analyses.where((a) => a.status == 'completed' || a.status == 'done').length;
    final benignAnalyses = analyses.where((a) => a.prediction?.toLowerCase() == 'benign').length;
    final maliciousAnalyses = analyses.where((a) => a.prediction?.toLowerCase() == 'malicious').length;
    final inProgressAnalyses = analyses.where((a) => a.status == 'processing').length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.history, color: Colors.cyanAccent),
              const SizedBox(width: 10),
              const Text('Analysis History', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                onPressed: _loadAnalyses,
                icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(child: stat('Total Analyses', '${analyses.length}')),
              const SizedBox(width: 12),
              Expanded(child: stat('Threats Found', '$maliciousAnalyses')),
              const SizedBox(width: 12),
              Expanded(child: stat('Clean Files', '$benignAnalyses')),
              const SizedBox(width: 12),
              Expanded(child: stat('In Progress', '$inProgressAnalyses')),
            ],
          ),
          const SizedBox(height: 16),

          // Filters bar
          Card(
            color: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: Colors.cyanAccent),
                  const SizedBox(width: 8),
                  const Text('Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 18),
                  _Dropdown(
                    value: filterPrediction,
                    items: const ['All Predictions', 'MALICIOUS', 'BENIGN'],
                    onChanged: (v) => setState(() => filterPrediction = v ?? filterPrediction),
                  ),
                  const SizedBox(width: 12),
                  _Dropdown(
                    value: filterTime,
                    items: const ['All Time', 'Last 7 days', 'Last 30 days'],
                    onChanged: (v) => setState(() => filterTime = v ?? filterTime),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Table or loading state
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  )
                : analyses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inbox, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No analyses found',
                              style: TextStyle(color: Colors.grey, fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Complete your first APK scan to see results here',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : Card(
                        color: cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: ListView.separated(
                            itemCount: _filteredAnalyses.length + 1,
                            separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                            itemBuilder: (context, i) {
                              if (i == 0) {
                                return _row(isHeader: true, cells: const ['File', 'Prediction', 'Status', 'Size', 'Date', 'Actions']);
                              }
                              final analysis = _filteredAnalyses[i - 1];
                              final fileName = analysis.fileName.split('/').last;
                              final fileSize = '${(analysis.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
                              final date = analysis.dateTime ?? 'Unknown';

                              return _row(
                                cells: [
                                  fileName,
                                  null, // Will be filled by prediction pill
                                  null, // Will be filled by status pill
                                  fileSize,
                                  date,
                                  null, // Will be filled by actions
                                ], 
                                builders: [
                                  // Prediction pill
                                  (ctx) => _getPredictionPill(analysis),
                                  // Status pill
                                  (ctx) => _getStatusPill(analysis.status),
                                  // Actions
                                  (ctx) => Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.open_in_new, color: Colors.cyanAccent),
                                            tooltip: 'View Details',
                                            onPressed: () async {
                                              // Fetch full analysis and navigate to results
                                              if (analysis.id != null) {
                                                final authService = context.read<AuthService>();
                                                final scanService = context.read<ScanService>();
                                                final apiKey = authService.apiKey;
                                                
                                                if (apiKey != null) {
                                                  // Show loading
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Loading analysis...')),
                                                  );
                                                  
                                                  // Fetch full details
                                                  final fullAnalysis = await scanService.fetchResultByJobId(
                                                    apiKey: apiKey,
                                                    jobId: analysis.id!,
                                                  );
                                                  
                                                  if (fullAnalysis != null) {
                                                    // Navigate to results page
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) => ResultsPage(analysis: fullAnalysis),
                                                      ),
                                                    );
                                                  } else {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Failed to load analysis details')),
                                                    );
                                                  }
                                                }
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.download, color: Colors.greenAccent),
                                            tooltip: 'Download Report',
                                            onPressed: () async {
                                              if (analysis.id != null) {
                                                try {
                                                  final authService = context.read<AuthService>();
                                                  final scanService = context.read<ScanService>();
                                                  final apiKey = authService.apiKey;
                                                  
                                                  if (apiKey != null) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Preparing download...')),
                                                    );
                                                    
                                                    // Fetch full analysis data
                                                    final fullAnalysis = await scanService.fetchResultByJobId(
                                                      apiKey: apiKey,
                                                      jobId: analysis.id!,
                                                    );
                                                    
                                                    if (fullAnalysis != null) {
                                                      // Prepare report data
                                                      final reportData = fullAnalysis.fullResult ?? {
                                                        'file_name': fullAnalysis.fileName,
                                                        'file_size': fullAnalysis.fileSize,
                                                        'status': fullAnalysis.status,
                                                        'prediction': fullAnalysis.prediction,
                                                        'confidence': fullAnalysis.confidence,
                                                        'anomaly_score': fullAnalysis.anomalyScore,
                                                        'date_time': fullAnalysis.dateTime,
                                                      };
                                                      
                                                      // Download as JSON
                                                      final fileName = '${analysis.fileName.replaceAll('.apk', '')}_report';
                                                      final result = await DownloadHelper.downloadJson(
                                                        jsonData: reportData,
                                                        fileName: fileName,
                                                      );
                                                      
                                                      if (result != null) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('Report saved: $result')),
                                                        );
                                                      } else {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Failed to download')),
                                                        );
                                                      }
                                                    }
                                                  }
                                                } catch (e) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Error: $e')),
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                ]
                              );
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _row({required List<dynamic> cells, bool isHeader = false, List<Widget Function(BuildContext)> builders = const []}) {
    const textStyleHeader = TextStyle(color: Colors.white70, fontWeight: FontWeight.bold);
    const textStyle       = TextStyle(color: Colors.white,   fontWeight: FontWeight.w500);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          _cell(cells[0]?.toString() ?? '', flex: 3, style: isHeader ? textStyleHeader : textStyle),
          _cell(cells[1]?.toString() ?? '', flex: 2, style: isHeader ? textStyleHeader : textStyle, custom: builders.isNotEmpty ? builders[0](context) : null),
          _cell(cells[2]?.toString() ?? '', flex: 2, style: isHeader ? textStyleHeader : textStyle, custom: builders.length > 1 ? builders[1](context) : null),
          _cell(cells[3]?.toString() ?? '', flex: 2, style: isHeader ? textStyleHeader : textStyle),
          _cell(cells[4]?.toString() ?? '', flex: 2, style: isHeader ? textStyleHeader : textStyle),
          _cell(cells[5]?.toString() ?? '', flex: 1, style: isHeader ? textStyleHeader : textStyle, custom: builders.length > 2 ? builders[2](context) : null),
        ],
      ),
    );
  }

  Widget _cell(String text, {required int flex, TextStyle? style, Widget? custom}) {
    return Expanded(
      flex: flex,
      child: custom ??
          Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _Dropdown({Key? key, required this.value, required this.items, required this.onChanged}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: const Color(0xFF121A23), borderRadius: BorderRadius.circular(10)),
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF121A23),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}