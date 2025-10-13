// lib/admin/pages/password_generation.dart
// (same imports)

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_store.dart';

class PasswordGenerationPage extends StatefulWidget {
  const PasswordGenerationPage({Key? key}) : super(key: key);

  @override
  State<PasswordGenerationPage> createState() => _PasswordGenerationPageState();
}

class _PasswordGenerationPageState extends State<PasswordGenerationPage> {
  final usernameCtrl = TextEditingController();
  String lastPassword = '';

  @override
  void dispose() {
    usernameCtrl.dispose();
    super.dispose();
  }

  String _generateStrongPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#%&*!?_';
    final rnd = Random.secure();
    return List.generate(12, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  void _generateAndStore(AdminStore store) {
    final username = usernameCtrl.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a username/email')));
      return;
    }
    final pwd = _generateStrongPassword();
    setState(() => lastPassword = pwd);
    store.addGeneratedPassword(username, pwd);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password generated and stored')));
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<AdminStore>(context);
    const cardBg = Color(0xFF0F1620);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Row(children: [
                Icon(Icons.password, color: Colors.cyanAccent),
                SizedBox(width: 10),
                Text('Password Generation', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 16),

              Card(
                color: cardBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Generate Password for User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: usernameCtrl,
                        decoration: InputDecoration(
                          hintText: 'Enter username/email',
                          filled: true,
                          fillColor: const Color(0xFF121A23),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 220,
                        child: ElevatedButton.icon(
                          onPressed: () => _generateAndStore(store),
                          icon: const Icon(Icons.bolt),
                          label: const Text('Generate'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: const Color(0xFF1E88E5),
                          ),
                        ),
                      ),
                      if (lastPassword.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SelectableText('Last Generated: $lastPassword', style: const TextStyle(color: Colors.cyanAccent)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: Card(
                  color: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ListView.separated(
                      itemCount: store.generated.length + 1,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _row(isHeader: true, cells: const ['Username', 'Password', 'Created', 'Actions']);
                        }
                        final g = store.generated[i - 1];
                        return _row(cells: [
                          g.username,
                          g.password,
                          g.createdAt.toString().substring(0, 19),
                          '—',
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

  Widget _row({required List<dynamic> cells, bool isHeader = false}) {
    const textStyleHeader = TextStyle(color: Colors.white70, fontWeight: FontWeight.bold);
    const textStyle       = TextStyle(color: Colors.white,   fontWeight: FontWeight.w500);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          _cell(cells[0]?.toString() ?? '', flex: 3, style: isHeader ? textStyleHeader : textStyle),
          _cell(cells[1]?.toString() ?? '', flex: 3, style: isHeader ? textStyleHeader : textStyle),
          _cell(cells[2]?.toString() ?? '', flex: 2, style: isHeader ? textStyleHeader : textStyle),
          _cell(cells[3]?.toString() ?? '', flex: 1, style: isHeader ? textStyleHeader : textStyle),
        ],
      ),
    );
  }

  Widget _cell(String text, {required int flex, TextStyle? style}) {
    return Expanded(
      flex: flex,
      child: Text(text, overflow: TextOverflow.ellipsis, style: style),
    );
  }
}
