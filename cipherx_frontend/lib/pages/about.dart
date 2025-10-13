// lib/pages/about.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Simple helper to compute responsive item width for Wrap grids.
class _GridSpec {
  final int cols;
  final double itemWidth;
  const _GridSpec(this.cols, this.itemWidth);
}

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  // ---------- helpers ----------
  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withOpacity(0.22)),
        ),
        child: Text(text, style: const TextStyle(color: Colors.greenAccent)),
      );

  _GridSpec _gridSpec(double maxWidth, double targetItemWidth, double spacing) {
    int cols = (maxWidth / (targetItemWidth + spacing)).floor();
    if (cols < 1) cols = 1;
    if (cols > 4) cols = 4;
    final itemWidth = (maxWidth - spacing * (cols - 1)) / cols;
    return _GridSpec(cols, itemWidth);
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      );

  // small, auto-height card base
  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
    return Card(
      color: const Color(0xFF0F1620),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: Padding(padding: padding, child: child),
    );
  }

  Widget _metricCard(IconData icon, String value, String label) {
    return _card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.cyanAccent),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureCard(IconData icon, String title, String desc) {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.cyanAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String desc) =>
      _featureCard(icon, title, desc);

  Widget _avatar(String initials) => Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.cyan, Colors.blue]),
          borderRadius: BorderRadius.circular(54),
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );

  Widget _teamCard({
    required String initials,
    required String name,
    required String email,
    required String linkedin,
  }) {
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _avatar(initials),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Email',
                icon: const Icon(Icons.email_outlined, color: Colors.white70),
                onPressed: () => launchUrl(Uri.parse('mailto:$email')),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'LinkedIn',
                icon: const Icon(Icons.link_outlined, color: Colors.white70),
                onPressed: () => launchUrl(
                  Uri.parse(linkedin),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyPad = EdgeInsets.symmetric(
      horizontal: MediaQuery.of(context).size.width < 1200 ? 16 : 24,
      vertical: 16,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        const spacing = 16.0;

        // Grids: choose target width per tile to avoid huge empty spaces
        final statsSpec = _gridSpec(maxW, 300, spacing);
        final featuresSpec = _gridSpec(maxW, 520, spacing);
        final teamSpec = _gridSpec(maxW, 420, spacing);
        final infoSpec = _gridSpec(maxW, 520, spacing);

        return SingleChildScrollView(
          padding: bodyPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ----- Hero -----
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [Colors.cyan, Colors.blue]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CipherX',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Advanced APK Security Analysis Platform',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _chip('Version 2.1.0 • Production Ready'),
              const SizedBox(height: 16),
              const Text(
                'CipherX is a cybersecurity platform that combines machine learning, rule-based analysis, and AI-powered insights to provide comprehensive APK security assessments. '
                'It equips security professionals with the tools they need to identify threats, analyze anomalies, and protect digital ecosystems.',
                style: TextStyle(color: Colors.white70),
              ),

              // ----- Platform Statistics -----
              const SizedBox(height: 22),
              _sectionTitle('Platform Statistics'),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: statsSpec.itemWidth,
                    child: _metricCard(Icons.bar_chart, '10,000+', 'APKs Analyzed'),
                  ),
                  SizedBox(
                    width: statsSpec.itemWidth,
                    child: _metricCard(
                        Icons.timer_outlined, '<30s', 'Average Processing Time'),
                  ),
                  SizedBox(
                    width: statsSpec.itemWidth,
                    child: _metricCard(
                        Icons.verified_user_outlined, '98.5%', 'Accuracy Rate'),
                  ),
                  SizedBox(
                    width: statsSpec.itemWidth,
                    child: _metricCard(Icons.groups_outlined, '500+', 'Active Users'),
                  ),
                ],
              ),

              // ----- Core Features -----
              const SizedBox(height: 22),
              _sectionTitle('Core Features'),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: featuresSpec.itemWidth,
                    child: _featureCard(
                      Icons.shield_outlined,
                      'Advanced APK Analysis',
                      'ML-powered classification augmented with rule-based pentesting heuristics.',
                    ),
                  ),
                  SizedBox(
                    width: featuresSpec.itemWidth,
                    child: _featureCard(
                      Icons.bolt_outlined,
                      'Anomaly Detection',
                      'Identifies suspicious patterns and behaviors in APK metadata and runtime indicators.',
                    ),
                  ),
                  SizedBox(
                    width: featuresSpec.itemWidth,
                    child: _featureCard(
                      Icons.smart_toy_outlined,
                      'AI-Powered Reports',
                      'Optional LLM integration to summarize findings and provide remediation guidance.',
                    ),
                  ),
                  SizedBox(
                    width: featuresSpec.itemWidth,
                    child: _featureCard(
                      Icons.lock_outline,
                      'Enterprise Security',
                      'On-device processing options, encryption at rest/in transit, and privacy by design.',
                    ),
                  ),
                ],
              ),

              // ----- Development Team -----
              const SizedBox(height: 22),
              _sectionTitle('Development Team'),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: teamSpec.itemWidth,
                    child: _teamCard(
                      initials: 'S',
                      name: 'Sanjana',
                      email: 'sanjanaks676@gmail.com',
                      linkedin:
                          'https://www.linkedin.com/in/sanjana-ks-19302325a?utm_source=share&utm_campaign=share_via&utm_content=profile&utm_medium=android_app',
                    ),
                  ),
                  SizedBox(
                    width: teamSpec.itemWidth,
                    child: _teamCard(
                      initials: 'SR',
                      name: 'Sanjana R',
                      email: 'sanjanar.ten@gmail.com',
                      linkedin: 'https://www.linkedin.com/in/sanjana-r-42bb65259/',
                    ),
                  ),
                  SizedBox(
                    width: teamSpec.itemWidth,
                    child: _teamCard(
                      initials: 'SK',
                      name: 'Suhas Kumar',
                      email: 'suhaskumarb748@gmail.com',
                      linkedin: 'https://www.linkedin.com/in/suhas-kumar-746565262',
                    ),
                  ),
                  SizedBox(
                    width: teamSpec.itemWidth,
                    child: _teamCard(
                      initials: 'VP',
                      name: 'Vishnu P',
                      email: 'vishnup2603@gmail.com',
                      linkedin: 'https://www.linkedin.com/in/vishnu-p-95a0aa257',
                    ),
                  ),
                ],
              ),

              // ----- Security & Open Source -----
              const SizedBox(height: 22),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: infoSpec.itemWidth,
                    child: _infoCard(
                      Icons.verified_user_outlined,
                      'Security & Privacy',
                      'Sensitive evaluations can execute locally. Data is never shared externally unless explicitly enabled.',
                    ),
                  ),
                  SizedBox(
                    width: infoSpec.itemWidth,
                    child: _infoCard(
                      Icons.auto_awesome_outlined,
                      'Open Source & Support',
                      'Pluggable architecture with adapters for scanners and models. Community support via issues & discussions.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
