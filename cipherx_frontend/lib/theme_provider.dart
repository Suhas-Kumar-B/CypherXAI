// lib/theme_provider.dart
import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool isDarkMode = true;
  int currentPage = 0;

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    notifyListeners();
  }

  void setPage(int pageIndex) {
    currentPage = pageIndex;
    notifyListeners();
  }
}
