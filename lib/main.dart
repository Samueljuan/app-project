import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kAppsScriptUrl = String.fromEnvironment(
  'APPS_SCRIPT_URL',
  defaultValue: '',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScanApp());
}

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

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  static const _kUsername = 'randomstuff.smg';
  static const _kPassword = 'renata elek';
  static const _kAuthStorageKey = 'last_auth_timestamp';
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.aztec,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.pdf417,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.code128,
      BarcodeFormat.ean8,
      BarcodeFormat.ean13,
    ],
  );
  bool _isSending = false;
  String _statusMessage = 'Arahkan kamera ke QR / barcode';
  String? _pendingValue;
  String? _lastValue;
  String? _pendingFormat;
  bool _showSuccess = false;
  final List<String> _logs = <String>[];
  bool _authenticated = false;
  bool _sessionChecked = false;
  bool _isAuthenticating = false;
  String? _authError;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  Timer? _statusResetTimer;
  bool _cameraActive = false;
  String? _cameraError;
  bool _cameraPromptDismissed = false;

  bool get _canSubmit => !_isSending && _pendingValue != null;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _statusResetTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      _resumeCamera();
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kAuthStorageKey);
    var authenticated = false;
    if (saved != null) {
      final savedTime = DateTime.tryParse(saved);
      if (savedTime != null &&
          DateTime.now().difference(savedTime) < const Duration(days: 1)) {
        authenticated = true;
      } else {
        await prefs.remove(_kAuthStorageKey);
      }
    }
    if (!mounted) return;
    setState(() {
      _authenticated = authenticated;
      _sessionChecked = true;
      if (_authenticated) {
        _cameraPromptDismissed = false;
        _cameraActive = false;
      }
    });
  }

  void _handleCapture(BarcodeCapture capture) {
    final Barcode validBarcode = capture.barcodes.firstWhere(
      (barcode) => (barcode.rawValue?.trim().isNotEmpty ?? false),
      orElse: () => capture.barcodes.isNotEmpty
          ? capture.barcodes.first
          : Barcode(rawValue: ''),
    );
    final code = validBarcode.rawValue?.trim() ?? '';
    if (code.isEmpty) {
      return;
    }

    setState(() {
      _pendingValue = code;
      _pendingFormat = validBarcode.format.name;
      _showSuccess = false;
      _statusMessage = 'Kode terbaca. Tekan Submit untuk mengirim.';
    });
  }

  Future<void> _submitScan() async {
    final code = _pendingValue;
    if (code == null) return;

    final now = DateTime.now();

    setState(() {
      _isSending = true;
      _showSuccess = false;
      _statusMessage = 'Mengirim ke spreadsheet...';
    });

    try {
      await _sendToSpreadsheet(code, now);
      if (!mounted) return;
      setState(() {
        _lastValue = code;
        _pendingValue = null;
        _pendingFormat = null;
        _showSuccess = true;
        _statusMessage = 'Terkirim: $code';
      });
      _appendLog('Berhasil kirim: $code');
      _scheduleStatusReset(duration: const Duration(seconds: 2));
    } catch (error) {
      final message = 'Gagal mengirim: $error';
      if (!mounted) return;
      setState(() {
        _statusMessage = message;
        _showSuccess = false;
        _pendingValue = null;
        _pendingFormat = null;
      });
      _appendLog(message);
      _scheduleStatusReset();
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _appendLog(String message) {
    final timestamp = DateTime.now()
        .toLocal()
        .toIso8601String()
        .split('.')
        .first;
    setState(() {
      _logs
        ..clear()
        ..add('[$timestamp] $message');
    });
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isAuthenticating = true;
      _authError = null;
    });
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username != _kUsername || password != _kPassword) {
      setState(() {
        _authError = 'Username atau password salah.';
        _isAuthenticating = false;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kAuthStorageKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    if (!mounted) return;
    setState(() {
      _authenticated = true;
      _isAuthenticating = false;
      _authError = null;
      _cameraPromptDismissed = false;
      _cameraActive = false;
    });
    _usernameController.clear();
    _passwordController.clear();
  }

  Future<void> _pauseCamera() async {
    try {
      await _controller.stop();
    } catch (_) {
      // ignore stop errors
    } finally {
      if (mounted) {
        setState(() {
          _cameraActive = false;
        });
      }
    }
  }

  Future<bool> _resumeCamera() async {
    if (!_authenticated) return false;
    try {
      await _controller.start();
      if (!mounted) return false;
      setState(() {
        _cameraActive = true;
        _cameraError = null;
        _cameraPromptDismissed = true;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _cameraActive = false;
        _cameraError =
            'Kamera tidak dapat dibuka. Pastikan izin kamera diberikan atau tekan ulang.';
      });
      return false;
    }
  }

  void _scheduleStatusReset({Duration duration = const Duration(seconds: 4)}) {
    _statusResetTimer?.cancel();
    _statusResetTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Arahkan kamera ke QR / barcode';
        _pendingValue = null;
        _pendingFormat = null;
        _showSuccess = false;
        _isSending = false;
      });
      if (_cameraPromptDismissed) {
        _resumeCamera();
      }
    });
  }

  Future<void> _sendToSpreadsheet(String code, DateTime scannedAt) async {
    final url = kAppsScriptUrl.trim();
    if (url.isEmpty) {
      throw 'Isi kAppsScriptUrl dengan URL Apps Script milikmu';
    }
    final payload = {
      'value': code,
      'scannedAt': scannedAt.toUtc().toIso8601String(),
    };

    Future<http.Response> postForm() => http.post(Uri.parse(url), body: payload);
    Future<http.Response> postJson() => http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
    Future<http.Response> getFallback() => http.get(
          Uri.parse(
            '$url?value=${Uri.encodeComponent(code)}&scannedAt=${Uri.encodeComponent(payload['scannedAt']!)}',
          ),
        );

    late http.Response response;
    var gotResponse = false;
    // Try the simplest form POST first (no preflight); fall back to JSON if needed.
    try {
      response = await postForm();
      gotResponse = true;
    } on http.ClientException catch (error) {
      _appendLog(
        'Catatan: respons Apps Script tidak bisa dibaca (${error.message}). '
        'Mencoba ulang dengan JSON...',
      );
    }

    final needsRetry = !gotResponse || response.statusCode >= 400;
    if (needsRetry) {
      try {
        response = await postJson();
        gotResponse = true;
      } on http.ClientException catch (error) {
        final looksLikeCors = error.message.contains('Failed to fetch') ||
            error.message.contains('Load failed');
        _appendLog(
          'Catatan: respons Apps Script tidak bisa dibaca (${error.message}). '
          'Data mungkin sudah sampai, cek spreadsheet.',
        );
        if (looksLikeCors) {
          // Try GET with query params (simple request, no preflight).
          response = await getFallback();
          gotResponse = true;
        } else {
          rethrow;
        }
      }
    }

    if (!gotResponse) {
      _appendLog(
        'Tidak ada respons terbaca dari Apps Script. Cek koneksi/CORS dan coba lagi.',
      );
      return;
    }

    if (response.statusCode >= 400) {
      throw 'Server mengembalikan kode ${response.statusCode} (${response.body})';
    }

    if (response.body.isNotEmpty) {
      _appendLog('Respons server: ${response.body}');
    }
  }

  Widget _buildSubmitButton() {
    final pendingText = _pendingValue;
    final label = _isSending
        ? 'Mengirim data...'
        : pendingText == null
        ? 'Scan kode terlebih dahulu'
        : 'Submit ke Google Sheet';

    final leading = _isSending
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            pendingText == null ? Icons.qr_code_scanner : Icons.upload_rounded,
          );

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _canSubmit ? _submitScan : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 12),
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (!_sessionChecked) {
      content = const Center(child: CircularProgressIndicator());
    } else if (!_authenticated) {
      content = _LoginForm(
        usernameController: _usernameController,
        passwordController: _passwordController,
        isLoading: _isAuthenticating,
        errorMessage: _authError,
        onSubmit: _handleLogin,
      );
    } else {
      content = _ScannerContent(
        controller: _controller,
        onCapture: _handleCapture,
        isSending: _isSending,
        statusMessage: _statusMessage,
        lastValue: _lastValue,
        pendingValue: _pendingValue,
        pendingFormat: _pendingFormat,
        showSuccess: _showSuccess,
        submitButton: _buildSubmitButton(),
        logs: _logs,
        cameraActive: _cameraActive,
        cameraError: _cameraError,
        onRequestCamera: () {
          _resumeCamera();
        },
        cameraPromptDismissed: _cameraPromptDismissed,
      );
    }
    return Scaffold(body: _buildBackground(content));
  }

  Widget _buildBackground(Widget child) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF02050B), Color(0xFF051322), Color(0xFF010C16)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: child,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          'PWA QR Scanner',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Setelah kode terbaca, tekan Submit untuk mengirimnya ke Google Sheet.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String message;
  final String? latestValue;
  final String? pendingValue;
  final String? pendingFormat;
  final bool showSuccess;
  const _StatusCard({
    required this.message,
    required this.latestValue,
    required this.pendingValue,
    required this.pendingFormat,
    required this.showSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (pendingValue != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.qr_code, size: 16, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  pendingFormat ?? 'Format tidak diketahui',
                  style: textTheme.labelSmall?.copyWith(color: Colors.white70),
                ),
                const Spacer(),
                if (showSuccess)
                  const Icon(Icons.check_circle, color: Colors.greenAccent),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Siap dikirim:',
              style: textTheme.labelSmall?.copyWith(color: Colors.white54),
            ),
            Text(
              pendingValue!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
          ],
          if (latestValue != null) ...[
            const SizedBox(height: 8),
            Text(
              'Terakhir:',
              style: textTheme.labelSmall?.copyWith(color: Colors.white54),
            ),
            Text(
              latestValue!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  final String errorMessage;
  const _CameraError({required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Kamera tidak bisa dibuka ($errorMessage)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Pastikan izin kamera diberikan dan jalankan ulang aplikasinya.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerContent extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onCapture;
  final bool isSending;
  final String statusMessage;
  final String? lastValue;
  final String? pendingValue;
  final String? pendingFormat;
  final bool showSuccess;
  final Widget submitButton;
  final List<String> logs;
  final bool cameraActive;
  final String? cameraError;
  final VoidCallback onRequestCamera;
  final bool cameraPromptDismissed;
  const _ScannerContent({
    required this.controller,
    required this.onCapture,
    required this.isSending,
    required this.statusMessage,
    required this.lastValue,
    required this.pendingValue,
    required this.pendingFormat,
    required this.showSuccess,
    required this.submitButton,
    required this.logs,
    required this.cameraActive,
    required this.cameraError,
    required this.onRequestCamera,
    required this.cameraPromptDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Header(),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: controller,
                      fit: BoxFit.cover,
                      onDetect: onCapture,
                      errorBuilder: (context, error) =>
                          _CameraError(errorMessage: error.errorCode.name),
                      placeholderBuilder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    ),
                    const _ScannerOverlay(),
                    if (!cameraActive && !cameraPromptDismissed)
                      Container(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Kamera tidak aktif',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (cameraError != null) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Text(
                                    cameraError!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 8),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    'Tekan tombol di bawah untuk menyalakan kamera.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: onRequestCamera,
                                child: const Text('Aktifkan Kamera'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (isSending)
                      Container(
                        color: Colors.black45,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _StatusCard(
          message: statusMessage,
          latestValue: lastValue,
          pendingValue: pendingValue,
          pendingFormat: pendingFormat,
          showSuccess: showSuccess,
        ),
        const SizedBox(height: 12),
        submitButton,
        const SizedBox(height: 12),
        _LogPanel(entries: logs),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _LogPanel extends StatelessWidget {
  final List<String> entries;
  const _LogPanel({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Log Pengiriman', style: textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            entries.first,
            style: textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.transparent, Colors.black38],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSubmit;
  const _LoginForm({
    required this.usernameController,
    required this.passwordController,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Masuk terlebih dahulu',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Isi username dan password untuk mengakses kamera.',
              style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _AuthTextField(
              controller: usernameController,
              label: 'Username',
              hintText: 'Nama toko',
              enabled: !isLoading,
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 12),
            _AuthTextField(
              controller: passwordController,
              label: 'Password',
              hintText: 'Password',
              obscureText: true,
              enabled: !isLoading,
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 12),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  errorMessage!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.redAccent,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLoading ? null : onSubmit,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Masuk'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sesi login otomatis berakhir setiap 24 jam.',
              style: textTheme.labelSmall?.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.obscureText = false,
    this.enabled = true,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
