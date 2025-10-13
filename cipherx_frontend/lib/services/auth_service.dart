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
  static const _admins = <String>{
    'admin@cipherx.com',
    'testadmin@cipherx.com',
    'suhaskumarb748@gmail.com',
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

  // No auto-provisioning; authentication relies on API key validation
  Future<void> _setupBackendConnection() async {}

  Future<bool> _validateApiKey(String apiKey) async {
    final apiClient = ApiClient();
    return await apiClient.authenticate(apiKey);
  }

  Future<AuthResult> login(String email, String passwordOrKey) async {
    // Admin: email must be in whitelist and key must match dart-define ADMIN_API_KEY
    if (_admins.contains(email) && ApiClient.ADMIN_API_KEY.isNotEmpty && passwordOrKey == ApiClient.ADMIN_API_KEY) {
      _role = AuthRole.admin;
      _username = email;
      _authenticatedWithBackend = true; // admin actions use X-Admin-Key
      _recordActivity(email, 'LOGIN (ADMIN)');
      notifyListeners();
      return const AuthResult(ok: true, role: AuthRole.admin);
    }

    // User: password field is the API key
    final providedApiKey = passwordOrKey.trim();
    if (providedApiKey.isNotEmpty) {
      final valid = await _validateApiKey(providedApiKey);
      if (valid) {
        _role = AuthRole.user;
        _username = email;
        _apiKey = providedApiKey;
        _authenticatedWithBackend = true;
        _recordActivity(email, 'LOGIN (USER)');
        notifyListeners();
        return AuthResult(ok: true, role: AuthRole.user, apiKey: _apiKey);
      }
    }

    return const AuthResult(ok: false, message: 'Invalid email or key');
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
    return _username; // placeholder
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