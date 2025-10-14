// lib/components/anomaly_gauge.dart
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/analysis.dart';

class AnomalyGauge extends StatelessWidget {
  final double score;
  final AnomalyDetails? details;

  const AnomalyGauge({Key? key, required this.score, this.details})
      : super(key: key);

  Map<String, dynamic> getScoreLevelInfo(String level) {
    switch (level) {
      case 'High':
        return {
          'level': 'High',
          'color': Colors.redAccent,
          'bg': Colors.redAccent.withOpacity(0.14)
        };
      case 'Medium':
        return {
          'level': 'Medium',
          'color': Colors.orangeAccent,
          'bg': Colors.orangeAccent.withOpacity(0.14)
        };
      default:
        return {
          'level': 'Low',
          'color': Colors.greenAccent,
          'bg': Colors.greenAccent.withOpacity(0.14)
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use level from details if available, otherwise derive from score
    final level = details?.level ?? (score >= 0.7 ? 'High' : score >= 0.4 ? 'Medium' : 'Low');
    final scoreInfo = getScoreLevelInfo(level);
    const cardBg = Color(0xFF0F1620);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Anomaly Detection Analysis',
            style: TextStyle(
                color: Colors.yellow.shade400,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Card(
          color: cardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Column(
              children: [
                CircularPercentIndicator(
                  radius: 86.0,
                  lineWidth: 12.0,
                  percent: score.clamp(0.0, 1.0),
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(score.toStringAsFixed(3),
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: scoreInfo['color'])),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scoreInfo['bg'],
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text("${scoreInfo['level']} Risk",
                            style: TextStyle(
                                color: scoreInfo['color'],
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  progressColor: scoreInfo['color'],
                  backgroundColor: Colors.grey.shade800,
                  circularStrokeCap: CircularStrokeCap.round,
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RangeLabel(title: 'Low', range: '0.0 - 0.4'),
                      _RangeLabel(title: 'Medium', range: '0.4 - 0.7'),
                      _RangeLabel(title: 'High', range: '0.7 - 1.0'),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
        if (details != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  title: 'Analysis Components',
                  titleColor: Colors.cyanAccent,
                  rows: [
                    _kv('Uncertainty', details!.uncertainty.toStringAsFixed(4)),
                    _kv('Vote Std', details!.voteStd.toStringAsFixed(4)),
                    _kv('Novelty', details!.novelty.toStringAsFixed(4)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _featureCard(details!),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static Widget _kv(String k, String v) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: const TextStyle(color: Colors.grey)),
        Text(v,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }

  static Widget _metricCard(
      {required String title,
      required Color titleColor,
      required List<Widget> rows}) {
    return Card(
      color: const Color(0xFF0F1620),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 10),
            ...rows.map((w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: w,
                )),
          ],
        ),
      ),
    );
  }

  static Widget _featureCard(AnomalyDetails d) {
    final coverage = d.totalFeatureCount == 0
        ? 0.0
        : ((d.totalFeatureCount - d.unseenFeatureCount) / d.totalFeatureCount);
    return Card(
      color: const Color(0xFF0F1620),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Feature Analysis',
                style: TextStyle(
                    color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _kv('Unseen Features', d.unseenFeatureCount.toString()),
            _kv('Total Features', d.totalFeatureCount.toString()),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: coverage,
                backgroundColor: Colors.grey.shade800,
                color: Colors.cyanAccent,
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeLabel extends StatelessWidget {
  final String title;
  final String range;
  const _RangeLabel({Key? key, required this.title, required this.range})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = title == 'Low'
        ? Colors.green
        : title == 'Medium'
            ? Colors.amber
            : Colors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        Text(range, style: TextStyle(color: color)),
      ],
    );
  }
}
