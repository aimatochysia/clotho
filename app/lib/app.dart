import 'package:flutter/material.dart';

import 'state/app_controller.dart';
import 'ui/dashboard_page.dart';

class ClothoApp extends StatelessWidget {
  const ClothoApp({super.key, required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6750A4);
    return MaterialApp(
      title: 'Clotho',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: DashboardPage(app: app),
    );
  }
}
