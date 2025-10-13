// lib/services/admin_store.dart
import 'package:flutter/foundation.dart';

class ClientActivity {
  final String file;
  final String prediction;
  final int confidence; // keep int like History
  final String status;  // e.g., LOGIN (ADMIN), LOGOUT, ANALYZE, etc.
  final String size;
  final String date;
  final String actorEmail;

  ClientActivity({
    required this.file,
    required this.prediction,
    required this.confidence,
    required this.status,
    required this.size,
    required this.date,
    required this.actorEmail,
  });
}

class GeneratedPassword {
  final String username;
  final String password;
  final DateTime createdAt;

  GeneratedPassword({
    required this.username,
    required this.password,
    required this.createdAt,
  });
}

class AdminUser {
  final String email;
  String displayName;
  bool active;

  AdminUser({required this.email, required this.displayName, this.active = true});
}

class AdminStore extends ChangeNotifier {
  static final AdminStore _instance = AdminStore._internal();
  factory AdminStore() => _instance;
  AdminStore._internal();

  // In-memory stores
  final List<ClientActivity> _activity = [];
  final List<GeneratedPassword> _generated = [];
  final List<AdminUser> _users = [
    AdminUser(email: 'dummy@gmail.com', displayName: 'Dummy User', active: true),
    AdminUser(email: 'sanjanar.ten@gmail.com', displayName: 'Sanjana (Admin)', active: true),
  ];

  List<ClientActivity> get activity => List.unmodifiable(_activity);
  List<GeneratedPassword> get generated => List.unmodifiable(_generated);
  List<AdminUser> get users => List.unmodifiable(_users);

  void addClientActivity({
    required String file,
    required String prediction,
    required int confidence,
    required String status,
    required String size,
    required String date,
    required String actorEmail,
  }) {
    _activity.insert(0, ClientActivity(
      file: file,
      prediction: prediction,
      confidence: confidence,
      status: status,
      size: size,
      date: date,
      actorEmail: actorEmail,
    ));
    notifyListeners();
  }

  void addGeneratedPassword(String username, String password) {
    _generated.insert(0, GeneratedPassword(
      username: username,
      password: password,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  // CRUD operations
  void addUser(String email, String name) {
    _users.add(AdminUser(email: email, displayName: name, active: true));
    notifyListeners();
  }

  void updateUser(String email, {String? name, bool? active}) {
    final i = _users.indexWhere((u) => u.email == email);
    if (i >= 0) {
      if (name != null) _users[i].displayName = name;
      if (active != null) _users[i].active = active;
      notifyListeners();
    }
  }

  void removeUser(String email) {
    _users.removeWhere((u) => u.email == email);
    notifyListeners();
  }
}
