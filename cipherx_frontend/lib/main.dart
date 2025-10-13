// lib/main.dart  (REPLACEMENT)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'pages/login.dart';
import 'services/admin_store.dart';
import 'services/auth_service.dart';
import 'services/scan_service.dart';

void main() {
  runApp(const CipherXApp());
}

class CipherXApp extends StatelessWidget {
  const CipherXApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AdminStore()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ScanService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'CipherX',
            theme: ThemeData(brightness: Brightness.light, primarySwatch: Colors.cyan),
            darkTheme: ThemeData(brightness: Brightness.dark, primarySwatch: Colors.cyan),
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            // Start at Login
            home: const LoginPage(),
            routes: {
              '/login': (_) => const LoginPage(),
              // User side still accessible via code (we don't change your routes/app_layout)
              // Admin side pushes AdminAppLayout via MaterialPageRoute inside login.
            },
          );
        },
      ),
    );
  }
}
