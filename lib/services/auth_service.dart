import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_scan_qr/config/app_config.dart';

class AuthService {
  static const Duration sessionDuration = Duration(days: 1);
  static const String _storageKey = 'last_auth_timestamp';

  AuthService({DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _username = _normalizeCredential(kLoginUsername),
        _password = _normalizeCredential(kLoginPassword),
        _passwordHash = _normalizeCredential(kLoginPasswordHash).toLowerCase();

  final DateTime Function() _now;
  final String _username;
  final String _password;
  final String _passwordHash;

  String get resolvedUsername => _username;

  bool get credentialsConfigured =>
      _username.isNotEmpty && (_password.isNotEmpty || _passwordHash.isNotEmpty);

  bool verifyCredentials({required String username, required String password}) {
    final normalizedUser = _normalizeCredential(username);
    final normalizedPass = _normalizeCredential(password);
    return normalizedUser == _username && _isPasswordMatch(normalizedPass);
  }

  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved == null) {
      return false;
    }

    final savedTime = DateTime.tryParse(saved);
    if (savedTime == null) {
      await prefs.remove(_storageKey);
      return false;
    }

    if (_now().difference(savedTime) < sessionDuration) {
      return true;
    }

    await prefs.remove(_storageKey);
    return false;
  }

  Future<void> persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _now().toUtc().toIso8601String());
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  String maskPassword(String raw) {
    if (raw.isEmpty) return '(empty)';
    final maskedLength = raw.length.clamp(1, 16);
    return '${'*' * maskedLength} (len=${raw.length})';
  }

  bool _isPasswordMatch(String rawInput) {
    if (_passwordHash.isNotEmpty) {
      return _hashPassword(rawInput) == _passwordHash;
    }
    if (_password.isNotEmpty) {
      return rawInput == _password;
    }
    return false;
  }

  String _hashPassword(String raw) {
    final bytes = utf8.encode(raw);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

String _normalizeCredential(String value) => value.trim();
