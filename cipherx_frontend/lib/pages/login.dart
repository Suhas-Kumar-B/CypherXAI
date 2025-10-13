// lib/pages/login.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../services/auth_service.dart';
import '../admin/admin_app_layout.dart';
import '../app_layout.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1620),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Help', style: TextStyle(color: Colors.white)),
        content: const Text(
          '• Admin login (restricted to 4 emails) opens the Admin Console.\n'
          '• User login opens the User Dashboard.\n'
          '• Use Logout from any side to return here.\n'
          'Admin Accounts:\n'
          '  - suhaskumarb748@gmail.com\n'
          '  - vishnup2603@gmail.com\n'
          '  - sanjana@gmail.com\n'
          '  - sanjanar.ten@gmail.com\n'
          'User Demo:\n'
          '  - dummy@gmail.com / qwerty123',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.cyanAccent)),
          )
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() { loading = true; error = null; });
    final res = await AuthService().login(emailCtrl.text.trim(), passCtrl.text);
    setState(() { loading = false; });

    if (!res.ok) {
      setState(() { error = res.message ?? 'Login failed'; });
      return;
    }

    if (res.role == AuthRole.admin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminAppLayout()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppLayout()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bg = themeProvider.isDarkMode ? const Color(0xFF0B0F14) : Colors.grey[50];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: _showHelp,
            icon: const Icon(Icons.help_outline, color: Colors.cyanAccent),
            label: const Text('Help', style: TextStyle(color: Colors.cyanAccent)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            color: themeProvider.isDarkMode ? const Color(0xFF0F1620) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.cyan, Colors.blue]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.shield, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'CipherX',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text('Secure Login', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 22),

                  Align(alignment: Alignment.centerLeft, child: Text('Username', style: TextStyle(color: Colors.grey[300]))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter your email',
                      filled: true,
                      fillColor: const Color(0xFF121A23),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 14),

                  Align(alignment: Alignment.centerLeft, child: Text('Password', style: TextStyle(color: Colors.grey[300]))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
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

                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(error!, style: const TextStyle(color: Colors.redAccent)),
                    ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: const Color(0xFF1E88E5),
                      ),
                      child: loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
