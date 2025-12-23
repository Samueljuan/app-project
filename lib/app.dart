import 'package:flutter/material.dart';

import 'package:app_scan_qr/pages/scanner_page.dart';

class ScanApp extends StatelessWidget {
  const ScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00D084),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Scan QR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF050A11),
        textTheme: Theme.of(
          context,
        ).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      home: const ScannerPage(),
    );
  }
}
