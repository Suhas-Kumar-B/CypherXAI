// lib/admin/pages/crud_users.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_store.dart';

class CrudUsersPage extends StatefulWidget {
  const CrudUsersPage({Key? key}) : super(key: key);

  @override
  State<CrudUsersPage> createState() => _CrudUsersPageState();
}

class _CrudUsersPageState extends State<CrudUsersPage> {
  final emailCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

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
                Text('CRUD (Users)', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
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
                      const Text('Add New User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                          hintText: 'Display name',
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
                          onPressed: () {
                            final email = emailCtrl.text.trim();
                            final name  = nameCtrl.text.trim().isEmpty ? email : nameCtrl.text.trim();
                            if (email.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email required')));
                              return;
                            }
                            store.addUser(email, name);
                            emailCtrl.clear(); nameCtrl.clear();
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
                      itemCount: store.users.length + 1,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _row(isHeader: true, cells: const ['Email', 'Name', 'Status', 'Actions']);
                        }
                        final u = store.users[i - 1];
                        return _row(cells: [
                          u.email,
                          u.displayName,
                          u.active ? 'ACTIVE' : 'DISABLED',
                          '—',
                        ], builders: [
                          (ctx) => Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => store.updateUser(u.email, active: !u.active),
                                child: Text(u.active ? 'Disable' : 'Enable', style: const TextStyle(color: Colors.cyanAccent)),
                              ),
                              TextButton(
                                onPressed: () => store.removeUser(u.email),
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
