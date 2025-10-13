// lib/pages/results.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/anomaly_gauge.dart';
import '../components/json_viewer.dart';
import '../components/pentest_finding_card.dart';
import '../models/analysis.dart';

class ResultsPage extends StatelessWidget {
  final Analysis? analysis;
  const ResultsPage({Key? key, this.analysis}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (analysis == null) {
      return const Center(
          child: Text('No analysis selected', style: TextStyle(color: Colors.white)));
    }

    final a = analysis!;
    final scannedAt = analysis!.dateTime ?? DateFormat('MMM d, y, h:mm:ss a').format(DateTime.now());
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

    return DefaultTabController(
      length: 4,
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
              child: const TabBar(
                isScrollable: true,
                indicatorColor: Colors.cyanAccent,
                tabs: [
                  Tab(icon: Icon(Icons.insert_drive_file_outlined), text: 'Overview'),
                  Tab(icon: Icon(Icons.shield_outlined), text: 'Pentesting Results'),
                  Tab(icon: Icon(Icons.bolt_outlined), text: 'Anomaly Analysis'),
                  Tab(icon: Icon(Icons.description_outlined), text: 'Raw Data'),
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
                _RawTab(analysis: a),
              ],
            ),
          ),
        ],
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
                      onPressed: () {
                        // You can wire this to download the JSON report if id present
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Use History page to download report')),
                        );
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
