// lib/components/sidebar_menu.dart
import 'package:flutter/material.dart';

class SidebarMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const SidebarMenuItem({Key? key, required this.icon, required this.title, required this.selected, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? Colors.cyanAccent : Colors.grey),
      title: Text(title, style: TextStyle(color: selected ? Colors.cyanAccent : Colors.grey)),
      tileColor: selected ? Colors.cyan.withOpacity(0.12) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }
}
