import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:app_scan_qr/config/app_config.dart';

class SpreadsheetSendResult {
  final bool likelySentDespiteCors;
  final String? serverResponse;

  const SpreadsheetSendResult({
    this.likelySentDespiteCors = false,
    this.serverResponse,
  });
}

class SpreadsheetService {
  SpreadsheetService({
    http.Client? client,
    String? appsScriptUrl,
    void Function(String message)? onLog,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _appsScriptUrl = (appsScriptUrl ?? kAppsScriptUrl).trim(),
        _onLog = onLog;

  final http.Client _client;
  final bool _ownsClient;
  final String _appsScriptUrl;
  final void Function(String message)? _onLog;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<SpreadsheetSendResult> sendCode({
    required String code,
    required DateTime scannedAt,
  }) async {
    if (_appsScriptUrl.isEmpty) {
      throw 'Isi kAppsScriptUrl dengan URL Apps Script milikmu';
    }

    final payload = {
      'value': code,
      'scannedAt': scannedAt.toUtc().toIso8601String(),
    };

    Future<http.Response> postForm() =>
        _client.post(Uri.parse(_appsScriptUrl), body: payload);
    Future<http.Response> postJson() => _client.post(
          Uri.parse(_appsScriptUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

    http.Response response;
    var usedJson = false;

    try {
      response = await postForm();
    } on http.ClientException catch (error) {
      if (_looksLikeCorsError(error)) {
        _onLog?.call(
          'Data kemungkinan sudah terkirim (respons diblokir browser/CORS). '
          'Cek Google Sheet untuk memastikan.',
        );
        return const SpreadsheetSendResult(likelySentDespiteCors: true);
      }
      _onLog?.call(
        'Gagal membaca respons (${error.message}). Mencoba format lain...',
      );
      response = await postJson();
      usedJson = true;
    }

    if (response.statusCode >= 400) {
      if (!usedJson) {
        final retry = await postJson();
        usedJson = true;
        if (retry.statusCode >= 400) {
          throw 'Server mengembalikan kode ${retry.statusCode} (${retry.body})';
        }
        response = retry;
      } else {
        throw 'Server mengembalikan kode ${response.statusCode} (${response.body})';
      }
    }

    final body = response.body;
    return SpreadsheetSendResult(
      serverResponse: body.isEmpty ? null : body,
    );
  }

  bool _looksLikeCorsError(http.ClientException error) {
    final message = error.message.toLowerCase();
    return message.contains('failed to fetch') ||
        message.contains('load failed') ||
        message.contains('access-control') ||
        message.contains('cors');
  }
}
