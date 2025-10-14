// lib/pages/results.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../components/anomaly_gauge.dart';
import '../components/json_viewer.dart';
import '../components/pentest_finding_card.dart';
import '../models/analysis.dart';
import '../services/scan_service.dart';
import '../services/auth_service.dart';
import '../theme_provider.dart';
import '../utils/download_helper.dart';

class ResultsPage extends StatefulWidget {
  final Analysis? analysis;
  const ResultsPage({Key? key, this.analysis}) : super(key: key);

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  Analysis? _analysis;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _analysis = widget.analysis;
    if (_analysis == null) {
      _loadMostRecentAnalysis();
    }
  }

  Future<void> _loadMostRecentAnalysis() async {
    setState(() => _isLoading = true);
    
    try {
      final scanService = context.read<ScanService>();
      final authService = context.read<AuthService>();
      final apiKey = authService.apiKey;
      
      if (apiKey != null) {
        if (scanService.history.isEmpty) {
          await scanService.loadHistory(apiKey);
        }
        
        if (scanService.currentAnalysis != null) {
          setState(() => _analysis = scanService.currentAnalysis);
        } else if (scanService.history.isNotEmpty) {
          final mostRecent = scanService.history.first;
          if (mostRecent.id != null) {
            final fullAnalysis = await scanService.fetchResultByJobId(
              apiKey: apiKey,
              jobId: mostRecent.id!,
            );
            if (fullAnalysis != null) {
              setState(() => _analysis = fullAnalysis);
            }
          }
        }
      }
    } catch (e) {
      // Error loading
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.cyanAccent),
              SizedBox(height: 16),
              Text('Loading analysis...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    if (_analysis == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.insert_drive_file_outlined, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              const Text('No analysis available', style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 8),
              const Text('Upload an APK from Dashboard', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  try {
                    context.read<ThemeProvider>().setPage(0);
                  } catch (e) {
                    // Fallback
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Go to Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final a = _analysis!;
    final scannedAt = _analysis!.dateTime ?? DateFormat('MMM d, y, h:mm:ss a').format(DateTime.now());
    final isBenign = (a.prediction ?? '').toLowerCase() == 'benign';
    final statusChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: (isBenign ? Colors.green : Colors.red).withOpacity(0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text((a.prediction ?? 'UNKNOWN').toUpperCase(),
          style: TextStyle(color: isBenign ? Colors.greenAccent : Colors.redAccent)),
    );

    Widget kpi(String title, String value, {Color color = Colors.white}) {
      return Card(
        color: const Color(0xFF0F1620),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    // Determine tab count based on whether Gemini report exists
    final hasGemini = a.geminiReport != null && a.geminiReport!.isNotEmpty;
    final tabCount = hasGemini ? 5 : 4;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: DefaultTabController(
        length: tabCount,
        child: Column(
          children: [
            // Header
            Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Analysis Results',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text('${a.fileName} • Scanned $scannedAt',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                const Icon(Icons.shield, color: Colors.greenAccent),
                const SizedBox(width: 8),
                statusChip,
              ],
            ),
          ),
          // KPI cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                    child: kpi('ML Confidence', '${a.confidence?.toStringAsFixed(0) ?? '0'}%',
                        color: Colors.cyanAccent)),
                const SizedBox(width: 12),
                Expanded(
                    child: kpi('Anomaly Score',
                        (a.anomalyScore ?? 0).toStringAsFixed(3),
                        color: Colors.purpleAccent)),
                const SizedBox(width: 12),
                Expanded(child: kpi('Security Issues', '1')),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1620),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                isScrollable: true,
                indicatorColor: Colors.cyanAccent,
                tabs: [
                  const Tab(icon: Icon(Icons.insert_drive_file_outlined), text: 'Overview'),
                  const Tab(icon: Icon(Icons.shield_outlined), text: 'Pentesting Results'),
                  const Tab(icon: Icon(Icons.bolt_outlined), text: 'Anomaly Analysis'),
                  if (hasGemini) const Tab(icon: Icon(Icons.auto_awesome), text: 'AI Report'),
                  const Tab(icon: Icon(Icons.description_outlined), text: 'Raw Data'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Tab content
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(analysis: a),
                _PentestTab(analysis: a),
                _AnomalyTab(analysis: a),
                if (hasGemini) _GeminiTab(analysis: a),
                _RawTab(analysis: a),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({Key? key, required this.analysis}) : super(key: key);
  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    const infoBg = Color(0xFF0F1620);

    Widget infoCard(String title, List<Widget> rows) {
      return Card(
        color: infoBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...rows
              ]),
        ),
      );
    }

    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(k, style: const TextStyle(color: Colors.white70)),
              Text(v,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: infoCard('File Information', [
                  kv('File Name', analysis.fileName),
                  kv('File Size',
                      '${(analysis.fileSize / (1024 * 1024)).toStringAsFixed(2)} MB'),
                  kv('Analysis Date', analysis.dateTime ?? '—'),
                  kv('Time', DateFormat('HH:mm').format(DateTime.now())),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 220,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Preparing download...')),
                          );
                          
                          // Prepare report data
                          final reportData = analysis.fullResult ?? {
                            'file_name': analysis.fileName,
                            'file_size': analysis.fileSize,
                            'status': analysis.status,
                            'prediction': analysis.prediction,
                            'confidence': analysis.confidence,
                            'anomaly_score': analysis.anomalyScore,
                            'pentest_findings': analysis.pentestFindings.map((f) => {
                              'id': f.id,
                              'title': f.title,
                              'severity': f.severity,
                              'evidence': f.evidence,
                              'recommendation': f.recommendation,
                            }).toList(),
                            'anomaly_details': analysis.anomalyDetails != null ? {
                              'uncertainty': analysis.anomalyDetails!.uncertainty,
                              'vote_std': analysis.anomalyDetails!.voteStd,
                              'novelty': analysis.anomalyDetails!.novelty,
                              'unseen_feature_count': analysis.anomalyDetails!.unseenFeatureCount,
                              'total_feature_count': analysis.anomalyDetails!.totalFeatureCount,
                            } : null,
                            'date_time': analysis.dateTime,
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
                              const SnackBar(content: Text('Failed to download report')),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.download_outlined,
                          color: Colors.cyanAccent),
                      label: const Text('Download Report',
                          style: TextStyle(color: Colors.cyanAccent)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.cyanAccent)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: infoCard('Analysis Configuration', [
                  kv('Pentesting Heuristics', analysis.pentestEnabled ? 'Enabled' : 'Disabled'),
                  kv('Anomaly Detection', analysis.anomalyEnabled ? 'Enabled' : 'Disabled'),
                  kv('AI Analysis', analysis.geminiEnabled ? 'Enabled' : 'Disabled'),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PentestTab extends StatelessWidget {
  const _PentestTab({Key? key, required this.analysis}) : super(key: key);
  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    final list = analysis.pentestFindings;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: PentestFindingCard(finding: list[i]),
        ),
      ),
    );
  }
}

class _AnomalyTab extends StatelessWidget {
  const _AnomalyTab({Key? key, required this.analysis}) : super(key: key);
  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          AnomalyGauge(
              score: analysis.anomalyScore ?? 0.0,
              details: analysis.anomalyDetails),
        ],
      ),
    );
  }
}

class _GeminiTab extends StatelessWidget {
  const _GeminiTab({Key? key, required this.analysis}) : super(key: key);
  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    final report = analysis.geminiReport ?? '';
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: const Color(0xFF0F1620),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: ListView(
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                  const SizedBox(width: 12),
                  const Text(
                    'AI-Powered Security Analysis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Generated by Google Gemini AI',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Divider(color: Colors.white12, height: 32),
              SelectableText(
                report,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RawTab extends StatelessWidget {
  const _RawTab({Key? key, required this.analysis}) : super(key: key);
  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          JsonViewer(data: analysis.fullResult ?? {
            'file_name': analysis.fileName,
            'file_size': analysis.fileSize,
            'status': analysis.status,
            'prediction': analysis.prediction,
            'confidence': analysis.confidence,
            'anomaly_score': analysis.anomalyScore,
            'pentest_enabled': analysis.pentestEnabled,
            'anomaly_enabled': analysis.anomalyEnabled,
          }),
        ],
      ),
    );
  }
}
