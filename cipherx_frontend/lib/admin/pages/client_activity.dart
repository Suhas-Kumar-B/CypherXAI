// In client_activity.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';
import '../../services/admin_store.dart';

class ClientActivityPage extends StatefulWidget {
  const ClientActivityPage({Key? key}) : super(key: key);

  @override
  _ClientActivityPageState createState() => _ClientActivityPageState();
}

class _ClientActivityPageState extends State<ClientActivityPage> {
  List<Map<String, dynamic>> _activityLogs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActivityLogs();
  }

  Future<void> _loadActivityLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final logs = await ApiClient().getActivityLog();
      setState(() {
        _activityLogs = logs;
        // Sort by timestamp in descending order (newest first)
        _activityLogs.sort((a, b) {
          final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(0);
          final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(0);
          return bTime.compareTo(aTime);
        });
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load activity logs: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Unknown time';
    final dateTime = DateTime.tryParse(timestamp);
    if (dateTime == null) return timestamp;
    
    return DateFormat('MMM d, y HH:mm:ss').format(dateTime.toLocal());
  }

  Widget _buildActivityItem(Map<String, dynamic> log) {
    return Card(
      color: const Color(0xFF0F1620),
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: ListTile(
        leading: _getActionIcon(log['action']),
        title: Text(
          log['action'] ?? 'Unknown Action',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (log['details'] != null) ...[
              const SizedBox(height: 4),
              Text(
                log['details'].toString(),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(log['timestamp']),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (log['user_email'] != null) ...[
              const SizedBox(height: 2),
              Text(
                'User: ${log['user_email']}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
            if (log['ip_address'] != null) ...[
              const SizedBox(height: 2),
              Text(
                'IP: ${log['ip_address']}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _getActionIcon(String? action) {
    if (action == null) return const Icon(Icons.info, color: Colors.grey);
    
    final lowerAction = action.toLowerCase();
    if (lowerAction.contains('login')) {
      return const Icon(Icons.login, color: Colors.greenAccent);
    } else if (lowerAction.contains('logout')) {
      return const Icon(Icons.logout, color: Colors.orangeAccent);
    } else if (lowerAction.contains('create') || lowerAction.contains('add')) {
      return const Icon(Icons.add_circle_outline, color: Colors.blueAccent);
    } else if (lowerAction.contains('delete') || lowerAction.contains('remove')) {
      return const Icon(Icons.delete_outline, color: Colors.redAccent);
    } else if (lowerAction.contains('update') || lowerAction.contains('modify')) {
      return const Icon(Icons.edit, color: Colors.yellowAccent);
    } else if (lowerAction.contains('error') || lowerAction.contains('failed')) {
      return const Icon(Icons.error_outline, color: Colors.red);
    }
    
    return const Icon(Icons.info_outline, color: Colors.grey);
  }

  Widget _row({required List<dynamic> cells, bool isHeader = false, List<Widget Function(BuildContext)> builders = const []}) {
    const textStyleHeader = TextStyle(color: Colors.white70, fontWeight: FontWeight.bold);
    const textStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.w500);

    // Ensure we don't exceed the number of cells we have
    final cellWidgets = <Widget>[];
    final cellCount = cells.length;
    
    // Add cells with proper null safety
    for (var i = 0; i < 4; i++) { // We only need 4 columns
      if (i < cellCount) {
        final cellContent = cells[i];
        final isActionCell = i == 2; // The action column
        
        // For the action column, use the builder if available
        if (isActionCell && i < builders.length) {
          cellWidgets.add(_cell(
            '', 
            flex: i == 0 ? 3 : 2, 
            style: isHeader ? textStyleHeader : textStyle,
            custom: builders[i](context),
          ));
        } else {
          cellWidgets.add(_cell(
            cellContent?.toString() ?? '—', 
            flex: i == 0 ? 3 : 2, 
            style: isHeader ? textStyleHeader : textStyle,
          ));
        }
      } else {
        // Add empty cell if we don't have enough data
        cellWidgets.add(_cell('—', flex: i == 0 ? 3 : 2, style: isHeader ? textStyleHeader : textStyle));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(children: cellWidgets),
    );
  }

  Widget _cell(String text, {int flex = 1, TextStyle? style, Widget? custom}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: style,
      ),
    );
  }

  Widget pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics_outlined, color: Colors.cyanAccent),
                SizedBox(width: 10),
                Text(
                  'Client Activity Logs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (_error != null)
              Card(
                color: Colors.red[900]?.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _loadActivityLogs,
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.cyanAccent,
                      ),
                    )
                  : _activityLogs.isEmpty
                      ? const Center(
                          child: Text(
                            'No activity logs found',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadActivityLogs,
                          color: Colors.cyanAccent,
                          child: ListView.builder(
                            itemCount: _activityLogs.length,
                            itemBuilder: (context, index) {
                              return _buildActivityItem(_activityLogs[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadActivityLogs,
        backgroundColor: Colors.cyanAccent,
        child: const Icon(Icons.refresh, color: Colors.black),
      ),
    );
  }
}