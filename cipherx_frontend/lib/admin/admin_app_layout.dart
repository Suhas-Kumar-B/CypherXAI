// lib/admin/admin_app_layout.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../components/sidebar_menu.dart';
import 'pages/client_activity.dart';
import 'pages/password_generation.dart';
import 'pages/crud_users.dart';
import '../services/auth_service.dart';

class AdminAppLayout extends StatelessWidget {
  const AdminAppLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return _AdminScaffold();
  }
}

class _AdminScaffold extends StatefulWidget {
  @override
  State<_AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<_AdminScaffold> {
  int page = 0;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    const pages = [ClientActivityPage(), PasswordGenerationPage(), CrudUsersPage()];

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? const Color(0xFF0B0F14) : Colors.grey[50],
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 260,
              color: themeProvider.isDarkMode ? const Color(0xFF0F1620) : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              child: Column(
                children: [
                  const Row(children: [
                    // App emblem
                    // (same style)
                  ]),
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.cyan, Colors.blue]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shield, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('CipherX Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('Console', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ]),
                  ]),
                  const SizedBox(height: 18),

                  SidebarMenuItem(icon: Icons.history,  title: 'Client Activity',     selected: page == 0, onTap: () => setState(() => page = 0)),
                  SidebarMenuItem(icon: Icons.password, title: 'Password Generation',  selected: page == 1, onTap: () => setState(() => page = 1)),
                  SidebarMenuItem(icon: Icons.manage_accounts, title: 'CRUD',          selected: page == 2, onTap: () => setState(() => page = 2)),
                  const Spacer(),

                  // Only Logout (theme toggle removed as requested)
                  Container(
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode ? const Color(0xFF101820) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black.withOpacity(0.1)),
                    ),
                    child: _BottomActionTile(
                      icon: Icons.logout,
                      label: 'Logout',
                      danger: true,
                      onTap: () {
                        AuthService().logout();
                        Navigator.of(context).pushReplacementNamed('/login');
                      },
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                color: themeProvider.isDarkMode ? const Color(0xFF0B0F14) : Colors.grey[100],
                child: IndexedStack(index: page, children: pages),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;

  const _BottomActionTile({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.redAccent : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: danger ? Colors.redAccent : Colors.grey),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: color, fontWeight: danger ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
