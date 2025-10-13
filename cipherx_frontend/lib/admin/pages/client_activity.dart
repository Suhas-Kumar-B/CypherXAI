// lib/admin/pages/client_activity.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_store.dart';
import '../../services/api_client.dart';

class ClientActivityPage extends StatefulWidget {
  const ClientActivityPage({Key? key}) : super(key: key);

  @override
  State<ClientActivityPage> createState() => _ClientActivityPageState();
}

class _ClientActivityPageState extends State<ClientActivityPage> {
  List<Map<String, dynamic>> activity = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      activity = await ApiClient().getActivityLog();
    } catch (_) {}
    setState(() => loading = false);
  }
  @override
  Widget build(BuildContext context) {
    final store = Provider.of<AdminStore>(context);
    const cardBg = Color(0xFF0F1620);

    Widget stat(String title, String value) => Card(
          color: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        );

    Widget pill(String text, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
          child: Text(text, style: TextStyle(color: color, fontSize: 12)),
        );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Row(children: [
                Icon(Icons.people_alt, color: Colors.cyanAccent),
                SizedBox(width: 10),
                Text('Client Activity', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: stat('Total Events', '${activity.length}')),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: Card(
                  color: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ListView.separated(
                      itemCount: activity.length + 1,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _row(isHeader: true, cells: const ['Timestamp', 'Username', 'Action', 'Details']);
                        }
                        final r = activity[i - 1];
                        final ts = (r['timestamp'] ?? '').toString();
                        final user = (r['username'] ?? '').toString();
                        final action = (r['action'] ?? '').toString();
                        final details = (r['details'] ?? '').toString();
                        final color = action.contains('ADMIN') ? Colors.cyanAccent : Colors.greenAccent;
                        return _row(cells: [
                          ts,
                          user,
                          null,
                          details.isEmpty ? '—' : details,
                        ], builders: [
                          (ctx) => pill(action, color),
                        ]);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
          _cell(cells[2]?.toString() ?? '', flex: 2, style: isHeader ? textStyleHeader : textStyle),
          _cell(cells[3]?.toString() ?? '', flex: 2, style: isHeader ? textStyleHeader : textStyle, custom: builders.length > 1 ? builders[1](context) : null),
          _cell(cells[4]?.toString() ?? '', flex: 2, style: isHeader ? textStyleHeader : textStyle),
          _cell(cells[5]?.toString() ?? '', flex: 2, style: isHeader ? textStyleHeader : textStyle),
          _cell(cells[6]?.toString() ?? '', flex: 1, style: isHeader ? textStyleHeader : textStyle, custom: builders.length > 2 ? builders[2](context) : null),
        ],
      ),
    );
  }

  Widget _cell(String text, {required int flex, TextStyle? style, Widget? custom}) {
    return Expanded(
      flex: flex,
      child: custom ?? Text(text, overflow: TextOverflow.ellipsis, style: style),
    );
  }
}
