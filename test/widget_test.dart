// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:app_scan_qr/main.dart';

void main() {
  test('default Apps Script URL sesuai konfigurasi', () {
    expect(
      kAppsScriptUrl,
      'https://script.google.com/macros/s/AKfycbyTotultHxmHdfqN5pa6PVrwI7FKM-4wrUsjDo37L0QEMRjWZUXxYDbcZhOESKxOmTpbQ/exec',
    );
  });
}
