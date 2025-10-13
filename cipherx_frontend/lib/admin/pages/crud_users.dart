// lib/admin/pages/crud_users.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_store.dart';
import '../../services/api_client.dart';

class CrudUsersPage extends StatefulWidget {
  const CrudUsersPage({Key? key}) : super(key: key);

  @override
  State<CrudUsersPage> createState() => _CrudUsersPageState();
}

class _CrudUsersPageState extends State<CrudUsersPage> {
  final emailCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  List<String> admins = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _refreshAdmins();
  }

  Future<void> _refreshAdmins() async {
    setState(() => loading = true);
    try {
      admins = await ApiClient().getAdmins();
    } catch (_) {}
    setState(() => loading = false);
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
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
                Icon(Icons.manage_accounts, color: Colors.cyanAccent),
                SizedBox(width: 10),
                Text('Manage Admin Users', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
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
                      const Text('Add Admin Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        decoration: InputDecoration(
                          hintText: 'Email',
                          filled: true,
                          fillColor: const Color(0xFF121A23),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          hintText: 'Optional note (ignored)',
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
                        width: 180,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final email = emailCtrl.text.trim();
                            if (email.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email required')));
                              return;
                            }
                            try {
                              await ApiClient().addAdminEmail(email);
                              await _refreshAdmins();
                              emailCtrl.clear(); nameCtrl.clear();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin added')));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add User'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: const Color(0xFF1E88E5),
                          ),
                        ),
                      ),
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
                      itemCount: (admins.length) + 1,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _row(isHeader: true, cells: const ['Admin Email', '—', '—', 'Actions']);
                        }
                        final email = admins[i - 1];
                        return _row(cells: [
                          email,
                          '—',
                          '—',
                          '—',
                        ], builders: [
                          (ctx) => Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  try {
                                    await ApiClient().removeAdminEmail(email);
                                    await _refreshAdmins();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                  }
                                },
                                child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
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
          _cell(cells[1]?.toString() ?? '', flex: 3, style: isHeader ? textStyleHeader : textStyle),
          _cell(cells[2]?.toString() ?? '', flex: 2, style: isHeader ? textStyleHeader : textStyle),
          _cell(cells[3]?.toString() ?? '', flex: 2, style: isHeader ? textStyleHeader : textStyle, custom: builders.isNotEmpty ? builders[0](context) : null),
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
