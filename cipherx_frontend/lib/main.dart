// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'pages/login.dart';
import 'services/admin_store.dart';
import 'services/auth_service.dart';
import 'services/scan_service.dart';
import 'services/api_client.dart'; // Import the ApiClient
import 'app_layout.dart';
import 'admin/admin_app_layout.dart';

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
        // Provide ApiClient so other services can use it
        Provider<ApiClient>(create: (_) => ApiClient()),
        ChangeNotifierProvider(create: (_) => AdminStore()),
        // ScanService and AuthService are singletons - just create them without arguments
        ChangeNotifierProvider(create: (_) => ScanService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'CipherX',
            theme: ThemeData(brightness: Brightness.light, primarySwatch: Colors.cyan),
            darkTheme: ThemeData(brightness: Brightness.dark, primarySwatch: Colors.cyan),
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const LoginPage(),
            routes: {
              '/login': (_) => const LoginPage(),
              '/dashboard': (_) => const AppLayout(),
              '/admin': (_) => const AdminAppLayout(),
            },
          );
        },
      ),
    );
  }
}
