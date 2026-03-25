import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clipboard/clipboard.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_snackbar.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({Key? key}) : super(key: key);

  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _users = [];
  String? _newUserApiKey;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    // In a real app, you would fetch users from your backend
    // For now, we'll use a placeholder
    setState(() {
      _isLoading = true;
    });
    
    try {
      // TODO: Replace with actual API call to fetch users
      // final response = await ApiClient().getUsers();
      // setState(() {
      //   _users = List<Map<String, dynamic>>.from(response['users'] ?? []);
      // });
    } catch (e) {
      _showError('Failed to load users: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _newUserApiKey = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final username = _usernameController.text.trim();
      
      // Create admin user with admin role
      final response = await ApiClient().createUser(
        username,
        isAdmin: true, // Ensure user is created as admin
      );
      
      // Log the admin creation action
      if (authService.currentUser != null) {
        try {
          await ApiClient().logAction(
            action: 'admin_created',
            details: 'Admin user created: $username',
            userId: authService.currentUser!.id,
          );
        } catch (e) {
          debugPrint('Failed to log admin creation: $e');
        }
      }
      
      setState(() {
        _newUserApiKey = response['api_key'];
        _users.add({
          'username': username,
          'api_key': _newUserApiKey,
          'role': 'admin',
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      _usernameController.clear();
      _showSuccess('Admin user created successfully!');
    } catch (e) {
      _showError('Failed to create user: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    FlutterClipboard.copy(text).then((_) {
      _showSuccess('Copied to clipboard!');
    });
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Create New User',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_newUserApiKey != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'API Key (save this - it won\'t be shown again):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _newUserApiKey!,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () => _copyToClipboard(_newUserApiKey!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createUser,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Add Admin'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Existing Users',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _isLoading && _users.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No users found'),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(user['username'] ?? 'No username'),
                            subtitle: Text(
                              'Created: ${user['created_at'] != null ? DateTime.parse(user['created_at']).toString().split('.')[0] : 'Unknown'}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: user['api_key'] != null
                                  ? () => _copyToClipboard(user['api_key'])
                                  : null,
                              tooltip: 'Copy API Key',
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}
