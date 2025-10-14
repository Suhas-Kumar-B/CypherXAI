// lib/utils/download_helper.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

class DownloadHelper {
  /// Downloads JSON data as a text file
  /// On web: triggers browser download
  /// On mobile/desktop: saves to Downloads folder
  static Future<String?> downloadJson({
    required Map<String, dynamic> jsonData,
    required String fileName,
  }) async {
    try {
      // Ensure fileName has .json extension
      final finalFileName = fileName.endsWith('.json') ? fileName : '$fileName.json';
      
      // Convert JSON to pretty-printed string
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      
      if (kIsWeb) {
        // Web: Trigger browser download
        final bytes = utf8.encode(jsonString);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', finalFileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        return 'Downloaded: $finalFileName';
      } else {
        // Mobile/Desktop: Save to Downloads folder
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          // Fallback to app documents directory
          final appDir = await getApplicationDocumentsDirectory();
          final file = File('${appDir.path}/$finalFileName');
          await file.writeAsString(jsonString);
          return file.path;
        }
        
        final file = File('${directory.path}/$finalFileName');
        await file.writeAsString(jsonString);
        return file.path;
      }
    } catch (e) {
      return null;
    }
  }
  
  /// Downloads text data as a text file
  static Future<String?> downloadText({
    required String textData,
    required String fileName,
  }) async {
    try {
      // Ensure fileName has .txt extension
      final finalFileName = fileName.endsWith('.txt') ? fileName : '$fileName.txt';
      
      if (kIsWeb) {
        // Web: Trigger browser download
        final bytes = utf8.encode(textData);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', finalFileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        return 'Downloaded: $finalFileName';
      } else {
        // Mobile/Desktop: Save to Downloads folder
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          // Fallback to app documents directory
          final appDir = await getApplicationDocumentsDirectory();
          final file = File('${appDir.path}/$finalFileName');
          await file.writeAsString(textData);
          return file.path;
        }
        
        final file = File('${directory.path}/$finalFileName');
        await file.writeAsString(textData);
        return file.path;
      }
    } catch (e) {
      return null;
    }
  }
  
  /// Downloads binary data (like from API response)
  static Future<String?> downloadBytes({
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      if (kIsWeb) {
        // Web: Trigger browser download
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        return 'Downloaded: $fileName';
      } else {
        // Mobile/Desktop: Save to Downloads folder
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          // Fallback to app documents directory
          final appDir = await getApplicationDocumentsDirectory();
          final file = File('${appDir.path}/$fileName');
          await file.writeAsBytes(bytes);
          return file.path;
        }
        
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);
        return file.path;
      }
    } catch (e) {
      return null;
    }
  }
}
