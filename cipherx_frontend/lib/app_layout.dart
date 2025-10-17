import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/dashboard.dart';
import 'pages/results.dart';
import 'pages/history.dart';
import 'pages/about.dart';
import 'components/sidebar_menu.dart';
import 'models/analysis.dart';
import 'models/user.dart';
import 'theme_provider.dart';

// ADD: import for auth + routing back to login
import 'services/auth_service.dart';
import 'services/scan_service.dart';

class AppLayout extends StatelessWidget {
  const AppLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scanService = Provider.of<ScanService>(context);
    
    // Get the most recent analysis from ScanService
    final currentAnalysis = scanService.currentAnalysis ?? 
                           (scanService.history.isNotEmpty ? scanService.history.first : null);
    
    final pages = [
      DashboardPage(analysis: currentAnalysis),
      ResultsPage(analysis: currentAnalysis),
      const HistoryPage(),
      const AboutPage(),
    ];

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? const Color(0xFF0B0F14) : Colors.grey[50],
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar
            Container(
              width: 260,
              color: themeProvider.isDarkMode ? const Color(0xFF0F1620) : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              child: Column(
                children: [
                  Row(children: [
                    Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Colors.cyan, Colors.blue]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shield, color: Colors.white)),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('CipherX',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode ? Colors.white : Colors.black)),
                      const Text('APK Security Analysis', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ])
                  ]),
                  const SizedBox(height: 18),

                  SidebarMenuItem(icon: Icons.home,    title: 'Dashboard', selected: themeProvider.currentPage == 0, onTap: () => themeProvider.setPage(0)),
                  SidebarMenuItem(icon: Icons.search,  title: 'Results',   selected: themeProvider.currentPage == 1, onTap: () => themeProvider.setPage(1)),
                  SidebarMenuItem(icon: Icons.history, title: 'History',   selected: themeProvider.currentPage == 2, onTap: () => themeProvider.setPage(2)),
                  SidebarMenuItem(icon: Icons.info,    title: 'About',     selected: themeProvider.currentPage == 3, onTap: () => themeProvider.setPage(3)),
                  const Spacer(),

                  // Bottom: ONLY Logout + the user card (per requirement)
                  FutureBuilder<User>(
                    future: User.me(),
                    builder: (context, snapshot) {
                      final user = snapshot.data;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Just a single logout action container
                          Container(
                            decoration: BoxDecoration(
                              color: themeProvider.isDarkMode ? const Color(0xFF101820) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black.withOpacity(0.1)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: _BottomActionTile(
                              icon: Icons.logout,
                              label: 'Logout',
                              danger: true,
                              onTap: () async {
                                // UPDATED: route to Login and record activity
                                await User.logout();
                                AuthService().logout();
                                Navigator.of(context).pushReplacementNamed('/login');
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          // User tile
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blueGrey.shade700,
                                  child: Text(
                                    (user?.fullName.isNotEmpty ?? false)
                                        ? user!.fullName.trim()[0].toUpperCase()
                                        : 'V',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user?.fullName ?? 'Vishnu P',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                      Text(user?.email ?? 'vishnup2603@gmail.com',
                                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: Container(
                color: themeProvider.isDarkMode ? const Color(0xFF0B0F14) : Colors.grey[100],
                child: IndexedStack(
                  index: themeProvider.currentPage,
                  children: pages,
                ),
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