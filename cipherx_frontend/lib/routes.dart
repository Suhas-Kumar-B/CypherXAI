// lib/routes.dart
import 'package:flutter/material.dart';

import 'pages/dashboard.dart';
import 'pages/results.dart';
import 'pages/history.dart';
import 'pages/about.dart';

import 'models/analysis.dart';
import 'models/user.dart';

class AppRoutes {
  static const String dashboard = '/';
  static const String results   = '/results';
  static const String history   = '/history';
  static const String about     = '/about';

  /// Back-compat helper: if some code still calls buildRoutes(user),
  /// this keeps that working. The [user] is unused because pages
  /// now pull user info themselves.
  static Map<String, WidgetBuilder> buildRoutes(User? user) => {
        dashboard: (_) => const DashboardPage(),
        results:   (_) => const ResultsPage(),
        history:   (_) => const HistoryPage(),
        about:     (_) => const AboutPage(),
      };

  /// Prefer this when you want to push pages with typed arguments.
  /// Example:
  /// Navigator.pushNamed(context, AppRoutes.results, arguments: analysis);
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case dashboard:
        final arg = settings.arguments;
        final analysis = arg is Analysis ? arg : null;
        return MaterialPageRoute(
          builder: (_) => DashboardPage(analysis: analysis),
          settings: settings,
        );

      case results:
        final arg = settings.arguments;
        final analysis = arg is Analysis ? arg : null;
        return MaterialPageRoute(
          builder: (_) => ResultsPage(analysis: analysis),
          settings: settings,
        );

      case history:
        return MaterialPageRoute(
          builder: (_) => const HistoryPage(),
          settings: settings,
        );

      case about:
        return MaterialPageRoute(
          builder: (_) => const AboutPage(),
          settings: settings,
        );

      default:
        // Fallback to dashboard
        return MaterialPageRoute(
          builder: (_) => const DashboardPage(),
          settings: settings,
        );
    }
  }
}
