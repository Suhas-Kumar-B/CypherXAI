// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'api_client.dart';
import 'admin_store.dart';

enum AuthRole { user, admin }

class AuthResult {
  final bool ok;
  final AuthRole? role;
  final String? message;
  final String? apiKey;
  const AuthResult({required this.ok, this.role, this.message, this.apiKey});
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  AuthRole? _role;
  String? _username;
  String? _apiKey;
  bool _authenticatedWithBackend = false;

  AuthRole? get role => _role;
  String? get username => _username;
  String? get apiKey => _apiKey;
  bool get isLoggedIn => _role != null && _authenticatedWithBackend;

  // Admin whitelist (ONLY these can access Admin side)
  static const _admins = <String, String>{
    'admin@cipherx.com': 'admin123',
    'testadmin@cipherx.com': 'test123',
    'suhaskumarb748@gmail.com': 'suhas@123',
    'vishnup2603@gmail.com': 'vishnu@123',
    'sanjana@gmail.com': 'sanjana@123',
    'sanjanar.ten@gmail.com': 'CUTIE@1',
  };

  // Test user accounts for easy testing
  static const _userCred = {
    'test@cipherx.com': 'test123',
    'user@cipherx.com': 'user123',
    'demo@cipherx.com': 'demo123',
    'dummy@gmail.com': 'qwerty123',
  };

  static String displayNameFromEmail(String email) {
    final local = email.split('@').first;
    final tokens = local.replaceAll(RegExp(r'[_\.]+'), ' ').split(' ');
    final words = tokens.map((t) {
      if (t.isEmpty) return '';
      final letters = t.replaceAll(RegExp(r'\d+'), '');
      if (letters.length <= 2) return letters.toUpperCase();
      if (letters.length > 6) {
        return '${letters.substring(0, letters.length - 1)[0].toUpperCase()}${letters.substring(1, letters.length - 1)} ${letters.substring(letters.length - 1).toUpperCase()}';
      }
      return '${letters[0].toUpperCase()}${letters.substring(1)}';
    }).where((w) => w.isNotEmpty).toList();
    final name = words.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return name.isEmpty ? email : name;
  }

  // Initialize with backend API
  Future<void> _setupBackendConnection() async {
    final apiClient = ApiClient();
    
    try {
      // Always ensure a backend user exists and get an API key for this username
      final response = await apiClient.createUser(_username!);
      _apiKey = response['api_key'] as String?;
      
      if (_apiKey != null && _apiKey!.isNotEmpty) {
        final isValidKey = await _validateApiKey(_apiKey!);
        if (isValidKey) {
          _authenticatedWithBackend = true;
        } else {
          // Clear authentication on invalid API key
          _role = null;
          _username = null;
          _apiKey = null;
          _authenticatedWithBackend = false;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Backend authentication error: $e');
      }
      _authenticatedWithBackend = false;
    }
  }

  Future<bool> _validateApiKey(String apiKey) async {
    final apiClient = ApiClient();
    return await apiClient.authenticate(apiKey);
  }

  Future<AuthResult> login(String email, String password) async {
    // Admins only if in whitelist and password matches
    if (_admins.containsKey(email) && _admins[email] == password) {
      _role = AuthRole.admin;
      _username = email;
      await _setupBackendConnection();
      _recordActivity(email, 'LOGIN (ADMIN)');
      notifyListeners();
      return AuthResult(
        ok: true, 
        role: AuthRole.admin,
        apiKey: _apiKey,
      );
    }

    // Regular user
    if (_userCred[email] == password) {
      _role = AuthRole.user;
      _username = email;
      await _setupBackendConnection();
      _recordActivity(email, 'LOGIN (USER)');
      notifyListeners();
      return AuthResult(
        ok: true, 
        role: AuthRole.user,
        apiKey: _apiKey,
      );
    }

    return const AuthResult(ok: false, message: 'Invalid credentials');
  }

  // Direct API key authentication (for backend integration)
  Future<AuthResult> authenticateWithApiKey(String apiKey) async {
    final apiClient = ApiClient();
    final isValidKey = await _validateApiKey(apiKey);
    
    if (isValidKey) {
      _apiKey = apiKey;
      _authenticatedWithBackend = true;
      _username = await _getUsernameFromApiKey(apiKey);
      _role = AuthRole.user;
      _recordActivity(_username ?? 'unknown', 'LOGIN (API)');
      notifyListeners();
      return AuthResult(ok: true, role: AuthRole.user, apiKey: apiKey);
    }
    
    return const AuthResult(ok: false, message: 'Invalid API key');
  }

  Future<String?> _getUsernameFromApiKey(String apiKey) async {
    // This would ideally come from backend, for now return unknown
    return 'user@example.com';
  }

  void logout() {
    if (_username != null) {
      _recordActivity(_username!, 'LOGOUT');
    }
    _role = null;
    _username = null;
    _apiKey = null;
    _authenticatedWithBackend = false;
    notifyListeners();
  }

  void _recordActivity(String user, String action) {
    final now = DateTime.now();
    final date = DateFormat('MMM d, y').format(now);
    final time = DateFormat('HH:mm').format(now);
    AdminStore().addClientActivity(
      file: '—',
      prediction: '—',
      confidence: 0,
      status: action,
      size: '—',
      date: '$date  $time',
      actorEmail: user,
    );
  }
}