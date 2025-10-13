// lib/components/json_viewer.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class JsonViewer extends StatelessWidget {
  final Map<String, dynamic> data;
  const JsonViewer({Key? key, required this.data}) : super(key: key);

  Widget renderJson(dynamic value, {int indent = 0}) {
    final padding = EdgeInsets.only(left: indent * 10.0);
    if (value == null) {
      return Padding(
          padding: padding,
          child: const Text('null', style: TextStyle(color: Colors.grey)));
    }
    if (value is bool) {
      return Padding(
          padding: padding,
          child: Text(value.toString(),
              style: TextStyle(color: value ? Colors.green : Colors.red)));
    }
    if (value is num) {
      return Padding(
          padding: padding,
          child: Text(value.toString(),
              style: const TextStyle(color: Colors.cyan)));
    }
    if (value is String) {
      return Padding(
          padding: padding,
          child: Text('"$value"',
              style: const TextStyle(color: Colors.greenAccent)));
    }
    if (value is List) {
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('[${value.length} items]',
                style: const TextStyle(color: Colors.yellow)),
            ...value.map((v) => renderJson(v, indent: indent + 1)).toList(),
          ],
        ),
      );
    }
    if (value is Map) {
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: value.entries
              .map(
                (e) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('"${e.key}":',
                              style:
                                  const TextStyle(color: Colors.blueAccent)),
                          renderJson(e.value, indent: indent + 1),
                        ],
                      ),
                    )
                  ],
                ),
              )
              .toList(),
        ),
      );
    }
    return Padding(
        padding: padding,
        child: Text(value.toString(),
            style: const TextStyle(color: Colors.grey)));
  }

  @override
  Widget build(BuildContext context) {
    final jsonText = const JsonEncoder.withIndent('  ').convert(data);

    return Card(
      color: const Color(0xFF0F1620),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(children: [
                  Icon(Icons.description_outlined, color: Colors.cyanAccent),
                  SizedBox(width: 8),
                  Text('Raw Analysis Data',
                      style: TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold)),
                ]),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: jsonText)),
                      icon: const Icon(Icons.copy, color: Colors.cyanAccent),
                      label: const Text('Copy JSON',
                          style: TextStyle(color: Colors.cyanAccent)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Keep simple & cross-platform friendly: copy as "download"
                        Clipboard.setData(ClipboardData(text: jsonText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('JSON copied (use Save As in any editor)')),
                        );
                      },
                      icon: const Icon(Icons.download_outlined,
                          color: Colors.white70),
                      label: const Text('Download',
                          style: TextStyle(color: Colors.white70)),
                      style: OutlinedButton.styleFrom(
                          side:
                              BorderSide(color: Colors.white.withOpacity(0.15))),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 360,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(child: renderJson(data)),
            ),
          ],
        ),
      ),
    );
  }
}
